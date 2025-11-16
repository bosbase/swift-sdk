import Foundation

public struct VectorDocument: Codable {
    public var vector: [Double]
    public var id: String?
    public var metadata: [String: AnyCodable]?
    public var content: String?

    public init(vector: [Double], id: String? = nil, metadata: [String: AnyCodable]? = nil, content: String? = nil) {
        self.vector = vector
        self.id = id
        self.metadata = metadata
        self.content = content
    }
}

public struct VectorSearchOptions: Encodable {
    public var queryVector: [Double]
    public var limit: Int?
    public var filter: [String: AnyCodable]?
    public var minScore: Double?
    public var maxDistance: Double?
    public var includeDistance: Bool?
    public var includeContent: Bool?

    public init(
        queryVector: [Double],
        limit: Int? = nil,
        filter: [String: AnyCodable]? = nil,
        minScore: Double? = nil,
        maxDistance: Double? = nil,
        includeDistance: Bool? = nil,
        includeContent: Bool? = nil
    ) {
        self.queryVector = queryVector
        self.limit = limit
        self.filter = filter
        self.minScore = minScore
        self.maxDistance = maxDistance
        self.includeDistance = includeDistance
        self.includeContent = includeContent
    }

    enum CodingKeys: String, CodingKey {
        case queryVector
        case limit
        case filter
        case minScore
        case maxDistance
        case includeDistance
        case includeContent
    }
}

public struct VectorSearchResult: Decodable {
    public let document: VectorDocument
    public let score: Double
    public let distance: Double?
}

public struct VectorSearchResponse: Decodable {
    public let results: [VectorSearchResult]
    public let totalMatches: Int?
    public let queryTime: Int?
}

public struct VectorBatchInsertOptions: Encodable {
    public var documents: [VectorDocument]
    public var skipDuplicates: Bool?

    public init(documents: [VectorDocument], skipDuplicates: Bool? = nil) {
        self.documents = documents
        self.skipDuplicates = skipDuplicates
    }

    enum CodingKeys: String, CodingKey {
        case documents
        case skipDuplicates
    }
}

public struct VectorInsertResponse: Decodable {
    public let id: String
    public let success: Bool
}

public struct VectorBatchInsertResponse: Decodable {
    public let insertedCount: Int
    public let failedCount: Int
    public let ids: [String]
    public let errors: [String]?
}

public struct VectorCollectionConfig: Encodable {
    public var dimension: Int?
    public var distance: String?
    public var options: [String: AnyCodable]?

    public init(dimension: Int? = nil, distance: String? = nil, options: [String: AnyCodable]? = nil) {
        self.dimension = dimension
        self.distance = distance
        self.options = options
    }
}

public struct VectorCollectionInfo: Decodable {
    public let name: String
    public let count: Int?
    public let dimension: Int?
}
