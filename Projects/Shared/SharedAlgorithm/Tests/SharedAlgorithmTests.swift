import XCTest
@testable import SharedAlgorithm
@testable import SharedDomain

final class SharedAlgorithmTests: XCTestCase {
    func testFeatureExtractor() {
        let extractor = FeatureExtractor()
        let result = extractor.extractMotionFeature(accelerationData: [1.0, 2.0, 3.0])
        XCTAssertEqual(result, 2.0)
    }

    func testScoreCalculator() {
        let calculator = ScoreCalculator()
        let score = calculator.calculateWakeability(motionFeature: 5.0, heartRateFeature: 80.0)
        XCTAssertGreaterThan(score.score, 0.0)
        XCTAssertLessThanOrEqual(score.score, 1.0)
    }
}
