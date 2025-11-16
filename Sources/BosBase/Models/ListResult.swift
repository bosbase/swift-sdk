import Foundation

public struct ListResult<Item: Decodable>: Decodable {
    public let page: Int
    public let perPage: Int
    public let totalItems: Int?
    public let totalPages: Int?
    public let items: [Item]

    enum CodingKeys: String, CodingKey {
        case page
        case perPage
        case totalItems
        case totalPages
        case items
    }
}
