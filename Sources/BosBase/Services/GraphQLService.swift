import Foundation

public struct GraphQLResponse: Codable {
    public let data: AnyCodable?
    public let errors: [JSONRecord]?
    public let extensions: [String: AnyCodable]?

    public init(
        data: AnyCodable? = nil,
        errors: [JSONRecord]? = nil,
        extensions: [String: AnyCodable]? = nil
    ) {
        self.data = data
        self.errors = errors
        self.extensions = extensions
    }
}

public final class GraphQLService: BaseService {
    public func query(
        _ document: String,
        variables: [String: AnyCodable]? = nil,
        operationName: String? = nil,
        queryParams: [String: Any?] = [:],
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> GraphQLResponse {
        var payload: JSONRecord = [
            "query": AnyCodable(document),
            "variables": AnyCodable(variables ?? [:]),
        ]
        if let operationName {
            payload["operationName"] = AnyCodable(operationName)
        }

        let options = RequestOptions(
            method: .post,
            headers: headers,
            query: queryParams,
            body: .encodable(payload),
            timeout: timeout
        )

        return try await client.send("/api/graphql", options: options, decodeTo: GraphQLResponse.self)
    }
}
