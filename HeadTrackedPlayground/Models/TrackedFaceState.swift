import Foundation

struct NormalizedPoint: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
}

struct NormalizedRect: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)
}

struct FaceObservation2D: Codable, Equatable, Sendable {
    var boundingBox: NormalizedRect
    var leftEye: [NormalizedPoint]
    var rightEye: [NormalizedPoint]
    var nose: [NormalizedPoint]
    var detectionConfidence: Double
    var landmarkConfidence: Double
    var timestamp: TimeInterval
}

struct TrackedFaceState: Codable, Equatable, Sendable {
    var observation: FaceObservation2D?
    var status: TrackingStatus
    var isUsingCoarseFallback: Bool

    static let empty = TrackedFaceState(observation: nil, status: .searching, isUsingCoarseFallback: false)
}
