import Foundation

public struct RecordAuthResponse<Record: Decodable>: Decodable {
    public let token: String
    public let record: Record
    public let meta: [String: AnyCodable]?
}

public struct OTPResponse: Decodable, Sendable {
    public let otpId: String
}
