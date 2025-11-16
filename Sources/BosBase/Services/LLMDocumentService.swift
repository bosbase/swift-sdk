import Foundation

public final class LLMDocumentService: BaseService {
    private let basePath = "/api/llm-documents"

    private func collectionPath(_ name: String) -> String {
        return basePath + "/" + encodePathSegment(name)
    }

    public func listCollections(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [JSONRecord] {
        return try await client.send(
            basePath + "/collections",
            options: RequestOptions(headers: headers, query: query),
            decodeTo: [JSONRecord].self
        )
    }

    public func createCollection(
        name: String,
        metadata: [String: String]? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let body: JSONRecord = ["metadata": AnyCodable(metadata ?? [:])]
        _ = try await client.send(
            basePath + "/collections/" + encodePathSegment(name),
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(body)),
            decodeTo: EmptyResponse.self
        )
    }

    public func deleteCollection(
        name: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            basePath + "/collections/" + encodePathSegment(name),
            options: RequestOptions(method: .delete, headers: headers, query: query),
            decodeTo: EmptyResponse.self
        )
    }

    @discardableResult
    public func insert(
        collection: String,
        document: LLMDocument,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            collectionPath(collection),
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(document)),
            decodeTo: JSONRecord.self
        )
    }

    public func get(
        collection: String,
        documentId: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> LLMDocument {
        return try await client.send(
            collectionPath(collection) + "/" + encodePathSegment(documentId),
            options: RequestOptions(headers: headers, query: query),
            decodeTo: LLMDocument.self
        )
    }

    @discardableResult
    public func update(
        collection: String,
        documentId: String,
        document: LLMDocumentUpdate,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            collectionPath(collection) + "/" + encodePathSegment(documentId),
            options: RequestOptions(method: .patch, headers: headers, query: query, body: .encodable(document)),
            decodeTo: JSONRecord.self
        )
    }

    public func delete(
        collection: String,
        documentId: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            collectionPath(collection) + "/" + encodePathSegment(documentId),
            options: RequestOptions(method: .delete, headers: headers, query: query),
            decodeTo: EmptyResponse.self
        )
    }

    public func list(
        collection: String,
        page: Int? = nil,
        perPage: Int? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var params = query
        if let page { params["page"] = page }
        if let perPage { params["perPage"] = perPage }
        return try await client.send(
            collectionPath(collection),
            options: RequestOptions(headers: headers, query: params),
            decodeTo: JSONRecord.self
        )
    }

    public func query(
        collection: String,
        options: LLMQueryOptions,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            collectionPath(collection) + "/documents/query",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(options)),
            decodeTo: JSONRecord.self
        )
    }
}
