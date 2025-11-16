import Foundation

private struct BatchQueueRequest {
    let method: HTTPMethod
    let url: String
    let headers: [String: String]?
    let body: [String: Any?]
}

public final class BatchService {
    private unowned let client: BosBaseClient
    private var requests: [BatchQueueRequest] = []

    init(client: BosBaseClient) {
        self.client = client
    }

    public func collection(_ idOrName: String) -> BatchCollectionBuilder {
        return BatchCollectionBuilder(parent: self, collectionIdOrName: idOrName)
    }

    public func send(headers: [String: String] = [:]) async throws -> [JSONRecord] {
        guard !requests.isEmpty else { return [] }

        var form = MultipartFormData()
        var jsonRequests: [[String: Any]] = []

        for (index, request) in requests.enumerated() {
            let payload = extractPayload(from: request.body)

            var json: [String: Any] = [
                "method": request.method.rawValue,
                "url": request.url,
                "body": payload.json
            ]
            if let headers = request.headers, !headers.isEmpty {
                json["headers"] = headers
            }
            jsonRequests.append(json)

            for (key, files) in payload.files {
                for file in files {
                    form.addFile(name: "requests.\(index).\(key)", file: file)
                }
            }
        }

        let payload: [String: Any] = ["requests": jsonRequests]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ClientResponseError(url: nil, status: 0, response: ["message": AnyCodable("Unable to encode batch payload")])
        }

        form.addText(name: "@jsonPayload", value: jsonString)

        let response: [JSONRecord] = try await client.send(
            "/api/batch",
            options: RequestOptions(method: .post, headers: headers, body: .multipartData(form)),
            decodeTo: [JSONRecord].self
        )

        requests.removeAll()
        return response
    }

    fileprivate func append(_ request: BatchQueueRequest) {
        requests.append(request)
    }

    private func extractPayload(from body: [String: Any?]) -> (json: [String: Any], files: [String: [FilePart]]) {
        var json: [String: Any] = [:]
        var files: [String: [FilePart]] = [:]

        for (key, value) in body {
            if let file = extractFile(value) {
                files[key, default: []].append(file)
                continue
            }

            if let array = extractArray(value) {
                var foundFiles: [FilePart] = []
                var regular: [Any] = []

                for element in array {
                    if let file = extractFile(element) {
                        foundFiles.append(file)
                    } else if let normalized = normalizeJSONValue(element) {
                        regular.append(normalized)
                    } else {
                        regular.append(NSNull())
                    }
                }

                if !foundFiles.isEmpty && foundFiles.count == array.count {
                    files[key, default: []].append(contentsOf: foundFiles)
                } else {
                    json[key] = regular
                    if !foundFiles.isEmpty {
                        var fileKey = key
                        if !key.hasPrefix("+") && !key.hasSuffix("+") {
                            fileKey += "+"
                        }
                        files[fileKey, default: []].append(contentsOf: foundFiles)
                    }
                }
                continue
            }

            if let normalized = normalizeJSONValue(value) {
                json[key] = normalized
            }
        }

        return (json, files)
    }

    private func extractFile(_ value: Any?) -> FilePart? {
        if let anyCodable = value as? AnyCodable {
            return extractFile(anyCodable.value)
        }
        return value as? FilePart
    }

    private func extractArray(_ value: Any?) -> [Any]? {
        if let array = value as? [Any] {
            return array
        }
        if let anyCodableArray = value as? [AnyCodable] {
            return anyCodableArray.map { $0.value }
        }
        return nil
    }

    private func normalizeJSONValue(_ value: Any?) -> Any? {
        if let anyCodable = value as? AnyCodable {
            return normalizeJSONValue(anyCodable.value)
        }
        switch value {
        case nil, is Void:
            return NSNull()
        case let number as NSNumber:
            return number
        case let string as String:
            return string
        case let bool as Bool:
            return bool
        case let date as Date:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: date)
        case let data as Data:
            return data.base64EncodedString()
        case let dictionary as [String: Any]:
            var mapped: [String: Any] = [:]
            for (key, value) in dictionary {
                if let normalized = normalizeJSONValue(value) {
                    mapped[key] = normalized
                }
            }
            return mapped
        case let dictionary as [String: Any?]:
            var mapped: [String: Any] = [:]
            for (key, value) in dictionary {
                if let normalized = normalizeJSONValue(value) {
                    mapped[key] = normalized
                }
            }
            return mapped
        case let array as [Any]:
            return array.compactMap { normalizeJSONValue($0) }
        default:
            if let convertible = value as? CustomStringConvertible {
                return convertible.description
            }
            return nil
        }
    }
}

public final class BatchCollectionBuilder {
    private unowned let parent: BatchService
    private let collectionIdOrName: String

    init(parent: BatchService, collectionIdOrName: String) {
        self.parent = parent
        self.collectionIdOrName = collectionIdOrName
    }

    public func create(
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) {
        appendRequest(method: .post, path: recordsPath(), body: body, query: query, headers: headers)
    }

    public func update(
        id: String,
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) {
        appendRequest(method: .patch, path: recordsPath() + "/" + encodePathSegment(id), body: body, query: query, headers: headers)
    }

    public func upsert(
        body: JSONRecord = [:],
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) {
        appendRequest(method: .put, path: recordsPath(), body: body, query: query, headers: headers)
    }

    public func delete(
        id: String,
        query: [String: Any?] = [:],
        headers: [String: String] = [:]
    ) {
        appendRequest(method: .delete, path: recordsPath() + "/" + encodePathSegment(id), body: [:], query: query, headers: headers)
    }

    private func appendRequest(
        method: HTTPMethod,
        path: String,
        body: JSONRecord?,
        query: [String: Any?],
        headers: [String: String]
    ) {
        var url = path
        let queryItems = QueryEncoder.encode(query)
        if !queryItems.isEmpty {
            let serialized = queryItems.compactMap { item -> String? in
                guard let value = item.value else { return nil }
                let name = item.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? item.name
                let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
                return "\(name)=\(escapedValue)"
            }.joined(separator: "&")
            if !serialized.isEmpty {
                url += (url.contains("?") ? "&" : "?") + serialized
            }
        }

        let request = BatchQueueRequest(
            method: method,
            url: url,
            headers: headers.isEmpty ? nil : headers,
            body: unwrapBody(body)
        )
        parent.append(request)
    }

    private func recordsPath() -> String {
        return "/api/collections/" + encodePathSegment(collectionIdOrName) + "/records"
    }

    private func unwrapBody(_ body: JSONRecord?) -> [String: Any?] {
        guard let body else { return [:] }
        var resolved: [String: Any?] = [:]
        for (key, value) in body {
            resolved[key] = value.value
        }
        return resolved
    }
}
