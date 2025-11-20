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

    // MARK: - Index helpers

    @discardableResult
    public func addIndex(
        _ collectionIdOrName: String,
        columns: [String],
        unique: Bool = false,
        indexName: String? = nil,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        guard !columns.isEmpty else {
            throw validationError("At least one column must be specified")
        }

        var collection: JSONRecord = try await getOne(collectionIdOrName, query: query, headers: headers)
        let rawFields = collection["fields"]?.value as? [Any] ?? []
        let fieldNames = rawFields.compactMap { field -> String? in
            if let dict = field as? [String: Any] {
                return dict["name"] as? String
            }
            return nil
        }

        for column in columns {
            if column != "id" && !fieldNames.contains(column) {
                throw validationError("Field \"\(column)\" does not exist in the collection")
            }
        }

        let collectionName = (collection["name"]?.value as? String) ?? collectionIdOrName
        let idxName = indexName ?? "idx_\(collectionName)_\(columns.joined(separator: "_"))"
        let columnsStr = columns.map { "`\($0)`" }.joined(separator: ", ")
        let indexDefinition = unique
            ? "CREATE UNIQUE INDEX `\(idxName)` ON `\(collectionName)` (\(columnsStr))"
            : "CREATE INDEX `\(idxName)` ON `\(collectionName)` (\(columnsStr))"

        var indexes = extractStringArray(from: collection["indexes"])
        if indexes.contains(indexDefinition) {
            throw validationError("Index already exists")
        }
        indexes.append(indexDefinition)
        collection["indexes"] = AnyCodable(indexes)

        return try await update(
            collectionIdOrName,
            body: .encodable(collection),
            query: query,
            headers: headers
        )
    }

    @discardableResult
    public func removeIndex(
        _ collectionIdOrName: String,
        columns: [String],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> JSONRecord {
        guard !columns.isEmpty else {
            throw validationError("At least one column must be specified")
        }

        var collection: JSONRecord = try await getOne(collectionIdOrName, query: query, headers: headers)
        var indexes = extractStringArray(from: collection["indexes"])
        let initialCount = indexes.count

        indexes.removeAll { idx in
            columns.allSatisfy { column in
                let backticked = "`\(column)`"
                return idx.contains(backticked)
                    || idx.contains("(\(column))")
                    || idx.contains("(\(column),")
                    || idx.contains(", \(column))")
            }
        }

        if indexes.count == initialCount {
            throw validationError("Index not found")
        }

        collection["indexes"] = AnyCodable(indexes)
        return try await update(
            collectionIdOrName,
            body: .encodable(collection),
            query: query,
            headers: headers
        )
    }

    public func getIndexes(
        _ collectionIdOrName: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) async throws -> [String] {
        let collection: JSONRecord = try await getOne(collectionIdOrName, query: query, headers: headers)
        return extractStringArray(from: collection["indexes"])
    }

    private func validationError(_ message: String) -> ClientResponseError {
        return ClientResponseError(
            url: nil,
            status: 400,
            response: [
                "code": AnyCodable(400),
                "message": AnyCodable(message),
                "data": AnyCodable([String: AnyCodable]())
            ]
        )
    }

    private func extractStringArray(from value: AnyCodable?) -> [String] {
        guard let rawArray = value?.value as? [Any] else {
            return []
        }
        return rawArray.compactMap { element in
            if let string = element as? String {
                return string
            }
            return nil
        }
    }
}
