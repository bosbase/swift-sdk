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
}
