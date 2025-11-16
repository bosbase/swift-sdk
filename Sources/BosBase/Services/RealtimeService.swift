import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct RealtimeSubscriptionOptions {
    public var query: [String: Any?]
    public var headers: [String: String]

    public init(query: [String: Any?] = [:], headers: [String: String] = [:]) {
        self.query = query
        self.headers = headers
    }
}

public struct RealtimeMessage {
    public let payload: JSONRecord
    public let topic: String?

    public var action: String? {
        return payload["action"]?.value as? String
    }
}

public final class RealtimeService: BaseService {
    public typealias Listener = @Sendable (RealtimeMessage) -> Void

    public var onDisconnect: (([String]) -> Void)?

    private var eventTask: Task<Void, Never>?
    private let state = RealtimeActorState()

    public func subscribe(
        topic: String,
        options: RealtimeSubscriptionOptions? = nil,
        callback: @escaping Listener
    ) async throws -> () -> Void {
        let key = makeSubscriptionKey(topic: topic, options: options)
        let identifier = UUID()
        let needsConnect = await state.addListener(key: key, id: identifier, listener: callback)

        if needsConnect {
            try await ensureConnected()
        }

        if await state.currentClientId() != nil {
            try await submitSubscriptions()
        }

        return { [weak self] in
            Task {
                await self?.removeListener(id: identifier, topicKey: key)
            }
        }
    }

    public func unsubscribe(_ topic: String? = nil) async throws {
        let hasSubscriptions = await state.remove(topic: topic)
        if hasSubscriptions {
            try await submitSubscriptions()
        } else {
            disconnect()
        }
    }

    public func unsubscribeByPrefix(_ prefix: String) async throws {
        let hasSubscriptions = await state.removeByPrefix(prefix)
        if hasSubscriptions {
            try await submitSubscriptions()
        } else {
            disconnect()
        }
    }

    public func currentClientIdentifier() async -> String? {
        await state.currentClientId()
    }

    private func ensureConnected() async throws {
        if eventTask == nil || eventTask?.isCancelled == true {
            eventTask = Task { [weak self] in
                await self?.runEventLoop()
            }
        }
        try await waitForConnection()
    }

    private func waitForConnection() async throws {
        if await state.currentClientId() != nil {
            return
        }
        try await withCheckedThrowingContinuation { continuation in
            Task {
                await self.state.registerContinuation(continuation)
            }
        }
    }

    private func runEventLoop() async {
        while await state.hasSubscriptions() {
            do {
                try await openEventStream()
                break
            } catch {
                let shouldRetry = await state.shouldRetry(maxAttempts: 5)
                if !shouldRetry {
                    disconnect(notify: true)
                    break
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }

    private func openEventStream() async throws {
        guard let url = client.buildURL("/api/realtime") else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Invalid realtime URL")])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(client.lang, forHTTPHeaderField: "Accept-Language")
        if let token = client.authStore.token {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let delegate = EventStreamDelegate { [weak self] event, data, eventId in
            self?.handleEvent(name: event, data: data, eventId: eventId)
        }

        await state.resetReconnectAttempts()

        do {
            try await delegate.start(request: request)
        } catch {
            throw ClientResponseError(url: request.url, status: 0, response: nil, underlying: error)
        }
    }

    private func handleEvent(name: String, data: String?, eventId: String?) {
        if name == "PB_CONNECT" {
            Task {
                let waiters = await state.setClientId(eventId ?? "")
                waiters.forEach { $0.resume(returning: ()) }
                try await submitSubscriptions()
            }
            return
        }

        guard let data, let jsonData = data.data(using: .utf8) else {
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(JSONRecord.self, from: jsonData) else {
            return
        }

        Task {
            let listeners = await state.listeners(for: name)
            guard !listeners.isEmpty else { return }
            let message = RealtimeMessage(payload: payload, topic: name)
            for listener in listeners {
                listener(message)
            }
        }
    }

    private func submitSubscriptions() async throws {
        guard let clientId = await state.currentClientId() else { return }
        let activeTopics = await state.activeTopics()
        let payload: JSONRecord = [
            "clientId": AnyCodable(clientId),
            "subscriptions": AnyCodable(activeTopics)
        ]

        _ = try await client.send(
            "/api/realtime",
            options: RequestOptions(method: .post, body: .encodable(payload), requestKey: "realtime_\(clientId)", autoCancel: true),
            decodeTo: EmptyResponse.self
        )
    }

    private func removeListener(id: UUID, topicKey: String) async {
        let hasSubscriptions = await state.removeListener(key: topicKey, id: id)
        if hasSubscriptions {
            try? await submitSubscriptions()
        } else {
            disconnect()
        }
    }

    private func disconnect(notify: Bool = false) {
        eventTask?.cancel()
        eventTask = nil
        Task {
            let waiters = await state.setClientId(nil)
            waiters.forEach { $0.resume(returning: ()) }
            if notify {
                let topics = await state.activeTopics()
                onDisconnect?(topics)
            }
        }
    }

    private func makeSubscriptionKey(topic: String, options: RealtimeSubscriptionOptions?) -> String {
        guard let options else { return topic }
        var key = topic
        if let encoded = encodeSubscriptionOptions(options) {
            key += (key.contains("?") ? "&" : "?") + "options=" + encoded
        }
        return key
    }

    private func encodeSubscriptionOptions(_ options: RealtimeSubscriptionOptions) -> String? {
        struct Payload: Encodable {
            let query: [String: AnyCodable]?
            let headers: [String: String]?
        }
        var queryPayload: [String: AnyCodable] = [:]
        for (key, value) in options.query {
            guard let value else { continue }
            queryPayload[key] = AnyCodable(value)
        }
        let payload = Payload(
            query: queryPayload.isEmpty ? nil : queryPayload,
            headers: options.headers.isEmpty ? nil : options.headers
        )
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload), let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? jsonString
    }
}

private actor RealtimeActorState {
    private var clientId: String?
    private var subscriptions: [String: [UUID: RealtimeService.Listener]] = [:]
    private var subscriptionCount = 0
    private var reconnectAttempts = 0
    private var pendingConnects: [CheckedContinuation<Void, Error>] = []

    func addListener(key: String, id: UUID, listener: @escaping RealtimeService.Listener) -> Bool {
        var needsConnect = subscriptionCount == 0
        var listeners = subscriptions[key] ?? [:]
        if listeners.isEmpty {
            needsConnect = true
        }
        listeners[id] = listener
        subscriptions[key] = listeners
        subscriptionCount += 1
        return needsConnect
    }

    func removeListener(key: String, id: UUID) -> Bool {
        guard var listeners = subscriptions[key] else { return subscriptionCount > 0 }
        if listeners.removeValue(forKey: id) != nil {
            subscriptionCount = max(0, subscriptionCount - 1)
        }
        subscriptions[key] = listeners.isEmpty ? nil : listeners
        return subscriptionCount > 0
    }

    func remove(topic: String?) -> Bool {
        if let topic {
            let normalized = topic.contains("?") ? topic : topic + "?"
            for key in subscriptions.keys {
                if (key + "?").hasPrefix(normalized) {
                    if let count = subscriptions[key]?.count {
                        subscriptionCount = max(0, subscriptionCount - count)
                    }
                    subscriptions[key] = nil
                }
            }
        } else {
            subscriptions.removeAll()
            subscriptionCount = 0
        }
        return subscriptionCount > 0
    }

    func removeByPrefix(_ prefix: String) -> Bool {
        for key in subscriptions.keys {
            if key.hasPrefix(prefix) {
                if let count = subscriptions[key]?.count {
                    subscriptionCount = max(0, subscriptionCount - count)
                }
                subscriptions[key] = nil
            }
        }
        return subscriptionCount > 0
    }

    func registerContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        pendingConnects.append(continuation)
    }

    func setClientId(_ id: String?) -> [CheckedContinuation<Void, Error>] {
        clientId = id
        let waiters = pendingConnects
        pendingConnects.removeAll()
        return waiters
    }

    func currentClientId() -> String? {
        clientId
    }

    func activeTopics() -> [String] {
        subscriptions.compactMap { $0.value.isEmpty ? nil : $0.key }
    }

    func listeners(for key: String) -> [RealtimeService.Listener] {
        if let values = subscriptions[key]?.values {
            return Array(values)
        }
        return []
    }

    func shouldRetry(maxAttempts: Int) -> Bool {
        guard subscriptionCount > 0 else { return false }
        if reconnectAttempts >= maxAttempts {
            return false
        }
        reconnectAttempts += 1
        return true
    }

    func resetReconnectAttempts() {
        reconnectAttempts = 0
    }

    func hasSubscriptions() -> Bool {
        subscriptionCount > 0
    }
}

private final class EventStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var parser: ServerSentEventParser
    private var buffer = Data()
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var requestURL: URL?

    init(handler: @escaping (String, String?, String?) -> Void) {
        self.parser = ServerSentEventParser(handler: handler)
    }

    func start(request: URLRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.continuation = continuation
            self.requestURL = request.url
            let configuration = URLSessionConfiguration.default
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            self.session = session
            let task = session.dataTask(with: request)
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            completionHandler(.cancel)
            let error = ClientResponseError(url: requestURL, status: http.statusCode, response: nil)
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        while let range = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0...range.lowerBound)
            if let line = String(data: lineData, encoding: .utf8) {
                parser.process(line: line.trimmingCharacters(in: .newlines))
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        parser.process(line: "")
        session.invalidateAndCancel()
        if let error {
            continuation?.resume(throwing: error)
        } else {
            continuation?.resume(returning: ())
        }
        continuation = nil
    }
}

private struct ServerSentEventParser {
    private var currentEvent: String = "message"
    private var dataBuffer: [String] = []
    private var currentId: String?
    private let handler: (String, String?, String?) -> Void

    init(handler: @escaping (String, String?, String?) -> Void) {
        self.handler = handler
    }

    mutating func process(line: String) {
        if line.isEmpty {
            dispatchEvent()
            return
        }

        if line.hasPrefix(":") {
            return
        }

        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let field = String(parts[0])
        let value = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""

        switch field {
        case "event":
            currentEvent = value
        case "data":
            dataBuffer.append(value)
        case "id":
            currentId = value
        default:
            break
        }
    }

    private mutating func dispatchEvent() {
        let data = dataBuffer.isEmpty ? nil : dataBuffer.joined(separator: "\n")
        handler(currentEvent, data, currentId)
        currentEvent = "message"
        dataBuffer.removeAll()
        currentId = nil
    }
}
