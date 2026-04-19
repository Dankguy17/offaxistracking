import Foundation

struct EnvironmentArtwork: Equatable {
    let imageURL: URL

    var displayName: String {
        imageURL.deletingPathExtension().lastPathComponent
    }
}
