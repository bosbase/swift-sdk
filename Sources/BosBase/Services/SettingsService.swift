import Foundation

public final class SettingsService: BaseService {
    public func getAll(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            "/api/settings",
            options: RequestOptions(headers: headers, query: query),
            decodeTo: JSONRecord.self
        )
    }

    @discardableResult
    public func update(
        body: JSONRecord,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            "/api/settings",
            options: RequestOptions(method: .patch, headers: headers, query: query, body: .encodable(body)),
            decodeTo: JSONRecord.self
        )
    }

    public func testS3(
        filesystem: String = "storage",
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        let payload: JSONRecord = ["filesystem": AnyCodable(filesystem)]
        _ = try await client.send(
            "/api/settings/test/s3",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: EmptyResponse.self
        )
    }

    public func testEmail(
        toEmail: String,
        template: String,
        collection: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        var payload: JSONRecord = [
            "email": AnyCodable(toEmail),
            "template": AnyCodable(template)
        ]
        if let collection { payload["collection"] = AnyCodable(collection) }
        _ = try await client.send(
            "/api/settings/test/email",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: EmptyResponse.self
        )
    }

    public func generateAppleClientSecret(
        clientId: String,
        teamId: String,
        keyId: String,
        privateKey: String,
        duration: Int,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        let payload: JSONRecord = [
            "clientId": AnyCodable(clientId),
            "teamId": AnyCodable(teamId),
            "keyId": AnyCodable(keyId),
            "privateKey": AnyCodable(privateKey),
            "duration": AnyCodable(duration)
        ]
        return try await client.send(
            "/api/settings/apple/generate-client-secret",
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(payload)),
            decodeTo: JSONRecord.self
        )
    }

    public func getCategory(
        _ category: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> AnyCodable? {
        let settings = try await getAll(query: query, headers: headers)
        return settings[category]
    }

    @discardableResult
    public func updateMeta(
        appName: String? = nil,
        appURL: String? = nil,
        senderName: String? = nil,
        senderAddress: String? = nil,
        hideControls: Bool? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var meta: JSONRecord = [:]
        if let appName { meta["appName"] = AnyCodable(appName) }
        if let appURL { meta["appURL"] = AnyCodable(appURL) }
        if let senderName { meta["senderName"] = AnyCodable(senderName) }
        if let senderAddress { meta["senderAddress"] = AnyCodable(senderAddress) }
        if let hideControls { meta["hideControls"] = AnyCodable(hideControls) }
        return try await update(body: ["meta": AnyCodable(meta)], query: query, headers: headers)
    }

    public func getApplicationSettings(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await getAll(query: query, headers: headers)
    }

    @discardableResult
    public func updateApplicationSettings(
        meta: JSONRecord? = nil,
        trustedProxy: JSONRecord? = nil,
        rateLimits: JSONRecord? = nil,
        batch: JSONRecord? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var payload: JSONRecord = [:]
        if let meta { payload["meta"] = AnyCodable(meta) }
        if let trustedProxy { payload["trustedProxy"] = AnyCodable(trustedProxy) }
        if let rateLimits { payload["rateLimits"] = AnyCodable(rateLimits) }
        if let batch { payload["batch"] = AnyCodable(batch) }
        return try await update(body: payload, query: query, headers: headers)
    }
}
