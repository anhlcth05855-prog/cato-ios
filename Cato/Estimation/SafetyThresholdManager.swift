import Foundation

/// Quản lý khoảng cách an toàn chuẩn theo quy định của Bộ Giao thông Vận tải
/// (Thông tư 38/2024/TT-BGTVT và Thông tư 31/2019/TT-BGTVT Điều 11 - Khoảng cách an toàn giữa hai xe trên đường bộ):
/// - v <= 60 km/h: Người lái xe chủ động giữ khoảng cách an toàn phù hợp với mật độ giao thông
/// - 60 < v <= 80 km/h: 35 mét
/// - 80 < v <= 100 km/h: 55 mét
/// - 100 < v <= 120 km/h: 70 mét
/// - v > 120 km/h: 100 mét
public class SafetyThresholdManager: ObservableObject {

    /// Bù ngưỡng an toàn được thiết lập trong Cài đặt (+0m, +5m, +10m)
    @Published public var thresholdBufferMeters: Float = 0

    public init(thresholdBufferMeters: Float = 0) {
        self.thresholdBufferMeters = thresholdBufferMeters
    }

    /// Lấy mốc khoảng cách an toàn tối thiểu theo mét quy định trong luật
    /// Trả về nil nếu ở dải <= 60 km/h (vì luật quy định người lái chủ động)
    public func getStatutoryDistanceLimit(speedKmh: Float) -> Int? {
        switch speedKmh {
        case ...60:
            return nil
        case 60.01...80:
            return 35
        case 80.01...100:
            return 55
        case 100.01...120:
            return 70
        default:
            return 100
        }
    }

    /// Lấy ngưỡng khoảng cách tối thiểu cơ sở (mét) để tính toán an toàn
    public func getBaseStatutoryThreshold(speedKmh: Float) -> Float {
        switch speedKmh {
        case ...60:
            return 10.0 // Dưới 60 km/h: Cảnh báo va chạm khẩn cấp khi < 10m
        case 60.01...80:
            return 35.0
        case 80.01...100:
            return 55.0
        case 100.01...120:
            return 70.0
        default:
            return 100.0
        }
    }

    /// Lấy chuỗi hiển thị ngưỡng trên giao diện HUD
    public func getThresholdDisplayText(speedKmh: Float) -> String {
        switch speedKmh {
        case ...60:
            return "Chủ động giữ KC"
        case 60.01...80:
            return "Ngưỡng 35 m"
        case 80.01...100:
            return "Ngưỡng 55 m"
        case 100.01...120:
            return "Ngưỡng 70 m"
        default:
            return "Ngưỡng 100 m"
        }
    }

    /// Lấy ngưỡng cảnh báo thực tế sau khi cộng thêm buffer tùy chọn của người dùng
    public func getEffectiveThreshold(speedKmh: Float) -> Float {
        let base = getBaseStatutoryThreshold(speedKmh: speedKmh)
        let buffer = (speedKmh > 60) ? thresholdBufferMeters : 0
        return base + buffer
    }

    /// Lấy mô tả dải tốc độ theo văn bản luật Thông tư 38/2024 / 31/2019
    public func getSpeedBandDescription(speedKmh: Float) -> String {
        switch speedKmh {
        case ...60:
            return "≤ 60 km/h (Chủ động giữ khoảng cách)"
        case 60.01...80:
            return "60 – 80 km/h (Ngưỡng 35 m)"
        case 80.01...100:
            return "80 – 100 km/h (Ngưỡng 55 m)"
        case 100.01...120:
            return "100 – 120 km/h (Ngưỡng 70 m)"
        default:
            return "> 120 km/h (Ngưỡng 100 m)"
        }
    }

    /// Đánh giá mức độ an toàn dựa trên khoảng cách đo được và tốc độ hiện tại
    public func evaluate(distanceMeters: Float, speedKmh: Float) -> SafetyAssessment {
        let effectiveThreshold = getEffectiveThreshold(speedKmh: speedKmh)
        let speedMps = max(speedKmh / 3.6, 0.1)
        let headwaySeconds = distanceMeters / speedMps

        let alertLevel: AlertLevel
        if distanceMeters <= 0 {
            alertLevel = .safe
        } else if speedKmh <= 60 {
            // Tốc độ <= 60 km/h: Chủ động giữ khoảng cách theo mật độ đường sá
            if distanceMeters < 8.0 {
                alertLevel = .danger // Quá gần, nguy cơ va chạm khẩn cấp
            } else if distanceMeters < 15.0 {
                alertLevel = .caution // Khá gần
            } else {
                alertLevel = .safe
            }
        } else {
            // Tốc độ > 60 km/h: Tuân thủ nghiêm ngặt ngưỡng tối thiểu theo luật (35m, 55m, 70m, 100m)
            if distanceMeters < effectiveThreshold {
                alertLevel = .danger
            } else if distanceMeters < effectiveThreshold * 1.15 || (speedKmh > 30 && headwaySeconds < 2.0) {
                alertLevel = .caution
            } else {
                alertLevel = .safe
            }
        }

        let isUnderThreshold: Bool
        if speedKmh <= 60 {
            isUnderThreshold = (distanceMeters > 0.1 && distanceMeters <= 8.0)
        } else {
            isUnderThreshold = (distanceMeters > 0.1 && distanceMeters <= effectiveThreshold)
        }

        return SafetyAssessment(
            alertLevel: alertLevel,
            speedKmh: speedKmh,
            currentDistanceMeters: distanceMeters,
            requiredThresholdMeters: effectiveThreshold,
            headwaySeconds: headwaySeconds,
            legalBandText: getSpeedBandDescription(speedKmh: speedKmh),
            thresholdDisplayText: getThresholdDisplayText(speedKmh: speedKmh),
            isUnderThreshold: isUnderThreshold
        )
    }
}
