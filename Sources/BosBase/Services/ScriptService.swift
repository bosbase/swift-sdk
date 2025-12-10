import Foundation

public final class ScriptService: BaseService {
    private let basePath = "/api/scripts"

    @discardableResult
    public func create(
        name: String,
        content: String,
        description: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptRecord {
        try requireSuperuser()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("Script name is required.") }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { throw validationError("Script content is required.") }

        var payload: JSONRecord = [
            "name": AnyCodable(trimmedName),
            "content": AnyCodable(trimmedContent)
        ]
        if let description = description?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            payload["description"] = AnyCodable(description)
        }

        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        return try await client.send(basePath, options: options, decodeTo: ScriptRecord.self)
    }

    public func command(
        _ command: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptExecutionResult {
        try requireSuperuser()

        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw validationError("Command is required.") }

        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(["command": AnyCodable(trimmed)])
        )
        return try await client.send(basePath + "/command", options: options, decodeTo: ScriptExecutionResult.self)
    }

    public func get(
        _ name: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptRecord {
        try requireSuperuser()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("Script name is required.") }

        let options = RequestOptions(headers: headers, query: query)
        return try await client.send(
            basePath + "/" + encodePathSegment(trimmedName),
            options: options,
            decodeTo: ScriptRecord.self
        )
    }

    public func list(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [ScriptRecord] {
        try requireSuperuser()

        let options = RequestOptions(headers: headers, query: query)
        struct Response: Decodable { let items: [ScriptRecord]? }
        let response: Response = try await client.send(basePath, options: options, decodeTo: Response.self)
        return response.items ?? []
    }

    @discardableResult
    public func update(
        _ name: String,
        content: String? = nil,
        description: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptRecord {
        try requireSuperuser()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("Script name is required.") }

        var payload: JSONRecord = [:]
        if let content = content?.trimmingCharacters(in: .whitespacesAndNewlines) {
            payload["content"] = AnyCodable(content)
        }
        if let description = description?.trimmingCharacters(in: .whitespacesAndNewlines) {
            payload["description"] = AnyCodable(description)
        }

        guard !payload.isEmpty else {
            throw validationError("At least one of content or description must be provided.")
        }

        let options = RequestOptions(
            method: .patch,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        return try await client.send(
            basePath + "/" + encodePathSegment(trimmedName),
            options: options,
            decodeTo: ScriptRecord.self
        )
    }

    public func execute(
        _ name: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptExecutionResult {
        try requireSuperuser()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("Script name is required.") }

        let options = RequestOptions(method: .post, headers: headers, query: query)
        return try await client.send(
            basePath + "/" + encodePathSegment(trimmedName) + "/execute",
            options: options,
            decodeTo: ScriptExecutionResult.self
        )
    }

    @discardableResult
    public func delete(
        _ name: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        try requireSuperuser()

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("Script name is required.") }

        let options = RequestOptions(method: .delete, headers: headers, query: query)
        _ = try await client.send(
            basePath + "/" + encodePathSegment(trimmedName),
            options: options,
            decodeTo: EmptyResponse.self
        )
        return true
    }

    private func requireSuperuser() throws {
        guard client.authStore.isSuperuser else {
            throw ClientResponseError(url: nil, status: 403, response: ["message": AnyCodable("Superuser authentication is required to manage scripts.")])
        }
    }

    private func validationError(_ message: String) -> ClientResponseError {
        return ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable(message)])
    }
}
