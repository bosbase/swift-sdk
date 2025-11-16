import Foundation

/// Type-erased Codable wrapper used for BosBase payloads.
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = ()
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = boolValue
        } else if let intValue = try? container.decode(Int.self) {
            self.value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            self.value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            self.value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is Void:
            try container.encodeNil()
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let intValue as Int8:
            try container.encode(intValue)
        case let intValue as Int16:
            try container.encode(intValue)
        case let intValue as Int32:
            try container.encode(intValue)
        case let intValue as Int64:
            try container.encode(intValue)
        case let uintValue as UInt:
            try container.encode(uintValue)
        case let uintValue as UInt8:
            try container.encode(uintValue)
        case let uintValue as UInt16:
            try container.encode(uintValue)
        case let uintValue as UInt32:
            try container.encode(uintValue)
        case let uintValue as UInt64:
            try container.encode(uintValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let floatValue as Float:
            try container.encode(floatValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let dateValue as Date:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: dateValue))
        case let dataValue as Data:
            try container.encode(dataValue.base64EncodedString())
        case let arrayValue as [Any]:
            let anyCodableArray = arrayValue.map { AnyCodable($0) }
            try container.encode(anyCodableArray)
        case let dictValue as [String: Any]:
            let anyCodableDict = dictValue.mapValues { AnyCodable($0) }
            try container.encode(anyCodableDict)
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported value")
            throw EncodingError.invalidValue(value, context)
        }
    }
}

public extension AnyCodable {
    var isNil: Bool {
        return value is Void
    }

    func asDictionary() -> [String: Any]? {
        return value as? [String: Any]
    }
}

extension AnyCodable: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self.init(nil)
    }
}

extension AnyCodable: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension AnyCodable: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Any...) {
        self.init(elements)
    }
}

extension AnyCodable: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Any)...) {
        var dict: [String: Any] = [:]
        for (key, value) in elements {
            dict[key] = value
        }
        self.init(dict)
    }
}
