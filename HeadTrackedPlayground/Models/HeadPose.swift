import Foundation

struct HeadPose: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var z: Double
    var confidence: Double
    var timestamp: TimeInterval

    static let neutral = HeadPose(x: 0, y: 0, z: 0.6, confidence: 0, timestamp: 0)
}
