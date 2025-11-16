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
