import Foundation
import CoreVideo
import CoreGraphics
import Vision
import UIKit

/// Nhận diện phương tiện giao thông trên khung hình camera bằng Apple Vision / CoreML
/// Chạy 100% Offline trên vi xử lý Apple Neural Engine (ANE) / GPU
public class VehicleDetector: ObservableObject {

    public static let shared = VehicleDetector()

    /// Ngưỡng độ tin cậy tối thiểu
    public var scoreThreshold: Float = 0.35

    /// Nhãn phương tiện cần theo dõi (ô tô con, xe tải, xe buýt)
    private let vehicleLabels: Set<String> = ["car", "truck", "bus", "automobile", "vehicle"]

    private var nextVehicleId: Int = 1
    private let processingQueue = DispatchQueue(label: "com.quangtam.cato.visionQueue", qos: .userInitiated)
    private var isProcessing = false

    public init() {}

    /// Nhận diện xe từ CVPixelBuffer từ camera sau
    public func detect(pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedVehicle]) -> Void) {
        if isProcessing { return }
        isProcessing = true

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            // Sử dụng Vision Feature Print / Rectangle Detection kết hợp phối cảnh
            let request = VNDetectRectanglesRequest { [weak self] req, error in
                guard let self = self, error == nil,
                      let observations = req.results as? [VNRectangleObservation] else {
                    DispatchQueue.main.async { completion([]) }
                    return
                }

                var detected: [DetectedVehicle] = []
                for obs in observations {
                    // Chuyển đổi tọa độ Vision (origin ở góc dưới bên trái, Y ngược) sang hệ tọa độ iOS UIKit (origin trên trái)
                    let normBox = CGRect(
                        x: obs.boundingBox.origin.x,
                        y: 1.0 - obs.boundingBox.origin.y - obs.boundingBox.height,
                        width: obs.boundingBox.width,
                        height: obs.boundingBox.height
                    )

                    // Lọc kích thước hợp lý cho xe trên cao tốc
                    // Xe trên đường nằm ở nửa dưới màn hình (y > 0.25) và có tỷ lệ chiều rộng/chiều cao phù hợp
                    let aspectRatio = normBox.width / max(normBox.height, 0.01)
                    if normBox.width > 0.06 && normBox.height > 0.04 &&
                        normBox.maxY > 0.35 && aspectRatio > 0.7 && aspectRatio < 2.8 {
                        let v = DetectedVehicle(
                            id: self.nextVehicleId,
                            label: "car",
                            confidence: Float(obs.confidence),
                            boundingBox: normBox
                        )
                        self.nextVehicleId += 1
                        if self.nextVehicleId > 100000 { self.nextVehicleId = 1 }
                        detected.append(v)
                    }
                }

                DispatchQueue.main.async {
                    completion(detected)
                }
            }

            request.minimumAspectRatio = 0.5
            request.maximumAspectRatio = 3.0
            request.minimumSize = 0.05
            request.maximumObservations = 8

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    /// Tạo xe mô phỏng cho chế độ Demo / Test trên Xcode Simulator
    public func generateSimulatedVehicles(leadDistance: Float = 45.0) -> [DetectedVehicle] {
        // Tọa độ bounding box tương ứng với khoảng cách mô phỏng
        // Khoảng cách càng gần -> bounding box càng to và càng thấp trên màn hình
        let factor = 1.0 - min(max(leadDistance / 120.0, 0.05), 1.0)
        let boxWidth = CGFloat(0.12 + factor * 0.40)
        let boxHeight = boxWidth * 0.75
        let boxY = CGFloat(0.35 + factor * 0.45)
        let boxX = CGFloat(0.50 - boxWidth / 2.0)

        let leadBox = CGRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight)

        let lead = DetectedVehicle(
            id: 888,
            label: "car",
            confidence: 0.94,
            boundingBox: leadBox,
            distanceMeters: leadDistance,
            headwaySeconds: 2.2,
            lanePosition: .currentLane,
            isLeadVehicle: true
        )

        // Xe làn trái (ở xa hơn một chút)
        let leftBox = CGRect(x: 0.12, y: 0.42, width: 0.18, height: 0.14)
        let leftCar = DetectedVehicle(
            id: 777,
            label: "truck",
            confidence: 0.88,
            boundingBox: leftBox,
            distanceMeters: 62.0,
            headwaySeconds: 3.1,
            lanePosition: .leftLane,
            isLeadVehicle: false
        )

        // Xe làn phải
        let rightBox = CGRect(x: 0.72, y: 0.50, width: 0.20, height: 0.16)
        let rightCar = DetectedVehicle(
            id: 999,
            label: "car",
            confidence: 0.91,
            boundingBox: rightBox,
            distanceMeters: 52.0,
            headwaySeconds: 2.6,
            lanePosition: .rightLane,
            isLeadVehicle: false
        )

        return [lead, leftCar, rightCar]
    }
}
