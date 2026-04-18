import AVFoundation
import Combine
import CoreMedia
import Foundation
import QuartzCore

final class CameraCaptureService: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var isRunning = false
    @Published private(set) var averageFPS: Double = 0
    @Published private(set) var errorMessage: String?

    let session = AVCaptureSession()
    var onFrame: ((CameraFrame) -> Void)?

    private let sessionQueue = DispatchQueue(label: "CameraCaptureService.session", qos: .userInitiated)
    private var isConfigured = false
    private var frameCounter = 0
    private var fpsWindowStart = CACurrentMediaTime()

    override init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
        session.sessionPreset = .high
    }

    func start() {
        switch authorizationStatus {
        case .authorized:
            configureAndStartIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.authorizationStatus = granted ? .authorized : .denied
                }
                if granted {
                    self.configureAndStartIfNeeded()
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access is unavailable. Grant camera permission in System Settings."
        @unknown default:
            errorMessage = "Unknown camera permission status."
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    private func configureAndStartIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.isConfigured {
                do {
                    try self.configureSession()
                    self.isConfigured = true
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
            }

            guard !self.session.isRunning else { return }

            self.session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
                self.errorMessage = nil
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = preferredCameraDevice() else {
            throw CameraCaptureError.noCameraDevice
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.failedToAddInput
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        guard session.canAddOutput(output) else {
            throw CameraCaptureError.failedToAddOutput
        }

        session.addInput(input)
        session.addOutput(output)
    }

    private func preferredCameraDevice() -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first ?? AVCaptureDevice.default(for: .video)
    }

    private func updateFPS() {
        frameCounter += 1
        let now = CACurrentMediaTime()
        let elapsed = now - fpsWindowStart
        guard elapsed >= 0.5 else { return }

        let fps = Double(frameCounter) / elapsed
        frameCounter = 0
        fpsWindowStart = now

        DispatchQueue.main.async {
            self.averageFPS = fps
        }
    }
}

extension CameraCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let frame = CameraFrame(
            pixelBuffer: pixelBuffer,
            timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            dimensions: CGSize(width: width, height: height)
        )

        updateFPS()
        onFrame?(frame)
    }
}

extension CameraCaptureService {
    enum CameraCaptureError: LocalizedError {
        case noCameraDevice
        case failedToAddInput
        case failedToAddOutput

        var errorDescription: String? {
            switch self {
            case .noCameraDevice:
                return "No compatible camera device was found."
            case .failedToAddInput:
                return "The camera input could not be added to the capture session."
            case .failedToAddOutput:
                return "The camera output could not be added to the capture session."
            }
        }
    }
}
