import Foundation

public final class CollectionService: BaseService {
    private let basePath = "/api/collections"

    public func getList<T: Decodable>(
        page: Int = 1,
        perPage: Int = 30,
        skipTotal: Bool = false,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> ListResult<T> {
        var params = query
        params["page"] = page
        params["perPage"] = perPage
        params["skipTotal"] = skipTotal
        let options = RequestOptions(headers: headers, query: params)
        return try await client.send(basePath, options: options, decodeTo: ListResult<T>.self)
    }

    public func getFullList<T: Decodable>(
        batchSize: Int = 200,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [T] {
        var result: [T] = []
        var page = 1
        while true {
            let list: ListResult<T> = try await getList(
                page: page,
                perPage: batchSize,
                skipTotal: true,
                query: query,
                headers: headers
            )
            result.append(contentsOf: list.items)
            if list.items.count < list.perPage {
                break
            }
            page += 1
        }
        return result
    }

    public func getOne<T: Decodable>(
        _ collectionIdOrName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> T {
        let path = basePath + "/" + encodePathSegment(collectionIdOrName)
        return try await client.send(path, options: RequestOptions(headers: headers, query: query), decodeTo: T.self)
    }

    @discardableResult
    public func delete(
        _ collectionIdOrName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let path = basePath + "/" + encodePathSegment(collectionIdOrName)
        let options = RequestOptions(method: .delete, headers: headers, query: query)
        _ = try await client.send(path, options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func deleteCollection(
        _ collectionIdOrName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        return try await delete(collectionIdOrName, query: query, headers: headers)
    }

    public func create<Response: Decodable>(
        body: RequestBody,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        let options = RequestOptions(method: .post, headers: headers, query: query, body: body)
        return try await client.send(basePath, options: options, decodeTo: Response.self)
    }

    public func create<Response: Decodable, Payload: Encodable>(
        body: Payload,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        return try await create(body: .encodable(body), query: query, headers: headers)
    }

    public func update<Response: Decodable>(
        _ collectionIdOrName: String,
        body: RequestBody,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        let path = basePath + "/" + encodePathSegment(collectionIdOrName)
        let options = RequestOptions(method: .patch, headers: headers, query: query, body: body)
        return try await client.send(path, options: options, decodeTo: Response.self)
    }

    public func update<Response: Decodable, Payload: Encodable>(
        _ collectionIdOrName: String,
        body: Payload,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Response {
        return try await update(
            collectionIdOrName,
            body: .encodable(body),
            query: query,
            headers: headers
        )
    }

    public func truncate(
        _ collectionIdOrName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let path = basePath + "/" + encodePathSegment(collectionIdOrName) + "/truncate"
        let options = RequestOptions(method: .delete, headers: headers, query: query)
        _ = try await client.send(path, options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func getScaffolds(headers: [String: String] = [:]) async throws -> [String: JSONRecord] {
        let options = RequestOptions(headers: headers)
        return try await client.send(basePath + "/meta/scaffolds", options: options, decodeTo: [String: JSONRecord].self)
    }

    public func createFromScaffold(
        type: String,
        name: String,
        overrides: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        let scaffolds = try await getScaffolds(headers: headers)
        guard var scaffold = scaffolds[type] else {
            let errorBody: JSONRecord = [
                "code": AnyCodable(400),
                "message": AnyCodable("Scaffold for type \(type) not found"),
                "data": AnyCodable([String: AnyCodable]())
            ]
            throw ClientResponseError(url: nil, status: 400, response: errorBody)
        }

        scaffold["name"] = AnyCodable(name)
        for (key, value) in overrides {
            scaffold[key] = value
        }

        return try await create(body: .encodable(scaffold), query: query, headers: headers)
    }

    public func createBase(
        name: String,
        overrides: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await createFromScaffold(type: "base", name: name, overrides: overrides, query: query, headers: headers)
    }

    public func createAuth(
        name: String,
        overrides: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await createFromScaffold(type: "auth", name: name, overrides: overrides, query: query, headers: headers)
    }

    public func createView(
        name: String,
        viewQuery: String? = nil,
        overrides: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        var finalOverrides = overrides
        if let viewQuery {
            finalOverrides["viewQuery"] = AnyCodable(viewQuery)
        }
        return try await createFromScaffold(type: "view", name: name, overrides: finalOverrides, query: query, headers: headers)
    }

    public func importCollections(
        _ collections: [JSONRecord],
        headers: [String: String] = [:]
    ) async throws -> Bool {
        let options = RequestOptions(method: .put, headers: headers, body: .encodable(["collections": AnyCodable(collections)]))
        _ = try await client.send(basePath + "/import", options: options, decodeTo: EmptyResponse.self)
        return true
    }

    public func exportCollections(
        include predicate: ((JSONRecord) -> Bool)? = nil,
        headers: [String: String] = [:]
    ) async throws -> [JSONRecord] {
        let collections: [JSONRecord] = try await getFullList(headers: headers)
        return collections.filter { predicate?($0) ?? true }.map { collection in
            var result = collection
            result.removeValue(forKey: "created")
            result.removeValue(forKey: "updated")
            return result
        }
    }

    public func getSchema(
        _ collectionIdOrName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        let path = basePath + "/" + encodePathSegment(collectionIdOrName) + "/schema"
        return try await client.send(path, options: RequestOptions(headers: headers, query: query), decodeTo: JSONRecord.self)
    }

    public func getAllSchemas(
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        return try await client.send(basePath + "/schemas", options: RequestOptions(headers: headers, query: query), decodeTo: JSONRecord.self)
    }
}
