import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct PubSubMessage {
    public let id: String
    public let topic: String
    public let created: String
    public let data: AnyCodable?
}

public struct PublishAck {
    public let id: String
    public let topic: String
    public let created: String
}

private struct PubSubAckWaiter {
    let fulfill: (JSONRecord) -> Void
    let reject: (Error) -> Void
    let cancel: () -> Void
}

private struct PubSubEnvelope: Codable {
    let type: String
    let id: String?
    let topic: String?
    let created: String?
    let requestId: String?
    let clientId: String?
    let message: String?
    let data: AnyCodable?
}

public final class PubSubService: BaseService, @unchecked Sendable {
    public typealias Listener = @Sendable (PubSubMessage) -> Void

    public var isConnected: Bool {
        queue.sync { isReady }
    }

    private let queue = DispatchQueue(label: "com.bosbase.pubsub")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var socket: URLSessionWebSocketTask?
    private var subscriptions: [String: [UUID: Listener]] = [:]
    private var pendingAcks: [String: PubSubAckWaiter] = [:]
    private var pendingConnects: [CheckedContinuation<Void, Error>] = []
    private var reconnectAttempts = 0
    private var manualClose = false
    private var isReady = false
    private var clientId: String = ""
    private var connectTimeoutTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?

    private let predefinedReconnectIntervals: [Double] = [0.2, 0.3, 0.5, 1.0, 1.2, 1.5, 2.0]
    private let ackTimeoutSeconds: Double = 10
    private let maxConnectTimeoutSeconds: Double = 15

    public func publish(topic: String, data: AnyCodable?) async throws -> PublishAck {
        guard !topic.isEmpty else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("topic must be set.")])
        }

        try await ensureSocket()

        let requestId = nextRequestId()
        let ackTask = Task { () throws -> PublishAck in
            try await self.waitForAck(requestId: requestId) { payload in
                PublishAck(
                    id: payload["id"]?.value as? String ?? "",
                    topic: payload["topic"]?.value as? String ?? topic,
                    created: payload["created"]?.value as? String ?? ""
                )
            }
        }

        try await sendEnvelope([
            "type": AnyCodable("publish"),
            "topic": AnyCodable(topic),
            "data": data ?? AnyCodable(Optional<String>.none),
            "requestId": AnyCodable(requestId)
        ])

        return try await ackTask.value
    }

    public func subscribe(
        topic: String,
        callback: @escaping Listener
    ) async throws -> () -> Void {
        guard !topic.isEmpty else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("topic must be set.")])
        }

        let identifier = UUID()
        let isFirstListener = queue.sync { () -> Bool in
            var listeners = subscriptions[topic] ?? [:]
            let isFirst = listeners.isEmpty
            listeners[identifier] = callback
            subscriptions[topic] = listeners
            return isFirst
        }

        try await ensureSocket()

        if isFirstListener {
            let requestId = nextRequestId()
            _ = Task {
                _ = try? await self.waitForAck(requestId: requestId) { _ in true }
            }
            try await sendEnvelope([
                "type": AnyCodable("subscribe"),
                "topic": AnyCodable(topic),
                "requestId": AnyCodable(requestId)
            ])
        }

        return { [weak self] in
            Task {
                try? await self?.removeListener(topic: topic, id: identifier)
            }
        }
    }

    public func unsubscribe(_ topic: String? = nil) async throws {
        let topicsToRemove: [String] = queue.sync {
            if let topic {
                subscriptions.removeValue(forKey: topic)
                return [topic]
            }
            let all = Array(subscriptions.keys)
            subscriptions.removeAll()
            return all
        }

        if topicsToRemove.isEmpty {
            return
        }

        if topic == nil {
            try await sendEnvelope(["type": AnyCodable("unsubscribe")])
            disconnect()
            return
        }

        try await sendUnsubscribe(topic: topic!)
        if !hasSubscriptions() {
            disconnect()
        }
    }

    public func disconnect() {
        queue.async {
            self.manualClose = true
            self.isReady = false
            self.connectTimeoutTask?.cancel()
            self.reconnectTask?.cancel()
            self.socket?.cancel()
            self.socket = nil

            let err = ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("pubsub connection closed")])
            self.rejectAllPending(err)
            let waiters = self.pendingConnects
            self.pendingConnects.removeAll()
            waiters.forEach { $0.resume(throwing: err) }
        }
    }

    // MARK: - Internals

    private func ensureSocket() async throws {
        if queue.sync(execute: { isReady }) {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if self.isReady {
                    continuation.resume(returning: ())
                    return
                }
                let shouldStart = self.pendingConnects.isEmpty
                self.pendingConnects.append(continuation)
                if shouldStart {
                    Task {
                        await self.startConnect()
                    }
                }
            }
        }
    }

    private func startConnect() async {
        let url: URL
        do {
            url = try buildWebSocketURL()
        } catch {
            await handleConnectError(error)
            return
        }

        let task = client.session.webSocketTask(with: url)
        queue.async {
            self.manualClose = false
            self.isReady = false
            self.socket = task
            self.connectTimeoutTask?.cancel()
            self.connectTimeoutTask = Task { [weak self] in
                let nanos = UInt64((self?.maxConnectTimeoutSeconds ?? 0) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                await self?.handleConnectError(
                    ClientResponseError(
                        url: url,
                        status: 0,
                        response: ["message": AnyCodable("WebSocket connect took too long.")]
                    )
                )
            }
        }

        task.resume()
        listen(task)
    }

    private func listen(_ task: URLSessionWebSocketTask) {
        Task.detached { [weak self] in
            while let strongSelf = self {
                do {
                    let message = try await task.receive()
                    switch message {
                    case .string(let text):
                        strongSelf.handleMessage(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            strongSelf.handleMessage(text)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    await self?.handleClose(becauseOf: error)
                    break
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        guard let envelope = try? decoder.decode(PubSubEnvelope.self, from: data) else { return }

        switch envelope.type {
        case "ready":
            handleConnected(clientId: envelope.clientId ?? "")
        case "message":
            guard let topic = envelope.topic else { return }
            let listeners = queue.sync { subscriptions[topic]?.values.map { $0 } ?? [] }
            if listeners.isEmpty { return }
            let msg = PubSubMessage(
                id: envelope.id ?? "",
                topic: topic,
                created: envelope.created ?? "",
                data: envelope.data
            )
            listeners.forEach { listener in
                listener(msg)
            }
        case "published", "subscribed", "unsubscribed", "pong":
            if let requestId = envelope.requestId {
                let payload = envelopeToRecord(envelope)
                resolvePending(requestId: requestId, payload: payload)
            }
        case "error":
            if let requestId = envelope.requestId {
                let err = ClientResponseError(
                    url: nil,
                    status: 0,
                    response: ["message": AnyCodable(envelope.message ?? "pubsub error")]
                )
                rejectPending(requestId: requestId, error: err)
            }
        default:
            break
        }
    }

    private func handleConnected(clientId: String) {
        queue.async {
            let shouldResubscribe = self.reconnectAttempts > 0
            self.reconnectAttempts = 0
            self.isReady = true
            self.clientId = clientId
            self.connectTimeoutTask?.cancel()
            self.connectTimeoutTask = nil

            let waiters = self.pendingConnects
            self.pendingConnects.removeAll()
            waiters.forEach { $0.resume(returning: ()) }

            if shouldResubscribe {
                let topics = Array(self.subscriptions.keys)
                Task {
                    for topic in topics {
                        try? await self.sendSubscribe(topic: topic)
                    }
                }
            }
        }
    }

    private func handleClose(becauseOf error: Error? = nil) async {
        let err = error ?? ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("pubsub connection closed")])
        queue.async {
            self.isReady = false
            self.socket = nil
            self.connectTimeoutTask?.cancel()
            self.connectTimeoutTask = nil
            self.reconnectTask?.cancel()
            self.reconnectTask = nil

            self.rejectAllPending(err)

            let waiters = self.pendingConnects
            self.pendingConnects.removeAll()
            waiters.forEach { $0.resume(throwing: err) }

            if self.manualClose {
                return
            }

            if self.subscriptions.isEmpty {
                return
            }

            let delay = self.predefinedReconnectIntervals[min(self.reconnectAttempts, self.predefinedReconnectIntervals.count - 1)]
            self.reconnectAttempts += 1
            self.reconnectTask = Task { [weak self] in
                let nanos = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanos)
                await self?.startConnect()
            }
        }
    }

    private func handleConnectError(_ error: Error) async {
        await handleClose(becauseOf: error)
    }

    private func sendEnvelope(_ payload: JSONRecord) async throws {
        try await ensureSocket()
        let text = String(data: try encoder.encode(payload), encoding: .utf8) ?? "{}"

        guard let ws = queue.sync(execute: { socket }) else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Unable to send websocket message - socket not initialized.")])
        }

        try await ws.send(.string(text))
    }

    private func sendSubscribe(topic: String) async throws {
        let requestId = nextRequestId()
        _ = Task {
            _ = try? await self.waitForAck(requestId: requestId) { _ in true }
        }
        try await sendEnvelope([
            "type": AnyCodable("subscribe"),
            "topic": AnyCodable(topic),
            "requestId": AnyCodable(requestId)
        ])
    }

    private func sendUnsubscribe(topic: String) async throws {
        let requestId = nextRequestId()
        _ = Task {
            _ = try? await self.waitForAck(requestId: requestId) { _ in true }
        }
        try await sendEnvelope([
            "type": AnyCodable("unsubscribe"),
            "topic": AnyCodable(topic),
            "requestId": AnyCodable(requestId)
        ])
    }

    private func waitForAck<T>(
        requestId: String,
        mapper: @escaping (JSONRecord) throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let timeoutWork = DispatchWorkItem { [weak self] in
                    guard let self else { return }
                    guard let waiter = self.pendingAcks.removeValue(forKey: requestId) else { return }
                    waiter.reject(
                        ClientResponseError(
                            url: nil,
                            status: 0,
                            response: ["message": AnyCodable("Timed out waiting for pubsub response.")]
                        )
                    )
                }
                let delayMilliseconds = Int(self.ackTimeoutSeconds * 1000)
                let deadline = DispatchTime.now() + .milliseconds(delayMilliseconds)
                self.queue.asyncAfter(deadline: deadline, execute: timeoutWork)

                self.pendingAcks[requestId] = PubSubAckWaiter(
                    fulfill: { payload in
                        do {
                            let value = try mapper(payload)
                            continuation.resume(returning: value)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    },
                    reject: { error in
                        continuation.resume(throwing: error)
                    },
                    cancel: {
                        timeoutWork.cancel()
                    }
                )
            }
        }
    }

    private func resolvePending(requestId: String, payload: JSONRecord) {
        queue.async {
            guard let waiter = self.pendingAcks.removeValue(forKey: requestId) else { return }
            waiter.cancel()
            waiter.fulfill(payload)
        }
    }

    private func rejectPending(requestId: String, error: Error) {
        queue.async {
            guard let waiter = self.pendingAcks.removeValue(forKey: requestId) else { return }
            waiter.cancel()
            waiter.reject(error)
        }
    }

    private func rejectAllPending(_ error: Error) {
        queue.async {
            let waiters = self.pendingAcks.values
            self.pendingAcks.removeAll()
            waiters.forEach { waiter in
                waiter.cancel()
                waiter.reject(error)
            }
        }
    }

    private func removeListener(topic: String, id: UUID) async throws {
        let shouldUnsubscribe = queue.sync { () -> Bool in
            guard var listeners = subscriptions[topic] else { return false }
            listeners.removeValue(forKey: id)
            if listeners.isEmpty {
                subscriptions.removeValue(forKey: topic)
                return true
            }
            subscriptions[topic] = listeners
            return false
        }

        if shouldUnsubscribe {
            try await sendUnsubscribe(topic: topic)
            if !hasSubscriptions() {
                disconnect()
            }
        }
    }

    private func hasSubscriptions() -> Bool {
        queue.sync {
            subscriptions.values.contains { !$0.isEmpty }
        }
    }

    private func buildWebSocketURL() throws -> URL {
        guard let url = client.buildURL("/api/pubsub") else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Invalid pubsub URL")])
        }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ClientResponseError(url: url, status: 0, response: ["message": AnyCodable("Invalid pubsub URL")])
        }

        var items = components.queryItems ?? []
        if let token = client.authStore.token {
            items.append(URLQueryItem(name: "token", value: token))
        }
        if !items.isEmpty {
            components.queryItems = items
        }
        components.scheme = (components.scheme == "https") ? "wss" : "ws"

        guard let finalURL = components.url else {
            throw ClientResponseError(url: url, status: 0, response: ["message": AnyCodable("Invalid pubsub URL")])
        }
        return finalURL
    }

    private func envelopeToRecord(_ envelope: PubSubEnvelope) -> JSONRecord {
        var record: JSONRecord = [:]
        if let id = envelope.id { record["id"] = AnyCodable(id) }
        if let topic = envelope.topic { record["topic"] = AnyCodable(topic) }
        if let created = envelope.created { record["created"] = AnyCodable(created) }
        if let requestId = envelope.requestId { record["requestId"] = AnyCodable(requestId) }
        if let message = envelope.message { record["message"] = AnyCodable(message) }
        if let data = envelope.data { record["data"] = data }
        if let clientId = envelope.clientId { record["clientId"] = AnyCodable(clientId) }
        record["type"] = AnyCodable(envelope.type)
        return record
    }

    private func nextRequestId() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}
