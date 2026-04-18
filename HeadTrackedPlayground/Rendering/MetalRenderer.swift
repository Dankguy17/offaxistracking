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
    private var currentEnvironment = RenderEnvironment.workspaceRoom
    private var isProjectionFrozen = false
    private var frozenProjectionParameters: ProjectionParameters?
    private var fpsFrameCount = 0
    private var fpsWindowStart = CACurrentMediaTime()

    func configure(view: MTKView) {
        guard let device else { return }

        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = clearColor(for: currentEnvironment)
        view.preferredFramesPerSecond = 60
        view.delegate = self

        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
            buildPipeline(device: device, view: view)
            buildScene(device: device)
        }
    }

    func update(pose: HeadPose, calibration: CalibrationProfile, environment: RenderEnvironment, isFrozen: Bool) {
        currentPose = pose
        currentCalibration = calibration
        if currentEnvironment != environment {
            currentEnvironment = environment
            frozenProjectionParameters = nil
            if let device {
                buildScene(device: device)
            }
        }

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
        let lineVertices = buildLineVertices(for: currentEnvironment)
        let triangleVertices = buildTriangleVertices(for: currentEnvironment)

        lineVertexCount = lineVertices.count
        triangleVertexCount = triangleVertices.count

        lineVertexBuffer = device.makeBuffer(bytes: lineVertices, length: MemoryLayout<RenderVertex>.stride * lineVertices.count)
        triangleVertexBuffer = device.makeBuffer(bytes: triangleVertices, length: MemoryLayout<RenderVertex>.stride * triangleVertices.count)
    }

    private func buildLineVertices(for environment: RenderEnvironment) -> [RenderVertex] {
        switch environment {
        case .workspaceRoom:
            return buildWorkspaceLineVertices()
        case .targetTunnel:
            return buildTargetTunnelLineVertices()
        }
    }

    private func buildTriangleVertices(for environment: RenderEnvironment) -> [RenderVertex] {
        switch environment {
        case .workspaceRoom:
            return buildWorkspaceTriangleVertices()
        case .targetTunnel:
            return buildTargetTunnelTriangleVertices()
        }
    }

    private func buildWorkspaceLineVertices() -> [RenderVertex] {
        var vertices: [RenderVertex] = []
        let portalColor = SIMD4<Float>(0.79, 0.80, 0.84, 1)
        let gridColor = SIMD4<Float>(0.28, 0.47, 0.57, 1)
        let accentColor = SIMD4<Float>(0.86, 0.72, 0.42, 1)
        let outlineColor = SIMD4<Float>(0.16, 0.18, 0.22, 1)
        let trimOutlineColor = SIMD4<Float>(0.22, 0.20, 0.16, 1)
        let floatingOutlineColor = SIMD4<Float>(0.90, 0.53, 0.28, 1)

        let frontRoomCorners: [SIMD3<Float>] = [
            SIMD3<Float>(-1.05, -0.72, -0.24),
            SIMD3<Float>(1.05, -0.72, -0.24),
            SIMD3<Float>(1.05, 0.78, -0.24),
            SIMD3<Float>(-1.05, 0.78, -0.24),
        ]

        let backRoomCorners: [SIMD3<Float>] = [
            SIMD3<Float>(-2.0, -1.0, -3.35),
            SIMD3<Float>(2.0, -1.0, -3.35),
            SIMD3<Float>(2.0, 1.4, -3.35),
            SIMD3<Float>(-2.0, 1.4, -3.35),
        ]

        let roomEdges = [
            (0, 1), (1, 2), (2, 3), (3, 0),
            (4, 5), (5, 6), (6, 7), (7, 4),
            (0, 4), (1, 5), (2, 6), (3, 7)
        ]

        for edge in roomEdges {
            let start = edge.0 < 4 ? frontRoomCorners[edge.0] : backRoomCorners[edge.0 - 4]
            let end = edge.1 < 4 ? frontRoomCorners[edge.1] : backRoomCorners[edge.1 - 4]
            vertices.append(RenderVertex(position: start, color: portalColor))
            vertices.append(RenderVertex(position: end, color: portalColor))
        }

        appendFloorGrid(
            xRange: -1.8 ... 1.8,
            zRange: -3.15 ... -0.45,
            y: -0.958,
            step: 0.3,
            color: gridColor,
            into: &vertices
        )

        appendBoxEdges(center: SIMD3<Float>(-1.02, 0.38, -3.3), size: SIMD3<Float>(1.18, 1.14, 0.12), color: trimOutlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(-1.02, 0.38, -3.25), size: SIMD3<Float>(0.94, 0.9, 0.05), color: accentColor, into: &vertices)
        appendLine(from: SIMD3<Float>(-1.02, -0.07, -3.275), to: SIMD3<Float>(-1.02, 0.83, -3.275), color: accentColor, into: &vertices)
        appendLine(from: SIMD3<Float>(-1.49, 0.38, -3.275), to: SIMD3<Float>(-0.55, 0.38, -3.275), color: accentColor, into: &vertices)

        appendBoxEdges(center: SIMD3<Float>(0.52, -0.48, -1.92), size: SIMD3<Float>(1.45, 0.08, 0.72), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(0.52, 0.0, -2.28), size: SIMD3<Float>(0.66, 0.42, 0.06), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(0.52, -0.44, -1.72), size: SIMD3<Float>(0.46, 0.04, 0.18), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(0.94, -0.43, -1.68), size: SIMD3<Float>(0.18, 0.06, 0.24), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(1.45, -0.34, -2.58), size: SIMD3<Float>(0.54, 0.94, 0.44), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(-1.42, -0.55, -2.52), size: SIMD3<Float>(0.44, 0.38, 0.44), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(-1.42, 0.08, -2.68), size: SIMD3<Float>(0.64, 0.04, 0.26), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(0, 0.92, -1.32), size: SIMD3<Float>(1.1, 0.08, 0.18), color: outlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(-0.24, -0.06, -1.48), size: SIMD3<Float>(0.3, 0.3, 0.3), color: floatingOutlineColor, into: &vertices)
        appendBoxEdges(center: SIMD3<Float>(-0.24, -0.84, -1.48), size: SIMD3<Float>(0.46, 0.02, 0.46), color: gridColor, into: &vertices)

        return vertices
    }

    private func buildTargetTunnelLineVertices() -> [RenderVertex] {
        var vertices: [RenderVertex] = []
        let frameColor = SIMD4<Float>(0.22, 0.27, 0.32, 1)
        let connectorColor = SIMD4<Float>(0.33, 0.40, 0.47, 1)
        let nodeColor = SIMD4<Float>(0.55, 0.58, 0.63, 1)

        let frameDepths: [Float] = [-0.45, -0.8, -1.15, -1.5, -1.85, -2.2, -2.55, -2.9]
        let frameMin = SIMD2<Float>(-1.26, -0.78)
        let frameMax = SIMD2<Float>(1.26, 0.78)

        for depth in frameDepths {
            appendRectOutline(min: frameMin, max: frameMax, z: depth, color: frameColor, into: &vertices)
        }

        for index in 0..<(frameDepths.count - 1) {
            let nearZ = frameDepths[index]
            let farZ = frameDepths[index + 1]
            appendLine(from: SIMD3<Float>(frameMin.x, frameMin.y, nearZ), to: SIMD3<Float>(frameMin.x, frameMin.y, farZ), color: connectorColor, into: &vertices)
            appendLine(from: SIMD3<Float>(frameMax.x, frameMin.y, nearZ), to: SIMD3<Float>(frameMax.x, frameMin.y, farZ), color: connectorColor, into: &vertices)
            appendLine(from: SIMD3<Float>(frameMax.x, frameMax.y, nearZ), to: SIMD3<Float>(frameMax.x, frameMax.y, farZ), color: connectorColor, into: &vertices)
            appendLine(from: SIMD3<Float>(frameMin.x, frameMax.y, nearZ), to: SIMD3<Float>(frameMin.x, frameMax.y, farZ), color: connectorColor, into: &vertices)
        }

        let targets = targetTunnelTargets()
        let connections = [(0, 1), (0, 2), (2, 3), (2, 5), (5, 6), (6, 7), (4, 5), (8, 2)]
        for connection in connections {
            appendLine(
                from: targets[connection.0].center,
                to: targets[connection.1].center,
                color: nodeColor,
                into: &vertices
            )
        }

        appendLine(from: SIMD3<Float>(0, 0, -0.35), to: SIMD3<Float>(0, 0, -3.05), color: connectorColor, into: &vertices)
        appendLine(from: SIMD3<Float>(-0.72, -0.52, -0.55), to: SIMD3<Float>(0.74, -0.52, -2.45), color: connectorColor, into: &vertices)

        return vertices
    }

    private func buildWorkspaceTriangleVertices() -> [RenderVertex] {
        let floorColor = SIMD4<Float>(0.40, 0.35, 0.29, 1)
        let wallColor = SIMD4<Float>(0.84, 0.81, 0.75, 1)
        let sideWallColor = SIMD4<Float>(0.79, 0.77, 0.72, 1)
        let ceilingColor = SIMD4<Float>(0.89, 0.87, 0.82, 1)
        let rugColor = SIMD4<Float>(0.24, 0.32, 0.38, 1)
        let deskColor = SIMD4<Float>(0.58, 0.42, 0.28, 1)
        let metalColor = SIMD4<Float>(0.59, 0.62, 0.68, 1)
        let monitorColor = SIMD4<Float>(0.12, 0.13, 0.16, 1)
        let screenColor = SIMD4<Float>(0.21, 0.52, 0.70, 1)
        let accentColor = SIMD4<Float>(0.82, 0.68, 0.34, 1)
        let cabinetColor = SIMD4<Float>(0.32, 0.34, 0.39, 1)
        let plantPotColor = SIMD4<Float>(0.69, 0.41, 0.26, 1)
        let plantLeafColor = SIMD4<Float>(0.34, 0.57, 0.36, 1)
        let bookColorA = SIMD4<Float>(0.73, 0.44, 0.37, 1)
        let bookColorB = SIMD4<Float>(0.46, 0.56, 0.77, 1)
        let bookColorC = SIMD4<Float>(0.80, 0.70, 0.49, 1)
        let floatingCoreColor = SIMD4<Float>(0.93, 0.57, 0.27, 1)
        let floatingAccentColor = SIMD4<Float>(0.98, 0.83, 0.56, 1)
        let floatingShadowColor = SIMD4<Float>(0.12, 0.15, 0.18, 1)

        var vertices: [RenderVertex] = []

        vertices += makeShadedBox(center: SIMD3<Float>(0, -0.99, -1.92), size: SIMD3<Float>(4.0, 0.04, 3.1), color: floorColor)
        vertices += makeShadedBox(center: SIMD3<Float>(0, 1.18, -1.92), size: SIMD3<Float>(4.0, 0.04, 3.1), color: ceilingColor)
        vertices += makeShadedBox(center: SIMD3<Float>(0, 0.2, -3.35), size: SIMD3<Float>(4.0, 2.4, 0.05), color: wallColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-2.0, 0.2, -1.92), size: SIMD3<Float>(0.05, 2.4, 3.1), color: sideWallColor)
        vertices += makeShadedBox(center: SIMD3<Float>(2.0, 0.2, -1.92), size: SIMD3<Float>(0.05, 2.4, 3.1), color: sideWallColor)

        vertices += makeShadedBox(center: SIMD3<Float>(0.1, -0.955, -2.02), size: SIMD3<Float>(2.25, 0.04, 1.32), color: rugColor)

        vertices += makeShadedBox(center: SIMD3<Float>(-1.02, 0.38, -3.3), size: SIMD3<Float>(1.18, 1.14, 0.12), color: accentColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.02, 0.38, -3.25), size: SIMD3<Float>(0.94, 0.9, 0.05), color: wallColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.02, 0.38, -3.225), size: SIMD3<Float>(0.82, 0.78, 0.03), color: screenColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.02, -0.2, -3.2), size: SIMD3<Float>(0.88, 0.05, 0.22), color: accentColor)

        vertices += makeShadedBox(center: SIMD3<Float>(0.52, -0.48, -1.92), size: SIMD3<Float>(1.45, 0.08, 0.72), color: deskColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-0.08, -0.82, -1.66), size: SIMD3<Float>(0.08, 0.6, 0.08), color: deskColor)
        vertices += makeShadedBox(center: SIMD3<Float>(1.12, -0.82, -1.66), size: SIMD3<Float>(0.08, 0.6, 0.08), color: deskColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-0.08, -0.82, -2.18), size: SIMD3<Float>(0.08, 0.6, 0.08), color: deskColor)
        vertices += makeShadedBox(center: SIMD3<Float>(1.12, -0.82, -2.18), size: SIMD3<Float>(0.08, 0.6, 0.08), color: deskColor)
        vertices += makeShadedBox(center: SIMD3<Float>(0.48, -0.7, -1.92), size: SIMD3<Float>(0.92, 0.06, 0.18), color: deskColor)

        vertices += makeShadedBox(center: SIMD3<Float>(0.52, 0.0, -2.28), size: SIMD3<Float>(0.66, 0.42, 0.08), color: monitorColor)
        vertices += makeShadedBox(center: SIMD3<Float>(0.52, 0.0, -2.22), size: SIMD3<Float>(0.54, 0.3, 0.02), color: screenColor)
        vertices += makeShadedBox(center: SIMD3<Float>(0.52, -0.25, -2.24), size: SIMD3<Float>(0.05, 0.22, 0.07), color: metalColor)
        vertices += makeShadedBox(center: SIMD3<Float>(0.52, -0.37, -2.15), size: SIMD3<Float>(0.22, 0.03, 0.16), color: metalColor)

        vertices += makeShadedBox(center: SIMD3<Float>(0.42, -0.44, -1.72), size: SIMD3<Float>(0.46, 0.04, 0.18), color: monitorColor)
        vertices += makeShadedBox(center: SIMD3<Float>(0.94, -0.43, -1.68), size: SIMD3<Float>(0.18, 0.06, 0.24), color: accentColor)

        vertices += makeShadedBox(center: SIMD3<Float>(1.45, -0.34, -2.58), size: SIMD3<Float>(0.54, 0.94, 0.44), color: cabinetColor)
        vertices += makeShadedBox(center: SIMD3<Float>(1.45, -0.02, -2.58), size: SIMD3<Float>(0.48, 0.02, 0.4), color: metalColor)
        vertices += makeShadedBox(center: SIMD3<Float>(1.45, 0.3, -2.58), size: SIMD3<Float>(0.48, 0.02, 0.4), color: metalColor)
        vertices += makeShadedBox(center: SIMD3<Float>(1.32, -0.66, -2.38), size: SIMD3<Float>(0.14, 0.18, 0.12), color: bookColorA)
        vertices += makeShadedBox(center: SIMD3<Float>(1.47, -0.63, -2.38), size: SIMD3<Float>(0.1, 0.24, 0.12), color: bookColorB)
        vertices += makeShadedBox(center: SIMD3<Float>(1.61, -0.64, -2.38), size: SIMD3<Float>(0.12, 0.22, 0.12), color: bookColorC)

        vertices += makeShadedBox(center: SIMD3<Float>(-1.42, -0.55, -2.52), size: SIMD3<Float>(0.44, 0.38, 0.44), color: plantPotColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.54, -0.18, -2.47), size: SIMD3<Float>(0.16, 0.38, 0.16), color: plantLeafColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.42, -0.08, -2.62), size: SIMD3<Float>(0.2, 0.48, 0.16), color: plantLeafColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.28, -0.16, -2.48), size: SIMD3<Float>(0.16, 0.34, 0.16), color: plantLeafColor)

        vertices += makeShadedBox(center: SIMD3<Float>(-1.42, 0.08, -2.68), size: SIMD3<Float>(0.64, 0.04, 0.26), color: deskColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.62, 0.28, -2.68), size: SIMD3<Float>(0.1, 0.36, 0.16), color: bookColorA)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.47, 0.25, -2.68), size: SIMD3<Float>(0.12, 0.3, 0.16), color: bookColorB)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.32, 0.24, -2.68), size: SIMD3<Float>(0.1, 0.28, 0.16), color: bookColorC)
        vertices += makeShadedBox(center: SIMD3<Float>(-1.15, 0.22, -2.68), size: SIMD3<Float>(0.14, 0.14, 0.16), color: accentColor)

        vertices += makeShadedBox(center: SIMD3<Float>(0, 0.92, -1.32), size: SIMD3<Float>(1.1, 0.08, 0.18), color: accentColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-0.24, -0.84, -1.48), size: SIMD3<Float>(0.46, 0.02, 0.46), color: floatingShadowColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-0.24, -0.06, -1.48), size: SIMD3<Float>(0.3, 0.3, 0.3), color: floatingCoreColor)
        vertices += makeShadedBox(center: SIMD3<Float>(-0.24, -0.06, -1.48), size: SIMD3<Float>(0.14, 0.42, 0.14), color: floatingAccentColor)

        return vertices
    }

    private func buildTargetTunnelTriangleVertices() -> [RenderVertex] {
        let panelColor = SIMD4<Float>(0.05, 0.06, 0.08, 1)
        let softPanelColor = SIMD4<Float>(0.08, 0.09, 0.12, 1)
        let glowColor = SIMD4<Float>(0.95, 0.48, 0.62, 1)
        let fillColor = SIMD4<Float>(0.98, 0.97, 0.99, 1)
        let coreColor = SIMD4<Float>(0.31, 0.33, 0.40, 1)
        let nodeColor = SIMD4<Float>(0.73, 0.74, 0.79, 1)

        var vertices: [RenderVertex] = []
        vertices += makeBox(center: SIMD3<Float>(0, 0, -1.95), size: SIMD3<Float>(2.7, 1.75, 0.02), color: panelColor)
        vertices += makeBox(center: SIMD3<Float>(0, 0, -3.08), size: SIMD3<Float>(2.52, 1.55, 0.02), color: softPanelColor)

        for target in targetTunnelTargets() {
            if target.isHighlighted {
                vertices += makeDiscBillboard(center: target.center, radius: target.radius * 1.1, segments: 28, color: glowColor)
            }
            vertices += makeRingBillboard(center: target.center, outerRadius: target.radius, innerRadius: target.radius * 0.7, segments: 28, color: glowColor)
            vertices += makeDiscBillboard(center: target.center, radius: target.radius * 0.64, segments: 28, color: fillColor)
            vertices += makeDiscBillboard(center: target.center, radius: target.radius * 0.16, segments: 20, color: coreColor)
        }

        let nodes: [(center: SIMD3<Float>, radius: Float)] = [
            (SIMD3<Float>(-0.22, 0.52, -1.15), 0.05),
            (SIMD3<Float>(0.24, 0.56, -1.42), 0.04),
            (SIMD3<Float>(-0.12, 0.06, -1.3), 0.06),
            (SIMD3<Float>(0.58, 0.02, -1.96), 0.05),
            (SIMD3<Float>(-0.58, -0.42, -1.84), 0.04)
        ]
        for node in nodes {
            vertices += makeDiscBillboard(center: node.center, radius: node.radius, segments: 20, color: nodeColor)
        }

        return vertices
    }

    private func makeBox(center: SIMD3<Float>, size: SIMD3<Float>, color: SIMD4<Float>) -> [RenderVertex] {
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

    private func makeShadedBox(center: SIMD3<Float>, size: SIMD3<Float>, color: SIMD4<Float>) -> [RenderVertex] {
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

        let faces: [(indices: [Int], intensity: Float)] = [
            ([0, 1, 2, 3], 1.03), // front
            ([1, 5, 6, 2], 0.82), // right
            ([5, 4, 7, 6], 0.7),  // back
            ([4, 0, 3, 7], 0.88), // left
            ([3, 2, 6, 7], 1.12), // top
            ([4, 5, 1, 0], 0.62), // bottom
        ]

        return faces.flatMap { face in
            let faceColor = tinted(color, intensity: face.intensity)
            return [
                RenderVertex(position: corners[face.indices[0]], color: faceColor),
                RenderVertex(position: corners[face.indices[1]], color: faceColor),
                RenderVertex(position: corners[face.indices[2]], color: faceColor),
                RenderVertex(position: corners[face.indices[0]], color: faceColor),
                RenderVertex(position: corners[face.indices[2]], color: faceColor),
                RenderVertex(position: corners[face.indices[3]], color: faceColor)
            ]
        }
    }

    private func tinted(_ color: SIMD4<Float>, intensity: Float) -> SIMD4<Float> {
        SIMD4<Float>(
            min(max(color.x * intensity, 0), 1),
            min(max(color.y * intensity, 0), 1),
            min(max(color.z * intensity, 0), 1),
            color.w
        )
    }

    private func makeDiscBillboard(
        center: SIMD3<Float>,
        radius: Float,
        segments: Int,
        color: SIMD4<Float>
    ) -> [RenderVertex] {
        let segmentCount = max(segments, 3)
        let angleStep = (Float.pi * 2) / Float(segmentCount)

        return (0..<segmentCount).flatMap { index in
            let startAngle = Float(index) * angleStep
            let endAngle = Float(index + 1) * angleStep
            let start = center + SIMD3<Float>(cos(startAngle) * radius, sin(startAngle) * radius, 0)
            let end = center + SIMD3<Float>(cos(endAngle) * radius, sin(endAngle) * radius, 0)

            return [
                RenderVertex(position: center, color: color),
                RenderVertex(position: start, color: color),
                RenderVertex(position: end, color: color)
            ]
        }
    }

    private func makeRingBillboard(
        center: SIMD3<Float>,
        outerRadius: Float,
        innerRadius: Float,
        segments: Int,
        color: SIMD4<Float>
    ) -> [RenderVertex] {
        let segmentCount = max(segments, 3)
        let angleStep = (Float.pi * 2) / Float(segmentCount)

        return (0..<segmentCount).flatMap { index in
            let startAngle = Float(index) * angleStep
            let endAngle = Float(index + 1) * angleStep

            let outerStart = center + SIMD3<Float>(cos(startAngle) * outerRadius, sin(startAngle) * outerRadius, 0)
            let outerEnd = center + SIMD3<Float>(cos(endAngle) * outerRadius, sin(endAngle) * outerRadius, 0)
            let innerStart = center + SIMD3<Float>(cos(startAngle) * innerRadius, sin(startAngle) * innerRadius, 0)
            let innerEnd = center + SIMD3<Float>(cos(endAngle) * innerRadius, sin(endAngle) * innerRadius, 0)

            return [
                RenderVertex(position: outerStart, color: color),
                RenderVertex(position: outerEnd, color: color),
                RenderVertex(position: innerEnd, color: color),
                RenderVertex(position: outerStart, color: color),
                RenderVertex(position: innerEnd, color: color),
                RenderVertex(position: innerStart, color: color)
            ]
        }
    }

    private func appendFloorGrid(
        xRange: ClosedRange<Float>,
        zRange: ClosedRange<Float>,
        y: Float,
        step: Float,
        color: SIMD4<Float>,
        into vertices: inout [RenderVertex]
    ) {
        guard step > 0 else { return }

        let normalizedXRange = min(xRange.lowerBound, xRange.upperBound) ... max(xRange.lowerBound, xRange.upperBound)
        let normalizedZRange = min(zRange.lowerBound, zRange.upperBound) ... max(zRange.lowerBound, zRange.upperBound)

        var x = normalizedXRange.lowerBound
        while x <= normalizedXRange.upperBound + 0.0001 {
            appendLine(
                from: SIMD3<Float>(x, y, normalizedZRange.lowerBound),
                to: SIMD3<Float>(x, y, normalizedZRange.upperBound),
                color: color,
                into: &vertices
            )
            x += step
        }

        var z = normalizedZRange.lowerBound
        while z <= normalizedZRange.upperBound + 0.0001 {
            appendLine(
                from: SIMD3<Float>(normalizedXRange.lowerBound, y, z),
                to: SIMD3<Float>(normalizedXRange.upperBound, y, z),
                color: color,
                into: &vertices
            )
            z += step
        }
    }

    private func appendRectOutline(
        min: SIMD2<Float>,
        max: SIMD2<Float>,
        z: Float,
        color: SIMD4<Float>,
        into vertices: inout [RenderVertex]
    ) {
        let bottomLeft = SIMD3<Float>(min.x, min.y, z)
        let bottomRight = SIMD3<Float>(max.x, min.y, z)
        let topRight = SIMD3<Float>(max.x, max.y, z)
        let topLeft = SIMD3<Float>(min.x, max.y, z)

        appendLine(from: bottomLeft, to: bottomRight, color: color, into: &vertices)
        appendLine(from: bottomRight, to: topRight, color: color, into: &vertices)
        appendLine(from: topRight, to: topLeft, color: color, into: &vertices)
        appendLine(from: topLeft, to: bottomLeft, color: color, into: &vertices)
    }

    private func appendBoxEdges(
        center: SIMD3<Float>,
        size: SIMD3<Float>,
        color: SIMD4<Float>,
        into vertices: inout [RenderVertex]
    ) {
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

        let edges = [
            (0, 1), (1, 2), (2, 3), (3, 0),
            (4, 5), (5, 6), (6, 7), (7, 4),
            (0, 4), (1, 5), (2, 6), (3, 7)
        ]

        for edge in edges {
            appendLine(from: corners[edge.0], to: corners[edge.1], color: color, into: &vertices)
        }
    }

    private func appendLine(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        color: SIMD4<Float>,
        into vertices: inout [RenderVertex]
    ) {
        vertices.append(RenderVertex(position: start, color: color))
        vertices.append(RenderVertex(position: end, color: color))
    }

    private func targetTunnelTargets() -> [(center: SIMD3<Float>, radius: Float, isHighlighted: Bool)] {
        [
            (SIMD3<Float>(-0.42, -0.22, -1.18), 0.11, false),
            (SIMD3<Float>(-0.16, -0.12, -1.34), 0.13, true),
            (SIMD3<Float>(0.62, -0.1, -1.9), 0.18, true),
            (SIMD3<Float>(-0.38, -0.42, -1.08), 0.08, false),
            (SIMD3<Float>(0.02, -0.52, -1.56), 0.08, false),
            (SIMD3<Float>(0.06, 0.42, -1.82), 0.07, false),
            (SIMD3<Float>(-0.24, 0.34, -1.52), 0.06, false),
            (SIMD3<Float>(0.52, 0.6, -2.26), 0.07, false),
            (SIMD3<Float>(-0.08, -0.34, -0.94), 0.07, false)
        ]
    }

    private func clearColor(for environment: RenderEnvironment) -> MTLClearColor {
        switch environment {
        case .workspaceRoom:
            MTLClearColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1)
        case .targetTunnel:
            MTLClearColor(red: 0.01, green: 0.01, blue: 0.02, alpha: 1)
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

        view.clearColor = clearColor(for: currentEnvironment)

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
