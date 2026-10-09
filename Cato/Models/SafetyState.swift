import SwiftUI

/// 3 Mức độ cảnh báo khoảng cách an toàn theo luật và khoảng cách thực tế
public enum AlertLevel: String, Codable, CaseIterable {
    case safe = "SAFE"         // An toàn (Xanh lá #2ECC71)
    case caution = "CAUTION"   // Thận trọng (Vàng cam #F5C518)
    case danger = "DANGER"     // Quá gần / Nguy hiểm (Đỏ rực #FF3B30)

    public var titleVi: String {
        switch self {
        case .safe: return "An toàn"
        case .caution: return "Thận trọng"
        case .danger: return "Quá gần"
        }
    }

    public var color: Color {
        switch self {
        case .safe: return Color(red: 46/255, green: 204/255, blue: 113/255)       // #2ECC71
        case .caution: return Color(red: 245/255, green: 197/255, blue: 24/255)   // #F5C518
        case .danger: return Color(red: 255/255, green: 59/255, blue: 48/255)     // #FF3B30
        }
    }

    public var hexString: String {
        switch self {
        case .safe: return "#2ECC71"
        case .caution: return "#F5C518"
        case .danger: return "#FF3B30"
        }
    }
}

/// Đánh giá trạng thái an toàn tổng thể
public struct SafetyAssessment: Equatable {
    public let alertLevel: AlertLevel
    public let speedKmh: Float
    public let currentDistanceMeters: Float
    public let requiredThresholdMeters: Float
    public let headwaySeconds: Float
    public let legalBandText: String
    public let thresholdDisplayText: String
    public let isUnderThreshold: Bool

    public init(
        alertLevel: AlertLevel = .safe,
        speedKmh: Float = 0,
        currentDistanceMeters: Float = 0,
        requiredThresholdMeters: Float = 35,
        headwaySeconds: Float = 0,
        legalBandText: String = "≤ 60 km/h (Chủ động giữ khoảng cách)",
        thresholdDisplayText: String = "Chủ động giữ KC",
        isUnderThreshold: Bool = false
    ) {
        self.alertLevel = alertLevel
        self.speedKmh = speedKmh
        self.currentDistanceMeters = currentDistanceMeters
        self.requiredThresholdMeters = requiredThresholdMeters
        self.headwaySeconds = headwaySeconds
        self.legalBandText = legalBandText
        self.thresholdDisplayText = thresholdDisplayText
        self.isUnderThreshold = isUnderThreshold
    }
}
