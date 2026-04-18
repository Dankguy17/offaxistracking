import Foundation

struct DebugMetrics: Codable, Equatable, Sendable {
    var cameraFPS: Double
    var visionLatencyMS: Double
    var renderFPS: Double
    var lastTrackingUpdateAge: Double

    static let zero = DebugMetrics(cameraFPS: 0, visionLatencyMS: 0, renderFPS: 0, lastTrackingUpdateAge: 0)
}
