import Foundation

enum QueryEncoder {
    static func encode(_ params: [String: Any?]) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        for (key, value) in params {
            guard let value else { continue }
            for string in strings(from: value) {
                items.append(URLQueryItem(name: key, value: string))
            }
        }
        return items
    }

    private static func strings(from value: Any) -> [String] {
        if let values = value as? [Any] {
            return values.compactMap { encodeSingle($0) }
        }
        if let set = value as? Set<AnyHashable> {
            return set.compactMap { encodeSingle($0) }
        }
        if let optional = value as? AnyOptional {
            if let unwrapped = optional.asAny() {
                return strings(from: unwrapped)
            }
            return []
        }
        if let dictionary = value as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
               let string = String(data: data, encoding: .utf8) {
                return [string]
            }
            return []
        }
        return encodeSingle(value).map { [$0] } ?? []
    }

    private static func encodeSingle(_ value: Any) -> String? {
        switch value {
        case is Void:
            return nil
        case let boolValue as Bool:
            return boolValue ? "true" : "false"
        case let stringValue as String:
            return stringValue
        case let dateValue as Date:
            return queryDateFormatter.string(from: dateValue)
        case let number as NSNumber:
            return number.stringValue
        case let dataValue as Data:
            return dataValue.base64EncodedString()
        default:
            if let customString = value as? CustomStringConvertible {
                return customString.description
            }
            return String(describing: value)
        }
    }

    private static var queryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private protocol AnyOptional {
    func asAny() -> Any?
}

extension Optional: AnyOptional {
    func asAny() -> Any? {
        switch self {
        case .some(let wrapped):
            return wrapped
        case .none:
            return nil
        }
    }
}
