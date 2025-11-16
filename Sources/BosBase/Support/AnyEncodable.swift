import Foundation

/// Type-erased box for arbitrary Encodable values.
public struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    public init<T: Encodable>(_ value: T) {
        self.encodeFunc = { encoder in
            try value.encode(to: encoder)
        }
    }

    public func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}
