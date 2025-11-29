import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class BosBaseClient: @unchecked Sendable {
    public typealias BeforeSendHook = (inout URLRequest) async throws -> Void
    public typealias AfterSendHook = (HTTPURLResponse, Data) async throws -> Data

    public let baseURL: URL
    public var lang: String
    public var timeout: TimeInterval
    public var authStore: AuthStore
    public var beforeSend: BeforeSendHook?
    public var afterSend: AfterSendHook?

    public lazy var collections = CollectionService(client: self)
    public lazy var files = FileService(client: self)
    public lazy var settings = SettingsService(client: self)
    public lazy var logs = LogService(client: self)
    public lazy var realtime = RealtimeService(client: self)
    public lazy var health = HealthService(client: self)
    public lazy var backups = BackupService(client: self)
    public lazy var crons = CronService(client: self)
    public lazy var vectors = VectorService(client: self)
    public lazy var llmDocuments = LLMDocumentService(client: self)
    public lazy var langchaingo = LangChaingoService(client: self)
    public lazy var caches = CacheService(client: self)
    public lazy var graphql = GraphQLService(client: self)
    public lazy var sql = SQLService(client: self)
    public lazy var pubsub = PubSubService(client: self)

    let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private var recordServices: [String: RecordService] = [:]
    private let servicesLock = NSLock()
    private let requestTracker = RequestTracker()
    private var enableAutoCancellation = true

    public init(
        baseURL: URL,
        authStore: AuthStore = AuthStore(),
        lang: String = "en-US",
        timeout: TimeInterval = 60.0,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.authStore = authStore
        self.lang = lang
        self.timeout = timeout
        self.session = session

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder
    }

    public convenience init(
        baseURLString: String,
        authStore: AuthStore = AuthStore(),
        lang: String = "en-US",
        timeout: TimeInterval = 60.0,
        session: URLSession = .shared
    ) throws {
        guard let url = URL(string: baseURLString) else {
            let errorBody: JSONRecord = [
                "message": AnyCodable("Invalid base URL")
            ]
            throw ClientResponseError(url: nil, status: 0, response: errorBody)
        }
        self.init(baseURL: url, authStore: authStore, lang: lang, timeout: timeout, session: session)
    }

    public func collection(_ idOrName: String) -> RecordService {
        servicesLock.lock()
        if let service = recordServices[idOrName] {
            servicesLock.unlock()
            return service
        }
        let service = RecordService(client: self, collectionIdOrName: idOrName)
        recordServices[idOrName] = service
        servicesLock.unlock()
        return service
    }

    public func createBatch() -> BatchService {
        return BatchService(client: self)
    }

    @discardableResult
    public func autoCancellation(_ enable: Bool) -> BosBaseClient {
        enableAutoCancellation = enable
        if !enable {
            cancelAllRequests()
        }
        return self
    }

    public func cancelRequest(_ key: String) {
        Task {
            await requestTracker.cancel(key: key)
        }
    }

    public func cancelAllRequests() {
        Task {
            await requestTracker.cancelAll()
        }
    }

    public func filter(_ raw: String, params: [String: Any?]) -> String {
        var expression = raw
        for (key, value) in params {
            let placeholder = "{:\(key)}"
            let replacement = formatFilterValue(value)
            expression = expression.replacingOccurrences(of: placeholder, with: replacement)
        }
        return expression
    }

    public func buildURL(_ path: String, query: [String: Any?]? = nil) -> URL? {
        var resolved = path
        if resolved.hasPrefix("/") {
            resolved.removeFirst()
        }
        var url = baseURL
        if !resolved.isEmpty {
            url.appendPathComponent(resolved)
        }
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let query {
                let items = QueryEncoder.encode(query)
                if !items.isEmpty {
                    components.queryItems = (components.queryItems ?? []) + items
                }
            }
            return components.url
        }
        return url
    }

    @discardableResult
    public func send<T: Decodable>(
        _ path: String,
        options: RequestOptions = RequestOptions(),
        decodeTo type: T.Type = T.self
    ) async throws -> T {
        guard let url = buildURL(path, query: options.query) else {
            let errorBody: JSONRecord = [
                "message": AnyCodable("Unable to build request URL")
            ]
            throw ClientResponseError(url: nil, status: 0, response: errorBody)
        }

        var request = URLRequest(url: url)
        request.httpMethod = options.method.rawValue
        request.timeoutInterval = options.timeout ?? timeout

        var headers = options.headers
        headers["Accept-Language"] = headers["Accept-Language"] ?? lang
        if authStore.isValid() && headers["Authorization"] == nil {
            if let token = authStore.token {
                headers["Authorization"] = token
            }
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        switch options.body {
        case .empty:
            break
        case let .json(payload):
            request.httpBody = try jsonEncoder.encode(payload)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        case let .data(data, contentType):
            request.httpBody = data
            if let contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        case let .multipart(formData):
            let built = formData.build()
            request.httpBody = built.body
            request.setValue(built.contentType, forHTTPHeaderField: "Content-Type")
        }

        if let beforeSend {
            try await beforeSend(&request)
        }

        var resolvedRequestKey: String?
        let shouldAutoCancel = (options.autoCancel ?? true) && enableAutoCancellation
        if let explicitKey = options.requestKey, !explicitKey.isEmpty {
            resolvedRequestKey = explicitKey
        } else if shouldAutoCancel {
            resolvedRequestKey = defaultRequestKey(for: options.method, path: path)
        }

        let fetchTask = Task<(Data, URLResponse), Error> {
            try await self.session.data(for: request)
        }

        if let resolvedRequestKey {
            await requestTracker.store(key: resolvedRequestKey, task: fetchTask, cancelPrevious: shouldAutoCancel)
        }

        let result: (Data, URLResponse)
        do {
            result = try await fetchTask.value
        } catch {
            if let resolvedRequestKey {
                await requestTracker.remove(key: resolvedRequestKey)
            }
            if (error as? CancellationError) != nil {
                throw ClientResponseError(url: request.url, status: 0, response: nil, underlying: error)
            }
            throw ClientResponseError(url: request.url, status: 0, response: nil, underlying: error)
        }

        if let resolvedRequestKey {
            await requestTracker.remove(key: resolvedRequestKey)
        }
        let (data, response) = result

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientResponseError(url: request.url, status: 0, response: nil)
        }

        var responseData = data
        if let afterSend {
            responseData = try await afterSend(httpResponse, data)
        }

        if httpResponse.statusCode >= 400 {
            let errorBody = try? jsonDecoder.decode([String: AnyCodable].self, from: responseData)
            throw ClientResponseError(url: httpResponse.url, status: httpResponse.statusCode, response: errorBody)
        }

        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        if responseData.isEmpty {
            if T.self == Data.self {
                return Data() as! T
            }
            if T.self == JSONRecord.self {
                return [:] as! T
            }
        }

        do {
            return try jsonDecoder.decode(T.self, from: responseData)
        } catch {
            throw ClientResponseError(url: httpResponse.url, status: httpResponse.statusCode, response: nil, underlying: error)
        }
    }

    private func defaultRequestKey(for method: HTTPMethod, path: String) -> String {
        return "\(method.rawValue.uppercased()) \(path)"
    }

    func decodeRecord<T: Decodable>(_ record: JSONRecord, as type: T.Type) throws -> T {
        if T.self == JSONRecord.self {
            return record as! T
        }
        let data = try jsonEncoder.encode(record)
        return try jsonDecoder.decode(T.self, from: data)
    }

    func transformAuthResponse<RecordType: Decodable>(
        _ response: RecordAuthResponse<JSONRecord>,
        to type: RecordType.Type
    ) throws -> RecordAuthResponse<RecordType> {
        let record = try decodeRecord(response.record, as: RecordType.self)
        return RecordAuthResponse(token: response.token, record: record, meta: response.meta)
    }

    private func formatFilterValue(_ value: Any?) -> String {
        guard let value else { return "null" }
        switch value {
        case let boolValue as Bool:
            return boolValue ? "true" : "false"
        case let number as NSNumber:
            return number.stringValue
        case let string as String:
            return "'\(string.replacingOccurrences(of: "'", with: "\\'"))'"
        case let date as Date:
            return "'\(BosBaseClient.filterDateFormatter.string(from: date))'"
        default:
            if let encodable = value as? Encodable {
                if let data = try? jsonEncoder.encode(AnyEncodable(encodable)),
                   let string = String(data: data, encoding: .utf8) {
                    return "'\(string.replacingOccurrences(of: "'", with: "\\'"))'"
                }
            }
            return "'\(String(describing: value))'"
        }
    }

private static let filterDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()
}

private actor RequestTracker {
    private var tasks: [String: Task<(Data, URLResponse), Error>] = [:]

    func store(key: String, task: Task<(Data, URLResponse), Error>, cancelPrevious: Bool) {
        if cancelPrevious, let previous = tasks[key] {
            previous.cancel()
        }
        tasks[key] = task
    }

    func remove(key: String) {
        tasks[key] = nil
    }

    func cancel(key: String) {
        tasks[key]?.cancel()
        tasks[key] = nil
    }

    func cancelAll() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
}
