import Foundation

public final class LogService: BaseService {
    public func getList(
        page: Int = 1,
        perPage: Int = 30,
        filter: String? = nil,
        sort: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var params = query
        params["page"] = page
        params["perPage"] = perPage
        if let filter { params["filter"] = filter }
        if let sort { params["sort"] = sort }
        return try await client.send(
            "/api/logs",
            options: RequestOptions(headers: headers, query: params),
            decodeTo: JSONRecord.self
        )
    }

    public func getOne(
        _ logId: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        guard !logId.isEmpty else {
            throw ClientResponseError(url: client.buildURL("/api/logs"), status: 404, response: [
                "code": AnyCodable(404),
                "message": AnyCodable("Missing required log id."),
                "data": AnyCodable([:])
            ])
        }
        return try await client.send(
            "/api/logs/" + encodePathSegment(logId),
            options: RequestOptions(headers: headers, query: query),
            decodeTo: JSONRecord.self
        )
    }

    public func getStats(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [JSONRecord] {
        return try await client.send(
            "/api/logs/stats",
            options: RequestOptions(headers: headers, query: query),
            decodeTo: [JSONRecord].self
        )
    }
}
