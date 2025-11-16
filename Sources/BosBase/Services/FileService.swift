import Foundation

public struct FileOptions {
    public var thumb: String?
    public var token: String?
    public var download: Bool?
    public var query: [String: Any?]

    public init(thumb: String? = nil, token: String? = nil, download: Bool? = nil, query: [String: Any?] = [:]) {
        self.thumb = thumb
        self.token = token
        self.download = download
        self.query = query
    }
}

public final class FileService: BaseService {
    public func getURL(
        record: JSONRecord,
        filename: String,
        options: FileOptions = FileOptions()
    ) -> URL? {
        guard !filename.isEmpty else { return nil }
        guard let recordId = record["id"]?.value as? String else { return nil }
        guard let collection = (record["collectionId"]?.value as? String) ?? (record["collectionName"]?.value as? String) else {
            return nil
        }

        var components: [String] = []
        components.append("api")
        components.append("files")
        components.append(encodePathSegment(collection))
        components.append(encodePathSegment(recordId))
        components.append(encodePathSegment(filename))

        var params = options.query
        if let thumb = options.thumb { params["thumb"] = thumb }
        if let token = options.token { params["token"] = token }
        if let download = options.download, download {
            params["download"] = true
        }

        return client.buildURL(components.joined(separator: "/"), query: params)
    }

    public func getToken(headers: [String: String] = [:]) async throws -> String {
        struct TokenResponse: Decodable { let token: String }
        let options = RequestOptions(method: .post, headers: headers)
        let response = try await client.send("/api/files/token", options: options, decodeTo: TokenResponse.self)
        return response.token
    }
}
