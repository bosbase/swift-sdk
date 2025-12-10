import Foundation

public struct AuthState {
    public let token: String?
    public let record: JSONRecord?

    public init(token: String?, record: JSONRecord?) {
        self.token = token
        self.record = record
    }
}

public typealias JSONRecord = [String: AnyCodable]

public final class AuthStore: @unchecked Sendable {
    private let lock = NSLock()
    private var state: AuthState
    public var onChange: ((AuthState) -> Void)?

    public init(token: String? = nil, record: JSONRecord? = nil) {
        self.state = AuthState(token: token, record: record)
    }

    public var token: String? {
        lock.lock()
        defer { lock.unlock() }
        return state.token
    }

    public var record: JSONRecord? {
        lock.lock()
        defer { lock.unlock() }
        return state.record
    }

    public var isSuperuser: Bool {
        lock.lock()
        let currentToken = state.token
        let currentRecord = state.record
        lock.unlock()

        if let collection = currentRecord?["collectionName"]?.value as? String, collection == "_superusers" {
            return true
        }

        guard let token = currentToken, !token.isEmpty else { return false }
        guard let claims = decodeTokenPayload(token), (claims["type"] as? String) == "auth" else { return false }

        if let collectionId = currentRecord?["collectionId"]?.value as? String, collectionId == "pbc_3142635823" {
            return true
        }

        if let collectionId = claims["collectionId"] as? String, collectionId == "pbc_3142635823" {
            return true
        }

        return (claims["collectionName"] as? String) == "_superusers"
    }

    public func isValid() -> Bool {
        return !(token ?? "").isEmpty
    }

    public func save(token: String, record: JSONRecord?) {
        lock.lock()
        state = AuthState(token: token, record: record)
        let current = state
        lock.unlock()
        onChange?(current)
    }

    public func update(record: JSONRecord?) {
        lock.lock()
        state = AuthState(token: state.token, record: record)
        let current = state
        lock.unlock()
        onChange?(current)
    }

    public func clear() {
        lock.lock()
        state = AuthState(token: nil, record: nil)
        let current = state
        lock.unlock()
        onChange?(current)
    }

    private func decodeTokenPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
        let remainder = payload.count % 4
        if remainder > 0 {
            payload.append(String(repeating: "=", count: 4 - remainder))
        }
        payload = payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
