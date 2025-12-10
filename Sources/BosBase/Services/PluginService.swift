import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum PluginHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    var asHTTPMethod: HTTPMethod {
        switch self {
        case .get: return .get
        case .post: return .post
        case .put: return .put
        case .patch: return .patch
        case .delete: return .delete
        case .head: return .head
        case .options: return .options
        }
    }
}

public struct PluginEvent {
    public let event: String
    public let data: String?
    public let id: String?
}

public final class PluginEventStream {
    public typealias Handler = @Sendable (PluginEvent) -> Void

    private var delegate: PluginEventStreamDelegate?
    private var task: Task<Void, Never>?

    init(request: URLRequest, onEvent: @escaping Handler, onError: ((Error) -> Void)?) throws {
        let delegate = PluginEventStreamDelegate(onEvent: onEvent)
        self.delegate = delegate
        self.task = Task {
            do {
                try await delegate.start(request: request)
            } catch {
                onError?(error)
            }
        }
    }

    deinit {
        close()
    }

    public func close() {
        delegate?.close()
        task?.cancel()
    }
}

public final class PluginService: BaseService {
    /**
     Sends an HTTP request to the plugin proxy endpoint.
     */
    public func request<Response: Decodable>(
        _ method: PluginHTTPMethod,
        path: String = "",
        body: RequestBody = .empty,
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        requestKey: String? = nil,
        autoCancel: Bool? = nil
    ) async throws -> Response {
        let normalizedPath = normalizePath(path)
        let mergedQuery = mergeQuery(path: path, extra: query)

        let options = RequestOptions(
            method: method.asHTTPMethod,
            headers: headers,
            query: mergedQuery,
            body: body,
            timeout: timeout,
            requestKey: requestKey,
            autoCancel: autoCancel
        )
        return try await client.send(normalizedPath, options: options, decodeTo: Response.self)
    }

    /**
     Opens a server-sent events stream to a plugin endpoint.
     */
    public func openEventStream(
        path: String = "",
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        onEvent: @escaping PluginEventStream.Handler,
        onError: ((Error) -> Void)? = nil
    ) throws -> PluginEventStream {
        let normalizedPath = normalizePath(path)
        var mergedQuery = mergeQuery(path: path, extra: query)
        if client.authStore.isValid(), mergedQuery["token"] == nil {
            mergedQuery["token"] = client.authStore.token
        }

        guard let url = client.buildURL(normalizedPath, query: mergedQuery) else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Unable to build plugin SSE URL.")])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue(client.lang, forHTTPHeaderField: "Accept-Language")

        var mergedHeaders = headers
        if client.authStore.isValid(), mergedHeaders["Authorization"] == nil {
            mergedHeaders["Authorization"] = client.authStore.token
        }
        for (key, value) in mergedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try PluginEventStream(request: request, onEvent: onEvent, onError: onError)
    }

    /**
     Opens a WebSocket connection to a plugin endpoint.
     */
    public func openWebSocket(
        path: String = "",
        query: [String: Any?] = [:],
        headers: [String: String] = [:],
        protocols: [String] = []
    ) throws -> URLSessionWebSocketTask {
        let normalizedPath = normalizePath(path)
        var mergedQuery = mergeQuery(path: path, extra: query)
        if client.authStore.isValid(), mergedQuery["token"] == nil {
            mergedQuery["token"] = client.authStore.token
        }

        guard let baseURL = client.buildURL(normalizedPath, query: mergedQuery),
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Unable to build plugin WebSocket URL.")])
        }

        if components.scheme == "https" {
            components.scheme = "wss"
        } else {
            components.scheme = "ws"
        }

        guard let wsURL = components.url else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Unable to build plugin WebSocket URL.")])
        }

        var request = URLRequest(url: wsURL)
        request.timeoutInterval = client.timeout
        request.setValue(client.lang, forHTTPHeaderField: "Accept-Language")

        var mergedHeaders = headers
        if client.authStore.isValid(), mergedHeaders["Authorization"] == nil {
            mergedHeaders["Authorization"] = client.authStore.token
        }
        for (key, value) in mergedHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if os(Linux)
        // FoundationNetworking on Linux does not expose the URLRequest-based initializer.
        let configuration = client.session.configuration
        var additionalHeaders = (configuration.httpAdditionalHeaders as? [String: Any]) ?? [:]
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            additionalHeaders[key] = value
        }
        configuration.httpAdditionalHeaders = additionalHeaders
        let session = URLSession(
            configuration: configuration,
            delegate: client.session.delegate,
            delegateQueue: client.session.delegateQueue
        )
        let task = session.webSocketTask(with: wsURL, protocols: protocols)
        #else
        let task = client.session.webSocketTask(with: request, protocols: protocols)
        #endif
        task.resume()
        return task
    }

    private func normalizePath(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "/api/plugins"
        }
        if let question = trimmed.firstIndex(of: "?") {
            trimmed = String(trimmed[..<question])
        }
        while trimmed.hasPrefix("/") {
            trimmed.removeFirst()
        }
        if trimmed.hasPrefix("api/plugins") {
            return "/" + trimmed
        }
        return "/api/plugins/" + trimmed
    }

    private func mergeQuery(path: String, extra: [String: Any?]) -> [String: Any?] {
        var merged = extra
        guard path.contains("?"),
              let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: true).last else {
            return merged
        }
        let inline = String(parts)
        guard !inline.isEmpty, let components = URLComponents(string: "?" + inline) else {
            return merged
        }
        for item in components.queryItems ?? [] {
            if merged[item.name] == nil {
                merged[item.name] = item.value
            }
        }
        return merged
    }
}

private final class PluginEventStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var parser: PluginServerSentEventParser
    private var buffer = Data()
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var requestURL: URL?

    init(onEvent: @escaping PluginEventStream.Handler) {
        self.parser = PluginServerSentEventParser { event, data, eventId in
            onEvent(PluginEvent(event: event, data: data, id: eventId))
        }
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

    func close() {
        session?.invalidateAndCancel()
        session = nil
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

private struct PluginServerSentEventParser {
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
