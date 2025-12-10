import Foundation

public final class ScriptPermissionsService: BaseService {
    private let basePath = "/api/script-permissions"

    @discardableResult
    public func create(
        scriptName: String,
        content: String,
        scriptId: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptPermissionRecord {
        try requireSuperuser()

        let trimmedName = scriptName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("scriptName is required.") }

        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { throw validationError("content is required.") }

        var payload: JSONRecord = [
            "script_name": AnyCodable(trimmedName),
            "content": AnyCodable(trimmedContent)
        ]
        if let scriptId = scriptId?.trimmingCharacters(in: .whitespacesAndNewlines), !scriptId.isEmpty {
            payload["script_id"] = AnyCodable(scriptId)
        }

        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: query,
            body: .encodable(payload)
        )
        return try await client.send(basePath, options: options, decodeTo: ScriptPermissionRecord.self)
    }

    public func get(
        _ scriptName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptPermissionRecord {
        try requireSuperuser()

        let trimmedName = scriptName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("scriptName is required.") }

        let options = RequestOptions(headers: headers, query: query)
        return try await client.send(
            basePath + "/" + encodePathSegment(trimmedName),
            options: options,
            decodeTo: ScriptPermissionRecord.self
        )
    }

    @discardableResult
    public func update(
        _ scriptName: String,
        content: String? = nil,
        scriptId: String? = nil,
        newScriptName: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ScriptPermissionRecord {
        try requireSuperuser()

        let trimmedName = scriptName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("scriptName is required.") }

        var payload: JSONRecord = [:]
        if let content = content?.trimmingCharacters(in: .whitespacesAndNewlines) {
            payload["content"] = AnyCodable(content)
        }
        if let scriptId = scriptId?.trimmingCharacters(in: .whitespacesAndNewlines), !scriptId.isEmpty {
            payload["script_id"] = AnyCodable(scriptId)
        }
        if let newName = newScriptName?.trimmingCharacters(in: .whitespacesAndNewlines), !newName.isEmpty {
            payload["script_name"] = AnyCodable(newName)
        }

        guard !payload.isEmpty else {
            throw validationError("At least one of scriptId, scriptName, or content must be provided.")
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
            decodeTo: ScriptPermissionRecord.self
        )
    }

    @discardableResult
    public func delete(
        _ scriptName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        try requireSuperuser()

        let trimmedName = scriptName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw validationError("scriptName is required.") }

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
            throw ClientResponseError(url: nil, status: 403, response: ["message": AnyCodable("Superuser authentication is required to manage script permissions.")])
        }
    }

    private func validationError(_ message: String) -> ClientResponseError {
        return ClientResponseError(url: nil, status: 400, response: ["message": AnyCodable(message)])
    }
}
