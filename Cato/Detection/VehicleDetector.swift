import Foundation
import CoreVideo
import CoreGraphics
import Vision
import CoreML
import UIKit
import QuartzCore

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

    // Bộ đệm theo dõi đa khung hình (Multi-frame Tracking) & chống giật 450ms
    private var lastTrackedVehicles: [DetectedVehicle] = []
    private var lastDetectionTime: TimeInterval = 0
    private let persistenceBufferSeconds: TimeInterval = 0.45

    private lazy var coreMLModel: VNCoreMLModel? = {
        let modelNames = ["yolov8n", "EfficientDet"]
        for name in modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc"),
               let mlModel = try? MLModel(contentsOf: url),
               let vnModel = try? VNCoreMLModel(for: mlModel) {
                return vnModel
            }
        }
        return nil
    }()

    public init() {}

    /// Nhận diện xe từ CVPixelBuffer từ camera sau
    public func detect(pixelBuffer: CVPixelBuffer, completion: @escaping ([DetectedVehicle]) -> Void) {
        if isProcessing { return }
        isProcessing = true

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            if let vnModel = self.coreMLModel {
                let request = VNCoreMLRequest(model: vnModel) { [weak self] req, error in
                    guard let self = self else { return }
                    if error == nil, let observations = req.results as? [VNRecognizedObjectObservation] {
                        var rawVehicles: [DetectedVehicle] = []
                        for obs in observations {
                            guard let topLabel = obs.labels.first,
                                  self.vehicleLabels.contains(topLabel.identifier.lowercased()),
                                  topLabel.confidence >= self.scoreThreshold else { continue }
                            let normBox = CGRect(
                                x: obs.boundingBox.origin.x,
                                y: 1.0 - obs.boundingBox.origin.y - obs.boundingBox.height,
                                width: obs.boundingBox.width,
                                height: obs.boundingBox.height
                            )
                            rawVehicles.append(DetectedVehicle(
                                id: 0,
                                label: topLabel.identifier.lowercased(),
                                confidence: Float(topLabel.confidence),
                                boundingBox: normBox
                            ))
                        }
                        let tracked = self.applyTrackingAndPersistence(rawVehicles)
                        DispatchQueue.main.async { completion(tracked) }
                    } else {
                        let fallback = self.applyTrackingAndPersistence([])
                        DispatchQueue.main.async { completion(fallback) }
                    }
                }
                request.imageCropAndScaleOption = .scaleFill
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    let fallback = self.applyTrackingAndPersistence([])
                    DispatchQueue.main.async { completion(fallback) }
                }
                return
            }

            // Fallback khi chưa nhúng file .mlmodelc: sử dụng Vision Rectangle Detection
            let request = VNDetectRectanglesRequest { [weak self] req, error in
                guard let self = self, error == nil,
                      let observations = req.results as? [VNRectangleObservation] else {
                    let fallback = self?.applyTrackingAndPersistence([]) ?? []
                    DispatchQueue.main.async { completion(fallback) }
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

                    let aspectRatio = normBox.width / max(normBox.height, 0.01)
                    if normBox.width > 0.06 && normBox.height > 0.04 &&
                        normBox.maxY > 0.35 && aspectRatio > 0.7 && aspectRatio < 2.8 {
                        let v = DetectedVehicle(
                            id: 0,
                            label: "car",
                            confidence: Float(obs.confidence),
                            boundingBox: normBox
                        )
                        detected.append(v)
                    }
                }

                let tracked = self.applyTrackingAndPersistence(detected)
                DispatchQueue.main.async {
                    completion(tracked)
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
                let fallback = self.applyTrackingAndPersistence([])
                DispatchQueue.main.async { completion(fallback) }
            }
        }
    }

    /// Khớp ID xe qua các khung hình liên tiếp dựa trên khoảng cách tâm (< 0.15) và giữ đệm 450ms chống nhấp nháy
    private func applyTrackingAndPersistence(_ rawVehicles: [DetectedVehicle]) -> [DetectedVehicle] {
        let now = CACurrentMediaTime()

        if rawVehicles.isEmpty {
            if now - lastDetectionTime <= persistenceBufferSeconds && !lastTrackedVehicles.isEmpty {
                return lastTrackedVehicles
            }
            lastTrackedVehicles = []
            return []
        }

        var assigned: [DetectedVehicle] = []
        var usedIds = Set<Int>()

        for v in rawVehicles {
            let center = CGPoint(x: v.boundingBox.midX, y: v.boundingBox.midY)
            var bestId: Int? = nil
            var bestDist: CGFloat = 0.15

            for prev in lastTrackedVehicles where !usedIds.contains(prev.id) {
                let prevCenter = CGPoint(x: prev.boundingBox.midX, y: prev.boundingBox.midY)
                let dist = hypot(center.x - prevCenter.x, center.y - prevCenter.y)
                if dist < bestDist {
                    bestDist = dist
                    bestId = prev.id
                }
            }

            let assignedId: Int
            if let matchedId = bestId {
                assignedId = matchedId
            } else {
                assignedId = nextVehicleId
                nextVehicleId = (nextVehicleId >= 100000) ? 1 : (nextVehicleId + 1)
            }
            usedIds.insert(assignedId)

            assigned.append(DetectedVehicle(
                id: assignedId,
                label: v.label,
                confidence: v.confidence,
                boundingBox: v.boundingBox
            ))
        }

        lastTrackedVehicles = assigned
        lastDetectionTime = now
        return assigned
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
