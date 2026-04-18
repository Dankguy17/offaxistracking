import Foundation

enum TrackingMode: String, Codable, CaseIterable, Sendable {
    case searching
    case trackingFine
    case trackingCoarse
    case lost
}

struct TrackingStatus: Codable, Equatable, Sendable {
    var mode: TrackingMode
    var confidence: Double
    var lastUpdateAge: TimeInterval

    static let searching = TrackingStatus(mode: .searching, confidence: 0, lastUpdateAge: 0)
}
