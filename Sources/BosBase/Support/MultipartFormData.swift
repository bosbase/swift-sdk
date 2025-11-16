import Foundation

public struct FilePart: Sendable {
    public let filename: String
    public let data: Data
    public let contentType: String

    public init(filename: String, data: Data, contentType: String = "application/octet-stream") {
        self.filename = filename
        self.data = data
        self.contentType = contentType
    }
}

public struct MultipartFormData: Sendable {
    public struct Part: Sendable {
        let headers: [String]
        let body: Data
    }

    private let boundary: String
    private var parts: [Part] = []

    public init(boundary: String = UUID().uuidString) {
        self.boundary = boundary
    }

    public mutating func addText(name: String, value: String) {
        var headers: [String] = []
        headers.append("Content-Disposition: form-data; name=\"\(name)\"")
        let body = Data(value.utf8)
        parts.append(Part(headers: headers, body: body))
    }

    public mutating func addFile(name: String, file: FilePart) {
        var headers: [String] = []
        headers.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(file.filename)\"")
        headers.append("Content-Type: \(file.contentType)")
        parts.append(Part(headers: headers, body: file.data))
    }

    public func build() -> (body: Data, contentType: String) {
        var body = Data()
        let lineBreak = "\r\n"

        for part in parts {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            for header in part.headers {
                body.append("\(header)\r\n".data(using: .utf8)!)
            }
            body.append(lineBreak.data(using: .utf8)!)
            body.append(part.body)
            body.append(lineBreak.data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        let contentType = "multipart/form-data; boundary=\(boundary)"
        return (body, contentType)
    }
}
