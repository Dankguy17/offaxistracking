import Combine
import Foundation
import Vision

final class PaperCalibrationService: ObservableObject, @unchecked Sendable {
    @Published private(set) var state: PaperCalibrationState = .idle

    var onCompleted: ((PaperCalibrationResult) -> Void)?

    private let estimator = PaperCalibrationEstimator()
    private let processingQueue = DispatchQueue(label: "PaperCalibrationService.processing", qos: .userInitiated)
    private let sequenceHandler = VNSequenceRequestHandler()
    private let requiredStableSamples = 8
    private let distanceToleranceMeters = 0.05
    private let centerTolerance = 0.05
    private var horizontalFieldOfViewDegrees: Double?
    private var preferredTarget: PaperCalibrationTarget = .auto
    private var isActive = false
    private var isProcessingFrame = false
    private var stableSampleCount = 0
    private var lastObservation: PaperCalibrationObservation?

    func updateHorizontalFieldOfViewDegrees(_ value: Double?) {
        processingQueue.async {
            self.horizontalFieldOfViewDegrees = value
        }
    }

    func start(preferredTarget: PaperCalibrationTarget) {
        processingQueue.async {
            self.preferredTarget = preferredTarget
            self.isActive = true
            self.stableSampleCount = 0
            self.lastObservation = nil
            self.publish(
                PaperCalibrationState(
                    phase: .searching,
                    instructionText: "\(preferredTarget.detectionPrompt) Keep it flat and fully visible to the webcam.",
                    preferredTarget: preferredTarget,
                    observation: nil
                )
            )
        }
    }

    func cancel() {
        processingQueue.async {
            self.isActive = false
            self.stableSampleCount = 0
            self.lastObservation = nil
            self.publish(
                PaperCalibrationState(
                    phase: .idle,
                    instructionText: self.preferredTarget.detectionPrompt,
                    preferredTarget: self.preferredTarget,
                    observation: nil
                )
            )
        }
    }

    func enqueue(_ frame: CameraFrame) {
        processingQueue.async {
            guard self.isActive, !self.isProcessingFrame else { return }
            self.isProcessingFrame = true
            self.process(frame)
            self.isProcessingFrame = false
        }
    }

    private func process(_ frame: CameraFrame) {
        guard let observation = detectPaper(in: frame) else {
            stableSampleCount = 0
            lastObservation = nil
            publish(
                PaperCalibrationState(
                    phase: .searching,
                    instructionText: "\(preferredTarget.detectionPrompt) No paper target detected yet.",
                    preferredTarget: preferredTarget,
                    observation: nil
                )
            )
            return
        }

        if let lastObservation, isStable(observation, comparedTo: lastObservation) {
            stableSampleCount += 1
        } else {
            stableSampleCount = 1
        }

        self.lastObservation = observation

        var trackedObservation = observation
        trackedObservation.stabilityProgress = min(Double(stableSampleCount) / Double(requiredStableSamples), 1)

        if stableSampleCount >= requiredStableSamples {
            isActive = false
            let result = PaperCalibrationResult(
                distanceMeters: trackedObservation.estimatedDistanceMeters,
                confidence: trackedObservation.confidence,
                sheet: trackedObservation.sheet
            )
            publish(
                PaperCalibrationState(
                    phase: .complete,
                    instructionText: "Locked \(trackedObservation.sheet.displayName) target at \(trackedObservation.estimatedDistanceMeters.formatted(.number.precision(.fractionLength(2)))) m.",
                    preferredTarget: preferredTarget,
                    observation: trackedObservation
                )
            )
            DispatchQueue.main.async {
                self.onCompleted?(result)
            }
            return
        }

        let samplesRemaining = requiredStableSamples - stableSampleCount
        publish(
            PaperCalibrationState(
                phase: .tracking,
                instructionText: "\(trackedObservation.sheet.displayName) detected at \(trackedObservation.estimatedDistanceMeters.formatted(.number.precision(.fractionLength(2)))) m. Hold still for \(samplesRemaining) more frames.",
                preferredTarget: preferredTarget,
                observation: trackedObservation
            )
        )
    }

    private func detectPaper(in frame: CameraFrame) -> PaperCalibrationObservation? {
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 6
        request.minimumConfidence = 0.65
        request.minimumAspectRatio = 0.68
        request.minimumSize = 0.12
        request.quadratureTolerance = 20

        do {
            try sequenceHandler.perform([request], on: frame.pixelBuffer)

            return request.results?
                .compactMap { observation in
                    estimator.estimateObservation(
                        corners: [
                            NormalizedPoint(x: Double(observation.topLeft.x), y: Double(observation.topLeft.y)),
                            NormalizedPoint(x: Double(observation.topRight.x), y: Double(observation.topRight.y)),
                            NormalizedPoint(x: Double(observation.bottomRight.x), y: Double(observation.bottomRight.y)),
                            NormalizedPoint(x: Double(observation.bottomLeft.x), y: Double(observation.bottomLeft.y))
                        ],
                        frameSize: frame.dimensions,
                        horizontalFieldOfViewDegrees: horizontalFieldOfViewDegrees,
                        preferredTarget: preferredTarget,
                        rectangleConfidence: Double(observation.confidence)
                    )
                }
                .max(by: { score(for: $0) < score(for: $1) })
        } catch {
            return nil
        }
    }

    private func score(for observation: PaperCalibrationObservation) -> Double {
        (observation.boundingBox.width * observation.boundingBox.height) * observation.confidence
    }

    private func isStable(_ current: PaperCalibrationObservation, comparedTo previous: PaperCalibrationObservation) -> Bool {
        guard current.sheet == previous.sheet else {
            return false
        }

        let currentCenter = (
            x: current.boundingBox.x + current.boundingBox.width * 0.5,
            y: current.boundingBox.y + current.boundingBox.height * 0.5
        )
        let previousCenter = (
            x: previous.boundingBox.x + previous.boundingBox.width * 0.5,
            y: previous.boundingBox.y + previous.boundingBox.height * 0.5
        )

        let centerDelta = hypot(currentCenter.x - previousCenter.x, currentCenter.y - previousCenter.y)
        let distanceDelta = abs(current.estimatedDistanceMeters - previous.estimatedDistanceMeters)
        return centerDelta <= centerTolerance && distanceDelta <= distanceToleranceMeters
    }

    private func publish(_ state: PaperCalibrationState) {
        DispatchQueue.main.async {
            self.state = state
        }
    }
}
