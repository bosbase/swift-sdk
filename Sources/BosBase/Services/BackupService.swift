import Foundation

public final class BackupService: BaseService {
    public func getFullList(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [JSONRecord] {
        return try await client.send(
            "/api/backups",
            options: RequestOptions(headers: headers, query: query),
            decodeTo: [JSONRecord].self
        )
    }

    public func create(
        name: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let payload: JSONRecord = ["name": AnyCodable(name)]
        _ = try await client.send(
            "/api/backups",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: EmptyResponse.self
        )
    }

    public func upload(
        formData: MultipartFormData,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            "/api/backups/upload",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .multipartData(formData)),
            decodeTo: EmptyResponse.self
        )
    }

    public func delete(
        key: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            "/api/backups/" + encodePathSegment(key),
            options: RequestOptions(method: .delete, headers: headers, query: query),
            decodeTo: EmptyResponse.self
        )
    }

    public func restore(
        key: String,
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            "/api/backups/" + encodePathSegment(key) + "/restore",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(body)),
            decodeTo: EmptyResponse.self
        )
    }

    public func downloadURL(
        token: String,
        key: String,
        query: [String: Any?] = [:]
    ) -> URL? {
        var params = query
        params["token"] = token
        return client.buildURL("/api/backups/" + encodePathSegment(key), query: params)
    }
}
