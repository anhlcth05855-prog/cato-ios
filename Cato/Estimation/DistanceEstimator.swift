import Foundation
import CoreGraphics

/// Ước lượng khoảng cách vật lý từ hình học camera và kích thước phương tiện chuẩn
public class DistanceEstimator: ObservableObject {

    /// Chiều cao camera so với mặt đường (mặc định 1.25m cho sedan/crossover, SUV ~1.40m)
    @Published public var cameraHeightMeters: Float = 1.25

    /// Góc nghiêng pitch của camera (radian), dương khi chúc xuống mặt đường
    @Published public var pitchAngleRad: Float = 0.05

    /// Tiêu cự ảo chuẩn hóa (tương đương góc nhìn ~60-70 độ của camera góc rộng tiêu chuẩn trên iPhone)
    public var focalLengthNormalized: Float = 1.35

    /// Cache bộ lọc EMA theo ID phương tiện để làm mượt số đo, chống giật số
    private var distanceSmootherMap = [Int: Float]()

    public init(cameraHeightMeters: Float = 1.25, pitchAngleRad: Float = 0.05) {
        self.cameraHeightMeters = cameraHeightMeters
        self.pitchAngleRad = pitchAngleRad
    }

    /// Chuẩn kích thước chiều rộng trung bình (mét) theo loại phương tiện
    private func getStandardVehicleWidth(label: String) -> Float {
        switch label.lowercased() {
        case "car": return 1.80       // Ô tô con trung bình ~1.8m
        case "truck": return 2.45     // Xe tải ~2.45m
        case "bus": return 2.55       // Xe khách/buýt ~2.55m
        case "motorcycle": return 0.85 // Xe máy ~0.85m
        default: return 1.80
        }
    }

    /// Ước lượng khoảng cách dựa trên điểm tiếp đất của bánh xe (Bottom of Bounding Box)
    private func estimateGeometricDistance(box: CGRect) -> Float {
        let yBottom = Float(box.maxY)
        let yCenter: Float = 0.5 // Tâm quang học chuẩn hóa

        // Góc phụ từ tâm quang học xuống đáy bounding box
        let alpha = atan((yBottom - yCenter) / focalLengthNormalized)
        let totalAngle = pitchAngleRad + alpha

        if totalAngle <= 0.02 {
            return 120.0 // Quá xa hoặc nằm trên đường chân trời
        }

        let dist = cameraHeightMeters / tan(totalAngle)
        return min(max(dist, 1.5), 150.0)
    }

    /// Ước lượng khoảng cách dựa trên kích thước chiều rộng chiếu (Pinhole projection)
    private func estimateWidthDistance(box: CGRect, label: String) -> Float {
        let boxWidthNorm = max(Float(box.width), 0.01)
        let realWidth = getStandardVehicleWidth(label: label)
        let dist = (realWidth * focalLengthNormalized) / boxWidthNorm
        return min(max(dist, 1.5), 150.0)
    }

    /// Phân loại làn đường (cùng làn, làn trái, làn phải) dựa trên toạ độ ngang x
    private func determineLanePosition(box: CGRect) -> LanePosition {
        let centerX = Float(box.midX)
        // Phễu phối cảnh: xe càng gần (yBottom càng lớn) thì phạm vi làn trên màn hình càng mở rộng
        let yBottom = Float(box.maxY)
        let laneSpread = 0.16 + (yBottom - 0.5) * 0.12
        let leftBoundary = 0.5 - laneSpread
        let rightBoundary = 0.5 + laneSpread

        if centerX < leftBoundary {
            return .leftLane
        } else if centerX > rightBoundary {
            return .rightLane
        } else {
            return .currentLane
        }
    }

    /// Cập nhật và ước lượng khoảng cách cho toàn bộ danh sách phương tiện được nhận diện
    public func processVehicles(
        vehicles: [DetectedVehicle],
        currentSpeedKmh: Float
    ) -> [DetectedVehicle] {
        let speedMps = max(currentSpeedKmh / 3.6, 0.1)
        var updated = vehicles

        for i in 0..<updated.count {
            var v = updated[i]

            // 1. Phân loại làn đường
            v.lanePosition = determineLanePosition(box: v.boundingBox)

            // 2. Tính khoảng cách kết hợp (Nếu là xe mô phỏng / kiểm thử đã có sẵn khoảng cách, giữ nguyên)
            let rawDist: Float
            if v.distanceMeters > 0 && [888, 777, 999].contains(v.id) {
                rawDist = v.distanceMeters
            } else {
                let dGeom = estimateGeometricDistance(box: v.boundingBox)
                let dWidth = estimateWidthDistance(box: v.boundingBox, label: v.label)
                let weightGeom: Float = (dGeom < 40.0) ? 0.65 : 0.40
                rawDist = dGeom * weightGeom + dWidth * (1.0 - weightGeom)
            }

            // 3. Làm mượt bằng Exponential Moving Average (EMA) để chống giật số
            let prevDist = distanceSmootherMap[v.id] ?? rawDist
            let alphaSmooth: Float = 0.35 // Hệ số đáp ứng thích ứng
            let smoothDist = alphaSmooth * rawDist + (1.0 - alphaSmooth) * prevDist
            distanceSmootherMap[v.id] = smoothDist

            v.distanceMeters = smoothDist
            v.headwaySeconds = smoothDist / speedMps
            v.isLeadVehicle = false
            updated[i] = v
        }

        // 4. Tìm xe dẫn đầu cùng làn (xe gần nhất trong currentLane)
        var leadIndex: Int? = nil
        var minDistance: Float = Float.greatestFiniteMagnitude

        for i in 0..<updated.count {
            if updated[i].lanePosition == .currentLane && updated[i].distanceMeters < minDistance {
                minDistance = updated[i].distanceMeters
                leadIndex = i
            }
        }

        if let leadIdx = leadIndex {
            updated[leadIdx].isLeadVehicle = true
        }

        // Dọn dẹp cache các xe không còn xuất hiện
        let activeIds = Set(updated.map { $0.id })
        distanceSmootherMap = distanceSmootherMap.filter { activeIds.contains($0.key) }

        return updated
    }
}
