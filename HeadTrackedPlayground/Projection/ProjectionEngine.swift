import Foundation
import simd

struct ProjectionEngine {
    func projectionParameters(
        for pose: HeadPose,
        calibration: CalibrationProfile,
        drawableSize: CGSize
    ) -> ProjectionParameters {
        let viewerPosition = SIMD3<Float>(Float(pose.x), Float(pose.y), Float(max(pose.z, 0.05)))

        let left = Float((-calibration.displayWidthMeters * 0.5) - pose.x)
        let right = Float((calibration.displayWidthMeters * 0.5) - pose.x)
        let bottom = Float((-calibration.displayHeightMeters * 0.5) - pose.y)
        let top = Float((calibration.displayHeightMeters * 0.5) - pose.y)
        let near = Float(max(pose.z, 0.05))
        let far: Float = 10

        let projectionMatrix = makeOffAxisFrustum(left: left, right: right, bottom: bottom, top: top, near: near, far: far)
        let viewMatrix = makeTranslationMatrix(x: -viewerPosition.x, y: -viewerPosition.y, z: -viewerPosition.z)

        return ProjectionParameters(
            projectionMatrix: projectionMatrix,
            viewMatrix: viewMatrix,
            viewerPosition: viewerPosition
        )
    }

    private func makeOffAxisFrustum(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
        let x = (2 * near) / (right - left)
        let y = (2 * near) / (top - bottom)
        let a = (right + left) / (right - left)
        let b = (top + bottom) / (top - bottom)
        let c = -(far + near) / (far - near)
        let d = -(2 * far * near) / (far - near)

        return simd_float4x4(
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(a, b, c, -1),
            SIMD4<Float>(0, 0, d, 0)
        )
    }

    private func makeTranslationMatrix(x: Float, y: Float, z: Float) -> simd_float4x4 {
        simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(x, y, z, 1)
        )
    }
}
