import AVFoundation
import UIKit
import QuartzCore

/// Quản lý luồng camera sau thời gian thực bằng AVFoundation
public class CameraFeedManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    public static let shared = CameraFeedManager()

    @Published public var isAuthorized: Bool = false
    @Published public var isRunning: Bool = false
    @Published public var isCameraAvailable: Bool = true

    public let captureSession = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.quangtam.cato.cameraSessionQueue")

    public var onFrameCaptured: ((CVPixelBuffer) -> Void)?

    private var lastFrameTime: TimeInterval = 0
    private let targetFrameInterval: TimeInterval = 1.0 / 20.0 // 20 FPS tối ưu nhiệt độ và pin trên taplo

    override public init() {
        super.init()
        checkPermission()
    }

    public func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            DispatchQueue.main.async { self.isAuthorized = false }
        }
    }

    public func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .hd1280x720 // 720p sắc nét, mượt mà và mát máy

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                DispatchQueue.main.async {
                    self.isCameraAvailable = false
                }
                self.captureSession.commitConfiguration()
                return
            }

            self.captureSession.addInput(videoInput)

            // Cấu hình định dạng pixel kCVPixelFormatType_32BGRA
            self.videoDataOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)
            ]
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)

            if self.captureSession.canAddOutput(self.videoDataOutput) {
                self.captureSession.addOutput(self.videoDataOutput)
            }

            // Đặt hướng camera
            if let connection = self.videoDataOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight
            }

            self.captureSession.commitConfiguration()
            self.start()
        }
    }

    public func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                }
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastFrameTime >= targetFrameInterval else {
            return
        }
        lastFrameTime = currentTime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameCaptured?(pixelBuffer)
    }
}
