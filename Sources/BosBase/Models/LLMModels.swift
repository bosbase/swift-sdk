import Foundation

public struct LLMDocument: Codable {
    public var content: String
    public var id: String?
    public var metadata: [String: String]?
    public var embedding: [Double]?

    public init(content: String, id: String? = nil, metadata: [String: String]? = nil, embedding: [Double]? = nil) {
        self.content = content
        self.id = id
        self.metadata = metadata
        self.embedding = embedding
    }
}

public struct LLMDocumentUpdate: Codable {
    public var content: String?
    public var metadata: [String: String]?
    public var embedding: [Double]?

    public init(content: String? = nil, metadata: [String: String]? = nil, embedding: [Double]? = nil) {
        self.content = content
        self.metadata = metadata
        self.embedding = embedding
    }
}

public struct LLMQueryOptions: Codable {
    public var queryText: String?
    public var queryEmbedding: [Double]?
    public var limit: Int?
    public var whereClause: [String: String]?
    public var negative: [String: AnyCodable]?

    public init(queryText: String? = nil, queryEmbedding: [Double]? = nil, limit: Int? = nil, whereClause: [String: String]? = nil, negative: [String: AnyCodable]? = nil) {
        self.queryText = queryText
        self.queryEmbedding = queryEmbedding
        self.limit = limit
        self.whereClause = whereClause
        self.negative = negative
    }

    enum CodingKeys: String, CodingKey {
        case queryText
        case queryEmbedding
        case limit
        case whereClause = "where"
        case negative
    }
}

public struct LLMQueryResult: Codable {
    public let id: String
    public let content: String
    public let metadata: [String: String]
    public let similarity: Double
}
