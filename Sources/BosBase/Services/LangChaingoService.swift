import Foundation

public final class LangChaingoService: BaseService {
    private let basePath = "/api/langchaingo"

    public func completions(
        _ payload: LangChaingoCompletionRequest,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> LangChaingoCompletionResponse {
        return try await client.send(
            basePath + "/completions",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: LangChaingoCompletionResponse.self
        )
    }

    public func rag(
        _ payload: LangChaingoRAGRequest,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> LangChaingoRAGResponse {
        return try await client.send(
            basePath + "/rag",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: LangChaingoRAGResponse.self
        )
    }

    public func queryDocuments(
        _ payload: LangChaingoDocumentQueryRequest,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> LangChaingoDocumentQueryResponse {
        return try await client.send(
            basePath + "/documents/query",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: LangChaingoDocumentQueryResponse.self
        )
    }

    public func sql(
        _ payload: LangChaingoSQLRequest,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> LangChaingoSQLResponse {
        return try await client.send(
            basePath + "/sql",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: LangChaingoSQLResponse.self
        )
    }
}
