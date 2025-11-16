import Foundation

public struct ClientResponseError: Error {
    public let url: URL?
    public let status: Int
    public let response: [String: AnyCodable]?
    public let underlying: Error?

    public init(url: URL?, status: Int, response: [String: AnyCodable]? = nil, underlying: Error? = nil) {
        self.url = url
        self.status = status
        self.response = response
        self.underlying = underlying
    }

    public var isCancellation: Bool {
        if let error = underlying as? URLError {
            return error.code == .cancelled
        }
        return false
    }
}
