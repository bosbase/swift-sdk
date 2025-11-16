import Foundation

public final class CacheService: BaseService {
    private let basePath = "/api/cache"

    public func list(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [JSONRecord] {
        struct CacheResponse: Decodable {
            let items: [JSONRecord]?
        }
        let response: CacheResponse = try await client.send(
            basePath,
            options: RequestOptions(headers: headers, query: query),
            decodeTo: CacheResponse.self
        )
        return response.items ?? []
    }

    @discardableResult
    public func create(
        name: String,
        sizeBytes: Int? = nil,
        defaultTTLSeconds: Int? = nil,
        readTimeoutMs: Int? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var payload: JSONRecord = ["name": AnyCodable(name)]
        if let sizeBytes { payload["sizeBytes"] = AnyCodable(sizeBytes) }
        if let defaultTTLSeconds { payload["defaultTTLSeconds"] = AnyCodable(defaultTTLSeconds) }
        if let readTimeoutMs { payload["readTimeoutMs"] = AnyCodable(readTimeoutMs) }
        return try await client.send(
            basePath,
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: JSONRecord.self
        )
    }

    @discardableResult
    public func update(
        name: String,
        body: JSONRecord,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            basePath + "/" + encodePathSegment(name),
            options: RequestOptions(method: .patch, headers: headers, query: query, body: .encodable(body)),
            decodeTo: JSONRecord.self
        )
    }

    public func delete(
        name: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            basePath + "/" + encodePathSegment(name),
            options: RequestOptions(method: .delete, headers: headers, query: query),
            decodeTo: EmptyResponse.self
        )
    }

    @discardableResult
    public func setEntry(
        cache: String,
        key: String,
        value: AnyCodable,
        ttlSeconds: Int? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var payload: JSONRecord = ["value": value]
        if let ttlSeconds { payload["ttlSeconds"] = AnyCodable(ttlSeconds) }
        return try await client.send(
            entryPath(cache: cache, key: key),
            options: RequestOptions(method: .put, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: JSONRecord.self
        )
    }

    public func getEntry(
        cache: String,
        key: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            entryPath(cache: cache, key: key),
            options: RequestOptions(headers: headers, query: query),
            decodeTo: JSONRecord.self
        )
    }

    @discardableResult
    public func renewEntry(
        cache: String,
        key: String,
        ttlSeconds: Int? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var payload: JSONRecord = [:]
        if let ttlSeconds { payload["ttlSeconds"] = AnyCodable(ttlSeconds) }
        return try await client.send(
            entryPath(cache: cache, key: key),
            options: RequestOptions(method: .patch, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: JSONRecord.self
        )
    }

    public func deleteEntry(
        cache: String,
        key: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            entryPath(cache: cache, key: key),
            options: RequestOptions(method: .delete, headers: headers, query: query),
            decodeTo: EmptyResponse.self
        )
    }

    private func entryPath(cache: String, key: String) -> String {
        return basePath + "/" + encodePathSegment(cache) + "/entries/" + encodePathSegment(key)
    }
}
