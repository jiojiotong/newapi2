import Foundation
import XCTest
@testable import NewAPIAdmin

final class NewAPIAdminCoreTests: XCTestCase {
    func testMakeURLPreservesQueryItems() throws {
        let client = NewAPIClient(baseURL: URL(string: "https://example.com/admin")!)
        let url = try client.makeURL("/api/channel/", queryItems: [URLQueryItem(name: "p", value: "1"), URLQueryItem(name: "page_size", value: "50")])
        XCTAssertEqual(url.absoluteString, "https://example.com/admin/api/channel/?p=1&page_size=50")
    }

    func testOptionParserBuildsDictionary() {
        let options = [OptionItem(key: "ModelPrice", value: "{}"), OptionItem(key: "GroupRatio", value: "{\"default\":1}")]
        XCTAssertEqual(OptionParser.dictionary(from: options)["ModelPrice"], "{}")
        XCTAssertEqual(OptionParser.dictionary(from: options)["GroupRatio"], "{\"default\":1}")
    }

    func testJSONValidationRejectsInvalidJSON() {
        XCTAssertThrowsError(try FormValidation.validateJSONString("{", field: "ModelPrice"))
    }

    func testNumericValidationRejectsInvalidValues() {
        XCTAssertThrowsError(try FormValidation.requirePositiveInt(0, field: "数量"))
        XCTAssertThrowsError(try FormValidation.requireNonNegative(-1, field: "额度"))
    }

    func testRedemptionValidationAcceptsValidValues() throws {
        XCTAssertNoThrow(try FormValidation.requirePositive(1, field: "额度"))
        XCTAssertNoThrow(try FormValidation.requirePositiveInt(10, field: "数量"))
        XCTAssertNoThrow(try FormValidation.requirePositiveInt(1_900_000_000, field: "过期时间"))
    }

    func testLoginResponseDetectsTwoFactor() throws {
        let data = Data("""
        {"require_2fa":true}
        """.utf8)
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)
        XCTAssertTrue(response.requiresTwoFactor)
        XCTAssertNil(response.adminUser)
    }

    func testAnyJSONValueRoundTrip() throws {
        let data = Data("{\"a\":1,\"b\":true,\"c\":[\"x\"]}".utf8)
        let value = try JSONDecoder().decode(AnyJSONValue.self, from: data)
        let encoded = try JSONEncoder().encode(value)
        XCTAssertFalse(encoded.isEmpty)
    }
}
