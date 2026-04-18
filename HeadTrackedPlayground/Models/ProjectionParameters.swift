import Foundation
import simd

struct ProjectionParameters: Sendable {
    var projectionMatrix: simd_float4x4
    var viewMatrix: simd_float4x4
    var viewerPosition: SIMD3<Float>

    static let identity = ProjectionParameters(
        projectionMatrix: matrix_identity_float4x4,
        viewMatrix: matrix_identity_float4x4,
        viewerPosition: SIMD3<Float>(0, 0, 0.6)
    )
}
