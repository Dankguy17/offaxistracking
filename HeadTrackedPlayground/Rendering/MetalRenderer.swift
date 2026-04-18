import Metal
import MetalKit
import QuartzCore
import simd

@MainActor
final class MetalRenderer: NSObject {
    let device = MTLCreateSystemDefaultDevice()

    var onRenderFPSUpdate: ((Double) -> Void)?

    private let projectionEngine = ProjectionEngine()
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var depthState: MTLDepthStencilState?
    private var lineVertexBuffer: MTLBuffer?
    private var triangleVertexBuffer: MTLBuffer?
    private var lineVertexCount = 0
    private var triangleVertexCount = 0

    private var currentPose = HeadPose.neutral
    private var currentCalibration = CalibrationProfile.default
    private var isProjectionFrozen = false
    private var frozenProjectionParameters: ProjectionParameters?
    private var fpsFrameCount = 0
    private var fpsWindowStart = CACurrentMediaTime()

    func configure(view: MTKView) {
        guard let device else { return }

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.delegate = self

        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
            buildPipeline(device: device, view: view)
            buildScene(device: device)
        }
    }

    func update(pose: HeadPose, calibration: CalibrationProfile, isFrozen: Bool) {
        currentPose = pose
        currentCalibration = calibration

        if self.isProjectionFrozen != isFrozen {
            if !isFrozen {
                frozenProjectionParameters = nil
            }
            self.isProjectionFrozen = isFrozen
        }
    }

    private func buildPipeline(device: MTLDevice, view: MTKView) {
        guard let library = try? device.makeLibrary(source: Self.shaderSource, options: nil) else { return }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<RenderVertex>.stride

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "sceneVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "sceneFragment")
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

        pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDescriptor)
    }

    private func buildScene(device: MTLDevice) {
        let lineVertices = buildLineVertices()
        let triangleVertices = buildTriangleVertices()

        lineVertexCount = lineVertices.count
        triangleVertexCount = triangleVertices.count

        lineVertexBuffer = device.makeBuffer(bytes: lineVertices, length: MemoryLayout<RenderVertex>.stride * lineVertices.count)
        triangleVertexBuffer = device.makeBuffer(bytes: triangleVertices, length: MemoryLayout<RenderVertex>.stride * triangleVertices.count)
    }

    private func buildLineVertices() -> [RenderVertex] {
        var vertices: [RenderVertex] = []
        let wallColor = SIMD4<Float>(0.72, 0.73, 0.78, 1)
        let gridColor = SIMD4<Float>(0.23, 0.56, 0.68, 1)

        let roomCorners: [SIMD3<Float>] = [
            SIMD3<Float>(-1.0, -0.7, -0.3),
            SIMD3<Float>(1.0, -0.7, -0.3),
            SIMD3<Float>(1.0, 0.7, -0.3),
            SIMD3<Float>(-1.0, 0.7, -0.3),
            SIMD3<Float>(-1.3, -0.9, -2.6),
            SIMD3<Float>(1.3, -0.9, -2.6),
            SIMD3<Float>(1.3, 0.9, -2.6),
            SIMD3<Float>(-1.3, 0.9, -2.6),
        ]

        let roomEdges = [
            (0, 1), (1, 2), (2, 3), (3, 0),
            (4, 5), (5, 6), (6, 7), (7, 4),
            (0, 4), (1, 5), (2, 6), (3, 7)
        ]

        for edge in roomEdges {
            vertices.append(RenderVertex(position: roomCorners[edge.0], color: wallColor))
            vertices.append(RenderVertex(position: roomCorners[edge.1], color: wallColor))
        }

        for x in stride(from: -1.2 as Float, through: 1.2 as Float, by: 0.2) {
            vertices.append(RenderVertex(position: SIMD3<Float>(x, -0.8, -2.5), color: gridColor))
            vertices.append(RenderVertex(position: SIMD3<Float>(x, 0.8, -2.5), color: gridColor))
        }

        for y in stride(from: -0.8 as Float, through: 0.8 as Float, by: 0.2) {
            vertices.append(RenderVertex(position: SIMD3<Float>(-1.2, y, -2.5), color: gridColor))
            vertices.append(RenderVertex(position: SIMD3<Float>(1.2, y, -2.5), color: gridColor))
        }

        return vertices
    }

    private func buildTriangleVertices() -> [RenderVertex] {
        let cubeColor = SIMD4<Float>(0.86, 0.56, 0.29, 1)
        let pillarColor = SIMD4<Float>(0.37, 0.73, 0.78, 1)

        return makeCube(center: SIMD3<Float>(-0.18, -0.02, -1.1), size: SIMD3<Float>(0.32, 0.32, 0.32), color: cubeColor)
            + makeCube(center: SIMD3<Float>(0.32, 0.18, -1.75), size: SIMD3<Float>(0.18, 0.48, 0.18), color: pillarColor)
    }

    private func makeCube(center: SIMD3<Float>, size: SIMD3<Float>, color: SIMD4<Float>) -> [RenderVertex] {
        let hx = size.x * 0.5
        let hy = size.y * 0.5
        let hz = size.z * 0.5

        let corners: [SIMD3<Float>] = [
            center + SIMD3<Float>(-hx, -hy, hz),
            center + SIMD3<Float>(hx, -hy, hz),
            center + SIMD3<Float>(hx, hy, hz),
            center + SIMD3<Float>(-hx, hy, hz),
            center + SIMD3<Float>(-hx, -hy, -hz),
            center + SIMD3<Float>(hx, -hy, -hz),
            center + SIMD3<Float>(hx, hy, -hz),
            center + SIMD3<Float>(-hx, hy, -hz),
        ]

        let triangles = [
            (0, 1, 2), (0, 2, 3),
            (1, 5, 6), (1, 6, 2),
            (5, 4, 7), (5, 7, 6),
            (4, 0, 3), (4, 3, 7),
            (3, 2, 6), (3, 6, 7),
            (4, 5, 1), (4, 1, 0),
        ]

        return triangles.flatMap { triangle in
            [
                RenderVertex(position: corners[triangle.0], color: color),
                RenderVertex(position: corners[triangle.1], color: color),
                RenderVertex(position: corners[triangle.2], color: color)
            ]
        }
    }

    private func updateFPS() {
        fpsFrameCount += 1
        let now = CACurrentMediaTime()
        let elapsed = now - fpsWindowStart
        guard elapsed >= 0.5 else { return }

        onRenderFPSUpdate?(Double(fpsFrameCount) / elapsed)
        fpsFrameCount = 0
        fpsWindowStart = now
    }
}

extension MetalRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        if isProjectionFrozen {
            frozenProjectionParameters = nil
        }
    }

    func draw(in view: MTKView) {
        guard
            let commandQueue,
            let pipelineState,
            let depthState,
            let lineVertexBuffer,
            let triangleVertexBuffer,
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable
        else {
            return
        }

        let projectionParameters: ProjectionParameters
        if isProjectionFrozen {
            if let frozenProjectionParameters {
                projectionParameters = frozenProjectionParameters
            } else {
                let computed = projectionEngine.projectionParameters(
                    for: currentPose,
                    calibration: currentCalibration,
                    drawableSize: view.drawableSize
                )
                frozenProjectionParameters = computed
                projectionParameters = computed
            }
        } else {
            projectionParameters = projectionEngine.projectionParameters(
                for: currentPose,
                calibration: currentCalibration,
                drawableSize: view.drawableSize
            )
            frozenProjectionParameters = nil
        }

        var uniforms = RenderUniforms(mvpMatrix: projectionParameters.projectionMatrix * projectionParameters.viewMatrix)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<RenderUniforms>.stride, index: 1)

        encoder.setVertexBuffer(lineVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: lineVertexCount)

        encoder.setVertexBuffer(triangleVertexBuffer, offset: 0, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: triangleVertexCount)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()

        updateFPS()
    }
}

private struct RenderVertex {
    var position: SIMD3<Float>
    var color: SIMD4<Float>
}

private struct RenderUniforms {
    var mvpMatrix: simd_float4x4
}

private extension MetalRenderer {
    static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexIn {
        float3 position [[attribute(0)]];
        float4 color [[attribute(1)]];
    };

    struct RenderUniforms {
        float4x4 mvpMatrix;
    };

    struct VertexOut {
        float4 position [[position]];
        float4 color;
    };

    vertex VertexOut sceneVertex(VertexIn in [[stage_in]], constant RenderUniforms& uniforms [[buffer(1)]]) {
        VertexOut out;
        out.position = uniforms.mvpMatrix * float4(in.position, 1.0);
        out.color = in.color;
        return out;
    }

    fragment float4 sceneFragment(VertexOut in [[stage_in]]) {
        return in.color;
    }
    """
}
