import Foundation

final class CalibrationManager {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadProfile() -> CalibrationProfile {
        let fileURL = calibrationFileURL()

        guard
            fileManager.fileExists(atPath: fileURL.path),
            let data = try? Data(contentsOf: fileURL),
            let profile = try? decoder.decode(CalibrationProfile.self, from: data)
        else {
            return .default
        }

        return profile
    }

    func saveProfile(_ profile: CalibrationProfile) throws {
        let directoryURL = calibrationDirectoryURL()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(profile)
        try data.write(to: calibrationFileURL(), options: [.atomic])
    }

    private func calibrationDirectoryURL() -> URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HeadTrackedPlayground", isDirectory: true)
    }

    private func calibrationFileURL() -> URL {
        calibrationDirectoryURL()
            .appendingPathComponent("calibration-profile.json")
    }
}
