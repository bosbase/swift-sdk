import XCTest
@testable import BosBaseTests

fileprivate extension BosBaseClientTests {
    @available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
    static nonisolated(unsafe) let __allTests__BosBaseClientTests = [
        ("testAuthStoreUpdate", asyncTest(testAuthStoreUpdate)),
        ("testBuildURLAppendsQueryParameters", testBuildURLAppendsQueryParameters),
        ("testFilterEscapesStringsAndDates", testFilterEscapesStringsAndDates)
    ]
}
@available(*, deprecated, message: "Not actually deprecated. Marked as deprecated to allow inclusion of deprecated tests (which test deprecated functionality) without warnings")
func __BosBaseTests__allTests() -> [XCTestCaseEntry] {
    return [
        testCase(BosBaseClientTests.__allTests__BosBaseClientTests)
    ]
}