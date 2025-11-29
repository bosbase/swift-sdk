import Foundation

public final class SQLService: BaseService {
    private let basePath = "/api/sql"

    public func execute(
        _ query: String,
        headers: [String: String] = [:]
    ) async throws -> SQLExecuteResponse {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ClientResponseError(
                url: nil,
                status: 400,
                response: [
                    "code": AnyCodable(400),
                    "message": AnyCodable("SQL query is required"),
                    "data": AnyCodable([String: AnyCodable]())
                ]
            )
        }

        let body = SQLExecuteRequest(query: trimmed)
        let options = RequestOptions(method: .post, headers: headers, body: .encodable(body))
        return try await client.send(
            basePath + "/execute",
            options: options,
            decodeTo: SQLExecuteResponse.self
        )
    }
}

private struct SQLExecuteRequest: Encodable {
    let query: String
}
