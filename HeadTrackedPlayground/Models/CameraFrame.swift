import AVFoundation
import CoreVideo
import Foundation

final class CameraFrame: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let timestamp: CMTime
    let dimensions: CGSize

    init(pixelBuffer: CVPixelBuffer, timestamp: CMTime, dimensions: CGSize) {
        self.pixelBuffer = pixelBuffer
        self.timestamp = timestamp
        self.dimensions = dimensions
    }
}
