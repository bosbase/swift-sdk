import Foundation

func encodePathSegment(_ segment: String) -> String {
    var allowed = CharacterSet.urlPathAllowed
    allowed.remove(charactersIn: "/")
    return segment.addingPercentEncoding(withAllowedCharacters: allowed) ?? segment
}
