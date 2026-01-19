import XCTest
@testable import SharedAlgorithm
@testable import SharedDomain

final class SharedAlgorithmTests: XCTestCase {

    // MARK: - Motion Feature Extraction Tests

    func testMotionFeatureExtraction() {
        let extractor = MotionFeatureExtractor(windowSeconds: 60.0, peakThreshold: 1.5)
        let baseTime = Date(timeIntervalSince1970: 1000)

        let samples = [
            MotionSample(timestamp: baseTime.addingTimeInterval(-50), magnitude: 0.5),
            MotionSample(timestamp: baseTime.addingTimeInterval(-40), magnitude: 1.8),
            MotionSample(timestamp: baseTime.addingTimeInterval(-30), magnitude: 2.0),
            MotionSample(timestamp: baseTime.addingTimeInterval(-20), magnitude: 0.3),
            MotionSample(timestamp: baseTime.addingTimeInterval(-10), magnitude: 1.6)
        ]

        let features = extractor.extract(from: samples, at: baseTime)

        XCTAssertGreaterThan(features.std, 0.0, "Standard deviation should be positive")
        XCTAssertEqual(features.peaks, 3, "3 samples exceed threshold 1.5")
        XCTAssertGreaterThan(features.energy, 0.0, "Energy should be positive")
    }

    // MARK: - HeartRate Feature Extraction Tests

    func testHeartRateFeatureExtraction() {
        let extractor = HeartRateFeatureExtractor(windowSeconds: 120.0, recentSeconds: 30.0)
        let baseTime = Date(timeIntervalSince1970: 2000)

        let samples = [
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-110), bpm: 60.0),
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-90), bpm: 62.0),
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-70), bpm: 61.0),
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-50), bpm: 63.0),
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-25), bpm: 70.0),
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-10), bpm: 72.0)
        ]

        let features = extractor.extract(from: samples, at: baseTime)

        XCTAssertGreaterThan(features.mean, 0.0, "Mean HR should be positive")
        XCTAssertGreaterThan(features.slope, 0.0, "Slope should be positive (recent HR increased)")
        XCTAssertGreaterThan(features.variance, 0.0, "Variance should be positive")
    }

    // MARK: - Score Calculator Tests

    func testWakeabilityScoreCalculation() {
        let calculator = WakeabilityScoreCalculator()
        let motion = MotionFeatures(std: 1.2, peaks: 5, energy: 20.0)
        let hr = HeartRateFeatures(mean: 70.0, slope: 5.0, variance: 10.0)

        let score = calculator.calculate(motion: motion, heartRate: hr)

        XCTAssertGreaterThanOrEqual(score.score, 0.0, "Score should be >= 0")
        XCTAssertLessThanOrEqual(score.score, 1.0, "Score should be <= 1")
        XCTAssertGreaterThan(score.components.motionScore, 0.0)
        XCTAssertGreaterThan(score.components.heartRateScore, 0.0)
    }

    // MARK: - Majority Rule Tests

    func testMajorityRule_TwoOutOfThreeTriggers() {
        let decider = TriggerDecider(
            threshold: 0.72,
            cooldownSeconds: 300.0,
            majorityCount: 2,
            majorityWindow: 3
        )

        let baseTime = Date(timeIntervalSince1970: 10000)
        let components = WakeabilityScore.Components(motionScore: 0.7, heartRateScore: 0.6)

        let recentScores = [
            ScoreUpdate(score: 0.75, components: components, timestamp: baseTime.addingTimeInterval(-60)),
            ScoreUpdate(score: 0.68, components: components, timestamp: baseTime.addingTimeInterval(-30)),
            ScoreUpdate(score: 0.78, components: components, timestamp: baseTime)
        ]

        let shouldTrigger = decider.shouldTriggerSmart(
            recentScores: recentScores,
            lastTriggerTime: nil,
            currentTime: baseTime
        )

        XCTAssertTrue(shouldTrigger, "Should trigger when 2 out of 3 scores exceed threshold")
    }

    func testMajorityRule_OneOutOfThreeDoesNotTrigger() {
        let decider = TriggerDecider(
            threshold: 0.72,
            cooldownSeconds: 300.0,
            majorityCount: 2,
            majorityWindow: 3
        )

        let baseTime = Date(timeIntervalSince1970: 10000)
        let components = WakeabilityScore.Components(motionScore: 0.5, heartRateScore: 0.4)

        let recentScores = [
            ScoreUpdate(score: 0.75, components: components, timestamp: baseTime.addingTimeInterval(-60)),
            ScoreUpdate(score: 0.65, components: components, timestamp: baseTime.addingTimeInterval(-30)),
            ScoreUpdate(score: 0.60, components: components, timestamp: baseTime)
        ]

        let shouldTrigger = decider.shouldTriggerSmart(
            recentScores: recentScores,
            lastTriggerTime: nil,
            currentTime: baseTime
        )

        XCTAssertFalse(shouldTrigger, "Should NOT trigger when only 1 out of 3 scores exceeds threshold")
    }

    // MARK: - Cooldown Tests

    func testCooldownPreventsRetrigger() {
        let decider = TriggerDecider(
            threshold: 0.72,
            cooldownSeconds: 300.0, // 5분
            majorityCount: 2,
            majorityWindow: 3
        )

        let baseTime = Date(timeIntervalSince1970: 20000)
        let lastTriggerTime = baseTime.addingTimeInterval(-240) // 4분 전
        let components = WakeabilityScore.Components(motionScore: 0.8, heartRateScore: 0.7)

        let recentScores = [
            ScoreUpdate(score: 0.80, components: components, timestamp: baseTime.addingTimeInterval(-60)),
            ScoreUpdate(score: 0.85, components: components, timestamp: baseTime.addingTimeInterval(-30)),
            ScoreUpdate(score: 0.90, components: components, timestamp: baseTime)
        ]

        let shouldTrigger = decider.shouldTriggerSmart(
            recentScores: recentScores,
            lastTriggerTime: lastTriggerTime,
            currentTime: baseTime
        )

        XCTAssertFalse(shouldTrigger, "Should NOT trigger within 5-minute cooldown period")
    }

    func testCooldownAllowsRetriggerAfterPeriod() {
        let decider = TriggerDecider(
            threshold: 0.72,
            cooldownSeconds: 300.0, // 5분
            majorityCount: 2,
            majorityWindow: 3
        )

        let baseTime = Date(timeIntervalSince1970: 20000)
        let lastTriggerTime = baseTime.addingTimeInterval(-310) // 5분 10초 전
        let components = WakeabilityScore.Components(motionScore: 0.8, heartRateScore: 0.7)

        let recentScores = [
            ScoreUpdate(score: 0.80, components: components, timestamp: baseTime.addingTimeInterval(-60)),
            ScoreUpdate(score: 0.85, components: components, timestamp: baseTime.addingTimeInterval(-30)),
            ScoreUpdate(score: 0.90, components: components, timestamp: baseTime)
        ]

        let shouldTrigger = decider.shouldTriggerSmart(
            recentScores: recentScores,
            lastTriggerTime: lastTriggerTime,
            currentTime: baseTime
        )

        XCTAssertTrue(shouldTrigger, "Should trigger after 5-minute cooldown period has passed")
    }

    // MARK: - Forced Trigger Tests

    func testForcedTriggerAtWakeTime() {
        let decider = TriggerDecider()

        let wakeTime = Date(timeIntervalSince1970: 30000)
        let currentTime = wakeTime.addingTimeInterval(10) // 10초 후

        let shouldForce = decider.shouldTriggerForced(currentTime: currentTime, wakeTime: wakeTime)

        XCTAssertTrue(shouldForce, "Should force trigger when current time >= wake time")
    }

    func testNoForcedTriggerBeforeWakeTime() {
        let decider = TriggerDecider()

        let wakeTime = Date(timeIntervalSince1970: 30000)
        let currentTime = wakeTime.addingTimeInterval(-60) // 1분 전

        let shouldForce = decider.shouldTriggerForced(currentTime: currentTime, wakeTime: wakeTime)

        XCTAssertFalse(shouldForce, "Should NOT force trigger before wake time")
    }

    // MARK: - Integration Tests

    func testWakeabilityAlgorithmIntegration() {
        let algorithm = WakeabilityAlgorithm()
        let baseTime = Date(timeIntervalSince1970: 40000)

        let motionSamples = [
            MotionSample(timestamp: baseTime.addingTimeInterval(-50), magnitude: 1.2),
            MotionSample(timestamp: baseTime.addingTimeInterval(-30), magnitude: 1.8),
            MotionSample(timestamp: baseTime.addingTimeInterval(-10), magnitude: 2.0)
        ]

        let hrSamples = [
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-100), bpm: 65.0),
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-60), bpm: 68.0),
            HeartRateSample(timestamp: baseTime.addingTimeInterval(-20), bpm: 72.0)
        ]

        let score = algorithm.computeScore(
            motionSamples: motionSamples,
            hrSamples: hrSamples,
            currentTime: baseTime
        )

        XCTAssertGreaterThanOrEqual(score.score, 0.0)
        XCTAssertLessThanOrEqual(score.score, 1.0)
    }

    func testEvaluateTriggerReturnsSmartTrigger() {
        let algorithm = WakeabilityAlgorithm()
        let baseTime = Date(timeIntervalSince1970: 50000)
        let wakeTime = baseTime.addingTimeInterval(600) // 10분 후
        let components = WakeabilityScore.Components(motionScore: 0.8, heartRateScore: 0.7)

        let recentScores = [
            ScoreUpdate(score: 0.76, components: components, timestamp: baseTime.addingTimeInterval(-60)),
            ScoreUpdate(score: 0.80, components: components, timestamp: baseTime.addingTimeInterval(-30)),
            ScoreUpdate(score: 0.85, components: components, timestamp: baseTime)
        ]

        let trigger = algorithm.evaluateTrigger(
            recentScores: recentScores,
            lastTriggerTime: nil,
            currentTime: baseTime,
            wakeTime: wakeTime
        )

        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.reason, .smart)
    }

    func testEvaluateTriggerReturnsForcedTrigger() {
        let algorithm = WakeabilityAlgorithm()
        let baseTime = Date(timeIntervalSince1970: 60000)
        let wakeTime = baseTime.addingTimeInterval(-10) // 이미 지남
        let components = WakeabilityScore.Components(motionScore: 0.3, heartRateScore: 0.2)

        let recentScores = [
            ScoreUpdate(score: 0.40, components: components, timestamp: baseTime.addingTimeInterval(-60)),
            ScoreUpdate(score: 0.35, components: components, timestamp: baseTime.addingTimeInterval(-30)),
            ScoreUpdate(score: 0.30, components: components, timestamp: baseTime)
        ]

        let trigger = algorithm.evaluateTrigger(
            recentScores: recentScores,
            lastTriggerTime: nil,
            currentTime: baseTime,
            wakeTime: wakeTime
        )

        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.reason, .forced, "Should force trigger even with low scores when wake time is reached")
    }
}
