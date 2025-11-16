import Foundation

public final class HealthService: BaseService {
    public func check(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(
            "/api/health",
            options: RequestOptions(headers: headers, query: query),
            decodeTo: JSONRecord.self
        )
    }
}
