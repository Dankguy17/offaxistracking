import XCTest
@testable import HeadTrackedPlayground

final class HeadTrackedPlaygroundTests: XCTestCase {
    func testScaffoldBuildsTestTarget() {
        XCTAssertTrue(true)
    }

    func testCalibrationProfileRoundTripPreservesValues() throws {
        let profile = CalibrationProfile.default
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CalibrationProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
    }
}
