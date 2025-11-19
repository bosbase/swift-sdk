import Foundation

public struct LangChaingoModelConfig: Codable {
    public var provider: String?
    public var model: String?
    public var apiKey: String?
    public var baseURL: String?

    public init(provider: String? = nil, model: String? = nil, apiKey: String? = nil, baseURL: String? = nil) {
        self.provider = provider
        self.model = model
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    enum CodingKeys: String, CodingKey {
        case provider
        case model
        case apiKey = "apiKey"
        case baseURL = "baseUrl"
    }
}

public struct LangChaingoCompletionMessage: Codable {
    public enum Role: String, Codable {
        case system
        case user
        case assistant
        case tool
    }

    public var role: Role
    public var content: String?
    public var name: String?
    public var toolCallID: String?

    public init(role: Role, content: String? = nil, name: String? = nil, toolCallID: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
        self.toolCallID = toolCallID
    }

    enum CodingKeys: String, CodingKey {
        case role
        case content
        case name
        case toolCallID = "toolCallId"
    }
}

public struct LangChaingoCompletionRequest: Codable {
    public var model: LangChaingoModelConfig?
    public var messages: [LangChaingoCompletionMessage]?
    public var temperature: Double?
    public var maxTokens: Int?
    public var stream: Bool?

    public init(
        model: LangChaingoModelConfig? = nil,
        messages: [LangChaingoCompletionMessage]? = nil,
        temperature: Double? = nil,
        maxTokens: Int? = nil,
        stream: Bool? = nil
    ) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

public struct LangChaingoFunctionCall: Codable {
    public var name: String?
    public var arguments: [String: AnyCodable]?
}

public struct LangChaingoToolCall: Codable {
    public var id: String?
    public var functionCall: LangChaingoFunctionCall?
}

public struct LangChaingoCompletionResponse: Codable {
    public var content: String?
    public var functionCall: LangChaingoFunctionCall?
    public var toolCalls: [LangChaingoToolCall]?
}

public struct LangChaingoRAGFilters: Codable {
    public var collection: String?
    public var metadata: [String: AnyCodable]?
    public var limit: Int?
    public var minScore: Double?
    public var query: String?
    public var vector: [Double]?

    public init(
        collection: String? = nil,
        metadata: [String: AnyCodable]? = nil,
        limit: Int? = nil,
        minScore: Double? = nil,
        query: String? = nil,
        vector: [Double]? = nil
    ) {
        self.collection = collection
        self.metadata = metadata
        self.limit = limit
        self.minScore = minScore
        self.query = query
        self.vector = vector
    }
}

public struct LangChaingoRAGRequest: Codable {
    public var model: LangChaingoModelConfig?
    public var query: String
    public var filters: LangChaingoRAGFilters?
    public var maxTokens: Int?

    public init(model: LangChaingoModelConfig? = nil, query: String, filters: LangChaingoRAGFilters? = nil, maxTokens: Int? = nil) {
        self.model = model
        self.query = query
        self.filters = filters
        self.maxTokens = maxTokens
    }
}

public struct LangChaingoSourceDocument: Codable {
    public var id: String?
    public var score: Double?
    public var content: String?
    public var metadata: [String: AnyCodable]?
}

public struct LangChaingoRAGResponse: Codable {
    public var answer: String?
    public var sources: [LangChaingoSourceDocument]?
}

public struct LangChaingoDocumentQueryRequest: Codable {
    public var model: LangChaingoModelConfig?
    public var collection: String
    public var query: String
    public var topK: Int?
    public var scoreThreshold: Double?
    public var filters: LangChaingoRAGFilters?
    public var promptTemplate: String?
    public var returnSources: Bool?

    public init(
        model: LangChaingoModelConfig? = nil,
        collection: String,
        query: String,
        topK: Int? = nil,
        scoreThreshold: Double? = nil,
        filters: LangChaingoRAGFilters? = nil,
        promptTemplate: String? = nil,
        returnSources: Bool? = nil
    ) {
        self.model = model
        self.collection = collection
        self.query = query
        self.topK = topK
        self.scoreThreshold = scoreThreshold
        self.filters = filters
        self.promptTemplate = promptTemplate
        self.returnSources = returnSources
    }

    enum CodingKeys: String, CodingKey {
        case model
        case collection
        case query
        case topK
        case scoreThreshold
        case filters
        case promptTemplate
        case returnSources
    }
}

// DocumentQueryResponse is the same as RAGResponse
public typealias LangChaingoDocumentQueryResponse = LangChaingoRAGResponse

public struct LangChaingoSQLRequest: Codable {
    public var model: LangChaingoModelConfig?
    public var query: String
    public var tables: [String]?
    public var topK: Int?

    public init(
        model: LangChaingoModelConfig? = nil,
        query: String,
        tables: [String]? = nil,
        topK: Int? = nil
    ) {
        self.model = model
        self.query = query
        self.tables = tables
        self.topK = topK
    }
}

public struct LangChaingoSQLResponse: Codable {
    public var sql: String
    public var answer: String
    public var columns: [String]?
    public var rows: [[String]]?
    public var rawResult: String?

    public init(
        sql: String,
        answer: String,
        columns: [String]? = nil,
        rows: [[String]]? = nil,
        rawResult: String? = nil
    ) {
        self.sql = sql
        self.answer = answer
        self.columns = columns
        self.rows = rows
        self.rawResult = rawResult
    }

    enum CodingKeys: String, CodingKey {
        case sql
        case answer
        case columns
        case rows
        case rawResult
    }
}
