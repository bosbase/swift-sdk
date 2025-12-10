import Foundation

public struct ScriptRecord: Decodable {
    public let id: String
    public let name: String
    public let content: String
    public let description: String?
    public let version: Int
    public let created: String?
    public let updated: String?
}

public struct ScriptExecutionResult: Decodable {
    public let output: String
}

public struct ScriptPermissionRecord: Decodable {
    public let id: String
    public let scriptId: String?
    public let scriptName: String
    public let content: String
    public let version: Int
    public let created: String?
    public let updated: String?
}
