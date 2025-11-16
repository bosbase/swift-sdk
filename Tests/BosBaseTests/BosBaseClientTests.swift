import XCTest
@testable import BosBase

final class BosBaseClientTests: XCTestCase {
    func testFilterEscapesStringsAndDates() throws {
        let client = BosBaseClient(baseURL: URL(string: "https://example.com")!)
        let date = Date(timeIntervalSince1970: 0)
        let filter = client.filter("title ~ {:title} && created >= {:created}", params: [
            "title": "te'st",
            "created": date
        ])
        XCTAssertTrue(filter.contains("te\\'st"))
        XCTAssertTrue(filter.contains("1970-01-01"))
    }

    func testBuildURLAppendsQueryParameters() throws {
        let client = BosBaseClient(baseURL: URL(string: "https://example.com/base")!)
        let url = client.buildURL("/api/collections", query: ["filter": "status = true", "page": 1])
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertTrue(url?.absoluteString.contains("filter=") ?? false)
        XCTAssertTrue(url?.absoluteString.contains("page=1") ?? false)
    }

    func testAuthStoreUpdate() async throws {
        let store = AuthStore(token: "abc", record: ["id": "123"])
        store.update(record: ["id": "456"])
        XCTAssertEqual(store.record?["id"]?.value as? String, "456")
        store.clear()
        XCTAssertNil(store.token)
    }
}
