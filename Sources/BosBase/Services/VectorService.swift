import Foundation

public final class VectorService: BaseService {
    private let basePath = "/api/vectors"

    private func collectionPath(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return basePath }
        return basePath + "/" + encodePathSegment(name)
    }

    @discardableResult
    public func insert(
        _ document: VectorDocument,
        collection: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> VectorInsertResponse {
        return try await client.send(
            collectionPath(collection),
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(document)),
            decodeTo: VectorInsertResponse.self
        )
    }

    @discardableResult
    public func batchInsert(
        _ options: VectorBatchInsertOptions,
        collection: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> VectorBatchInsertResponse {
        return try await client.send(
            collectionPath(collection) + "/documents/batch",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(options)),
            decodeTo: VectorBatchInsertResponse.self
        )
    }

    @discardableResult
    public func update(
        documentId: String,
        document: VectorDocument,
        collection: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> VectorInsertResponse {
        return try await client.send(
            collectionPath(collection) + "/" + encodePathSegment(documentId),
            options: RequestOptions(method: .patch, headers: headers, query: query, body: .encodable(document)),
            decodeTo: VectorInsertResponse.self
        )
    }

    public func delete(
        documentId: String,
        collection: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            collectionPath(collection) + "/" + encodePathSegment(documentId),
            options: RequestOptions(method: .delete, headers: headers, query: query),
            decodeTo: EmptyResponse.self
        )
    }

    public func search(
        options: VectorSearchOptions,
        collection: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> VectorSearchResponse {
        return try await client.send(
            collectionPath(collection) + "/documents/search",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(options)),
            decodeTo: VectorSearchResponse.self
        )
    }

    public func get(
        documentId: String,
        collection: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> VectorDocument {
        return try await client.send(
            collectionPath(collection) + "/" + encodePathSegment(documentId),
            options: RequestOptions(headers: headers, query: query),
            decodeTo: VectorDocument.self
        )
    }

    public func list(
        collection: String? = nil,
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

    public func createCollection(
        name: String,
        config: VectorCollectionConfig,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            basePath + "/collections/" + encodePathSegment(name),
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(config)),
            decodeTo: EmptyResponse.self
        )
    }

    public func updateCollection(
        name: String,
        config: VectorCollectionConfig,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            basePath + "/collections/" + encodePathSegment(name),
            options: RequestOptions(method: .patch, headers: headers, query: query, body: .encodable(config)),
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

    public func listCollections(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [VectorCollectionInfo] {
        return try await client.send(
            basePath + "/collections",
            options: RequestOptions(headers: headers, query: query),
            decodeTo: [VectorCollectionInfo].self
        )
    }
}
