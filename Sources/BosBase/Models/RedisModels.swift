import Foundation

public struct RedisKeySummary: Decodable {
    public let key: String
}

public struct RedisEntry: Decodable {
    public let key: String
    public let value: AnyCodable
    public let ttlSeconds: Int?
}

public struct RedisListPage: Decodable {
    public let cursor: String
    public let items: [RedisKeySummary]
}
