import Foundation

public final class CronService: BaseService {
    public func getFullList(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [JSONRecord] {
        return try await client.send(
            "/api/crons",
            options: RequestOptions(headers: headers, query: query),
            decodeTo: [JSONRecord].self
        )
    }

    public func run(
        jobId: String,
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws {
        _ = try await client.send(
            "/api/crons/" + encodePathSegment(jobId),
            options: RequestOptions(method: .post, headers: headers, query: query, body: .encodable(body)),
            decodeTo: EmptyResponse.self
        )
    }
}
