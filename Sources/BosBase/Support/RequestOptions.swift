import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

public enum RequestBody {
    case empty
    case json(AnyEncodable)
    case data(Data, contentType: String?)
    case multipart(MultipartFormData)

    public static func encodable<T: Encodable>(_ value: T) -> RequestBody {
        return .json(AnyEncodable(value))
    }
}

public struct RequestOptions {
    public var method: HTTPMethod
    public var headers: [String: String]
    public var query: [String: Any?]
    public var body: RequestBody
    public var timeout: TimeInterval?
    public var requestKey: String?
    public var autoCancel: Bool?

    public init(
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        query: [String: Any?] = [:],
        body: RequestBody = .empty,
        timeout: TimeInterval? = nil,
        requestKey: String? = nil,
        autoCancel: Bool? = nil
    ) {
        self.method = method
        self.headers = headers
        self.query = query
        self.body = body
        self.timeout = timeout
        self.requestKey = requestKey
        self.autoCancel = autoCancel
    }
}

public extension RequestBody {
    static func multipart(_ build: (inout MultipartFormData) -> Void) -> RequestBody {
        var formData = MultipartFormData()
        build(&formData)
        return .multipart(formData)
    }

    static func multipartData(_ formData: MultipartFormData) -> RequestBody {
        return .multipart(formData)
    }
}
