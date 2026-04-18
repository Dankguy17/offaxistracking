import Foundation

enum PaperCalibrationTarget: String, CaseIterable, Identifiable, Codable, Sendable {
    case auto
    case a4
    case usLetter

    var id: Self { self }

    var displayName: String {
        switch self {
        case .auto:
            "Auto Detect"
        case .a4:
            "A4"
        case .usLetter:
            "8.5 x 11 in"
        }
    }

    var detectionPrompt: String {
        switch self {
        case .auto:
            "Hold an A4 or 8.5 x 11 inch sheet near your face."
        case .a4:
            "Hold an A4 sheet near your face."
        case .usLetter:
            "Hold an 8.5 x 11 inch sheet near your face."
        }
    }

    var candidateSheets: [PaperSheetKind] {
        switch self {
        case .auto:
            PaperSheetKind.allCases
        case .a4:
            [.a4]
        case .usLetter:
            [.usLetter]
        }
    }
}

enum PaperSheetKind: String, CaseIterable, Codable, Sendable {
    case a4
    case usLetter

    var displayName: String {
        switch self {
        case .a4:
            "A4"
        case .usLetter:
            "8.5 x 11 in"
        }
    }

    var shortLabel: String {
        switch self {
        case .a4:
            "A4"
        case .usLetter:
            "Letter"
        }
    }

    var shortSideMeters: Double {
        switch self {
        case .a4:
            0.210
        case .usLetter:
            0.2159
        }
    }

    var longSideMeters: Double {
        switch self {
        case .a4:
            0.297
        case .usLetter:
            0.2794
        }
    }

    var aspectRatio: Double {
        longSideMeters / shortSideMeters
    }
}

enum PaperCalibrationPhase: String, Equatable, Sendable {
    case idle
    case searching
    case tracking
    case complete
}

struct PaperCalibrationObservation: Equatable, Sendable {
    var corners: [NormalizedPoint]
    var boundingBox: NormalizedRect
    var estimatedDistanceMeters: Double
    var confidence: Double
    var sheet: PaperSheetKind
    var stabilityProgress: Double
}

struct PaperCalibrationResult: Equatable, Sendable {
    var distanceMeters: Double
    var confidence: Double
    var sheet: PaperSheetKind
}

struct PaperCalibrationState: Equatable, Sendable {
    var phase: PaperCalibrationPhase
    var instructionText: String
    var preferredTarget: PaperCalibrationTarget
    var observation: PaperCalibrationObservation?

    var isRunning: Bool {
        phase == .searching || phase == .tracking
    }

    static let idle = PaperCalibrationState(
        phase: .idle,
        instructionText: PaperCalibrationTarget.auto.detectionPrompt,
        preferredTarget: .auto,
        observation: nil
    )
}
