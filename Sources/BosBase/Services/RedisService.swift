import Foundation

public final class RedisService: BaseService {
    private let basePath = "/api/redis/keys"

    public func listKeys(
        cursor: String? = nil,
        pattern: String? = nil,
        count: Int? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RedisListPage {
        var params = query
        if let cursor { params["cursor"] = cursor }
        if let pattern { params["pattern"] = pattern }
        if let count { params["count"] = count }

        let options = RequestOptions(headers: headers, query: params)
        return try await client.send(basePath, options: options, decodeTo: RedisListPage.self)
    }

    @discardableResult
    public func createKey(
        _ key: String,
        value: Any,
        ttlSeconds: Int? = nil,
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RedisEntry {
        let payload = try buildPayload(key: key, value: value, ttlSeconds: ttlSeconds, body: body, requireValue: true)
        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        return try await client.send(basePath, options: options, decodeTo: RedisEntry.self)
    }

    public func getKey(
        _ key: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RedisEntry {
        let normalizedKey = try normalizeKey(key)
        let options = RequestOptions(headers: headers, query: query)
        return try await client.send(
            basePath + "/" + encodePathSegment(normalizedKey),
            options: options,
            decodeTo: RedisEntry.self
        )
    }

    @discardableResult
    public func updateKey(
        _ key: String,
        value: Any,
        ttlSeconds: Int? = nil,
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> RedisEntry {
        let normalizedKey = try normalizeKey(key)
        let payload = try buildPayload(key: normalizedKey, value: value, ttlSeconds: ttlSeconds, body: body, requireValue: true, includeKey: false)
        let options = RequestOptions(
            method: .put,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        return try await client.send(
            basePath + "/" + encodePathSegment(normalizedKey),
            options: options,
            decodeTo: RedisEntry.self
        )
    }

    @discardableResult
    public func deleteKey(
        _ key: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let normalizedKey = try normalizeKey(key)
        let options = RequestOptions(method: .delete, headers: headers, query: query)
        _ = try await client.send(
            basePath + "/" + encodePathSegment(normalizedKey),
            options: options,
            decodeTo: EmptyResponse.self
        )
        return true
    }

    private func buildPayload(
        key: String,
        value: Any?,
        ttlSeconds: Int?,
        body: JSONRecord,
        requireValue: Bool,
        includeKey: Bool = true
    ) throws -> JSONRecord {
        let normalizedKey = try normalizeKey(key)
        var payload = body
        if includeKey {
            payload["key"] = payload["key"] ?? AnyCodable(normalizedKey)
        }
        if let value {
            payload["value"] = payload["value"] ?? AnyCodable(value)
        } else if requireValue {
            throw validationError("value is required.")
        }
        if let ttlSeconds {
            payload["ttlSeconds"] = payload["ttlSeconds"] ?? AnyCodable(ttlSeconds)
        }
        return payload
    }

    private func normalizeKey(_ key: String) throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw validationError("Key must not be empty.") }
        return trimmed
    }

    private func validationError(_ message: String) -> ClientResponseError {
        return ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable(message)])
    }
}
