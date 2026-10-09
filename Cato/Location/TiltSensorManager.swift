import Foundation
import CoreMotion

/// Đo góc nghiêng pitch của điện thoại gắn trên kính lái bằng CoreMotion (Gia tốc kế / Con quay hồi chuyển)
public class TiltSensorManager: ObservableObject {

    public static let shared = TiltSensorManager()

    private let motionManager = CMMotionManager()
    @Published public var smoothedPitchRad: Float = 0.05

    public var onPitchChanged: ((Float) -> Void)?

    public init() {}

    public func start() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 0.1 // 10 Hz
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }

            let gravity = motion.gravity
            let x = gravity.x
            let y = gravity.y
            let z = gravity.z

            // Ở hướng Landscape ngang trên kính lái:
            // trục Z hướng trước/sau, trục Y hướng lên trên
            let norm = sqrt(x * x + y * y + z * z)
            if norm > 0 {
                let normalizedZ = min(max(z / norm, -1.0), 1.0)
                let pitch = Float(atan2(normalizedZ, sqrt(x * x + y * y)))

                // Lọc thông thấp (Low-pass filter) khử rung xóc khi xe chạy
                self.smoothedPitchRad = 0.95 * self.smoothedPitchRad + 0.05 * pitch
                self.onPitchChanged?(self.smoothedPitchRad)
            }
        }
    }

    public func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
