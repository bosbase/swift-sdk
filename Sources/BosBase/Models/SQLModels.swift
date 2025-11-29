import Foundation

public struct SQLExecuteResponse: Decodable {
    public let columns: [String]?
    public let rows: [[String]]?
    public let rowsAffected: Int64?

    public init(columns: [String]? = nil, rows: [[String]]? = nil, rowsAffected: Int64? = nil) {
        self.columns = columns
        self.rows = rows
        self.rowsAffected = rowsAffected
    }
}

public struct SQLTableDefinition: Encodable {
    public let name: String
    public let sql: String?

    public init(name: String, sql: String? = nil) {
        self.name = name
        self.sql = sql
    }
}

struct SQLTableNamesRequest: Encodable {
    let tables: [String]
}

struct SQLTableImportRequest: Encodable {
    let tables: [SQLTableDefinition]
}

public struct SQLTableImportResult: Decodable {
    public let created: [JSONRecord]
    public let skipped: [String]

    public init(created: [JSONRecord] = [], skipped: [String] = []) {
        self.created = created
        self.skipped = skipped
    }
}
