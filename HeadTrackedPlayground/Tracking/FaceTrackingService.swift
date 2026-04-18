import Combine
import CoreMedia
import Foundation
import QuartzCore
import Vision

final class FaceTrackingService: ObservableObject, @unchecked Sendable {
    @Published private(set) var trackedFaceState: TrackedFaceState = .empty
    @Published private(set) var averageLatencyMS: Double = 0

    var reacquireInterval: TimeInterval = 1.0

    private let processingQueue = DispatchQueue(label: "FaceTrackingService.processing", qos: .userInitiated)
    private let sequenceHandler = VNSequenceRequestHandler()
    private var trackRequest: VNTrackObjectRequest?
    private var isProcessingFrame = false
    private var lastDetectionTime: CFTimeInterval = 0
    private var lastObservationTime: CFTimeInterval?
    private var latencyAccumulatorMS: Double = 0
    private var latencySamples = 0

    func enqueue(_ frame: CameraFrame) {
        processingQueue.async { [weak self] in
            guard let self, !self.isProcessingFrame else { return }
            self.isProcessingFrame = true
            self.process(frame)
            self.isProcessingFrame = false
        }
    }

    private func process(_ frame: CameraFrame) {
        let wallClockStart = CACurrentMediaTime()
        let trackedObservation = resolvedTrackedObservation(for: frame, now: wallClockStart)
        let state = makeTrackedFaceState(from: trackedObservation, frameTimestamp: CMTimeGetSeconds(frame.timestamp), now: wallClockStart, pixelBuffer: frame.pixelBuffer)
        publish(state: state, latencyMS: (CACurrentMediaTime() - wallClockStart) * 1000)
    }

    private func resolvedTrackedObservation(for frame: CameraFrame, now: CFTimeInterval) -> VNDetectedObjectObservation? {
        if shouldRunFullDetection(now: now) {
            return detectPrimaryFace(on: frame.pixelBuffer, now: now)
        }

        guard let trackRequest else {
            return detectPrimaryFace(on: frame.pixelBuffer, now: now)
        }

        do {
            try sequenceHandler.perform([trackRequest], on: frame.pixelBuffer)

            guard
                let trackedObject = trackRequest.results?.first as? VNDetectedObjectObservation,
                trackedObject.confidence >= 0.35,
                trackedObject.boundingBox.width > 0,
                trackedObject.boundingBox.height > 0
            else {
                self.trackRequest = nil
                return detectPrimaryFace(on: frame.pixelBuffer, now: now)
            }

            self.trackRequest = VNTrackObjectRequest(detectedObjectObservation: trackedObject)
            self.trackRequest?.trackingLevel = .fast
            return trackedObject
        } catch {
            self.trackRequest = nil
            return detectPrimaryFace(on: frame.pixelBuffer, now: now)
        }
    }

    private func shouldRunFullDetection(now: CFTimeInterval) -> Bool {
        guard trackRequest != nil else {
            return true
        }

        return (now - lastDetectionTime) >= reacquireInterval
    }

    private func detectPrimaryFace(on pixelBuffer: CVPixelBuffer, now: CFTimeInterval) -> VNDetectedObjectObservation? {
        let request = VNDetectFaceRectanglesRequest()

        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
            guard
                let faces = request.results,
                let strongestFace = faces.max(by: { $0.boundingBox.area < $1.boundingBox.area })
            else {
                trackRequest = nil
                return nil
            }

            lastDetectionTime = now
            let observation = VNDetectedObjectObservation(boundingBox: strongestFace.boundingBox)
            let newTrackRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
            newTrackRequest.trackingLevel = .fast
            trackRequest = newTrackRequest
            return observation
        } catch {
            trackRequest = nil
            return nil
        }
    }

    private func makeTrackedFaceState(
        from trackedObservation: VNDetectedObjectObservation?,
        frameTimestamp: TimeInterval,
        now: CFTimeInterval,
        pixelBuffer: CVPixelBuffer
    ) -> TrackedFaceState {
        guard let trackedObservation else {
            let age = lastObservationTime.map { now - $0 } ?? 0
            let mode: TrackingMode = lastObservationTime == nil ? .searching : .lost
            return TrackedFaceState(
                observation: nil,
                status: TrackingStatus(mode: mode, confidence: 0, lastUpdateAge: age),
                isUsingCoarseFallback: false
            )
        }

        let boundingBox = NormalizedRect(rect: trackedObservation.boundingBox)
        let landmarkObservation = extractLandmarks(in: trackedObservation.boundingBox, pixelBuffer: pixelBuffer)

        let faceObservation = FaceObservation2D(
            boundingBox: boundingBox,
            leftEye: landmarkObservation.leftEye,
            rightEye: landmarkObservation.rightEye,
            nose: landmarkObservation.nose,
            detectionConfidence: Double(trackedObservation.confidence),
            landmarkConfidence: landmarkObservation.confidence,
            timestamp: frameTimestamp
        )

        let hasLandmarks = !landmarkObservation.leftEye.isEmpty && !landmarkObservation.rightEye.isEmpty
        let mode: TrackingMode = hasLandmarks ? .trackingFine : .trackingCoarse
        let confidence = hasLandmarks
            ? ((Double(trackedObservation.confidence) * 0.6) + (landmarkObservation.confidence * 0.4))
            : Double(trackedObservation.confidence) * 0.65

        lastObservationTime = now

        return TrackedFaceState(
            observation: faceObservation,
            status: TrackingStatus(mode: mode, confidence: confidence, lastUpdateAge: 0),
            isUsingCoarseFallback: !hasLandmarks
        )
    }

    private func extractLandmarks(in boundingBox: CGRect, pixelBuffer: CVPixelBuffer) -> (leftEye: [NormalizedPoint], rightEye: [NormalizedPoint], nose: [NormalizedPoint], confidence: Double) {
        let request = VNDetectFaceLandmarksRequest()
        request.regionOfInterest = boundingBox

        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
            guard
                let observation = request.results?.max(by: { $0.boundingBox.area < $1.boundingBox.area }),
                let landmarks = observation.landmarks
            else {
                return ([], [], [], 0)
            }

            let leftEye = convert(points: landmarks.leftEye?.normalizedPoints, boundingBox: observation.boundingBox)
            let rightEye = convert(points: landmarks.rightEye?.normalizedPoints, boundingBox: observation.boundingBox)
            let nose = convert(points: landmarks.nose?.normalizedPoints, boundingBox: observation.boundingBox)
            let confidence = ((!leftEye.isEmpty && !rightEye.isEmpty) ? 0.85 : 0.2)

            return (leftEye, rightEye, nose, confidence)
        } catch {
            return ([], [], [], 0)
        }
    }

    private func convert(points: [CGPoint]?, boundingBox: CGRect) -> [NormalizedPoint] {
        guard let points else { return [] }

        return points.map { point in
            NormalizedPoint(
                x: boundingBox.origin.x + (point.x * boundingBox.size.width),
                y: boundingBox.origin.y + (point.y * boundingBox.size.height)
            )
        }
    }

    private func publish(state: TrackedFaceState, latencyMS: Double) {
        latencyAccumulatorMS += latencyMS
        latencySamples += 1

        var emittedLatency = latencyMS
        if latencySamples >= 8 {
            emittedLatency = latencyAccumulatorMS / Double(latencySamples)
            latencyAccumulatorMS = 0
            latencySamples = 0
        }

        DispatchQueue.main.async {
            self.trackedFaceState = state
            self.averageLatencyMS = emittedLatency
        }
    }
}

private extension CGRect {
    var area: CGFloat {
        width * height
    }
}

private extension NormalizedRect {
    init(rect: CGRect) {
        self.init(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }
}
