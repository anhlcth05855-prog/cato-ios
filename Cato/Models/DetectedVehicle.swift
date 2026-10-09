import Foundation
import CoreGraphics

/// Phân loại vị trí làn xe: Cùng làn xe ta (Ego lane), Làn trái, Làn phải
public enum LanePosition: String, Codable, CaseIterable {
    case currentLane = "CURRENT_LANE"
    case leftLane = "LEFT_LANE"
    case rightLane = "RIGHT_LANE"

    public var titleVi: String {
        switch self {
        case .currentLane: return "Cùng làn"
        case .leftLane: return "Làn trái"
        case .rightLane: return "Làn phải"
        }
    }
}

/// Loại phương tiện được nhận diện
public enum VehicleType: String, Codable, CaseIterable {
    case car = "car"
    case truck = "truck"
    case bus = "bus"
    case motorcycle = "motorcycle"

    public var defaultWidthMeters: Float {
        switch self {
        case .car: return 1.80
        case .truck: return 2.45
        case .bus: return 2.55
        case .motorcycle: return 0.85
        }
    }

    public var titleVi: String {
        switch self {
        case .car: return "Ô tô con"
        case .truck: return "Xe tải"
        case .bus: return "Xe khách"
        case .motorcycle: return "Xe máy"
        }
    }
}

/// Thông tin phương tiện nhận diện trên khung hình camera
public struct DetectedVehicle: Identifiable, Equatable {
    public let id: Int
    public var label: String
    public var confidence: Float
    /// Bounding box chuẩn hóa trong khoảng [0, 1] trên khung hình camera
    /// x, y, width, height theo hệ tọa độ iOS (origin ở góc trên bên trái)
    public var boundingBox: CGRect
    public var distanceMeters: Float
    public var headwaySeconds: Float
    public var lanePosition: LanePosition
    public var isLeadVehicle: BooleanLiteralType

    public init(
        id: Int,
        label: String = "car",
        confidence: Float = 0.85,
        boundingBox: CGRect = .zero,
        distanceMeters: Float = 0,
        headwaySeconds: Float = 0,
        lanePosition: LanePosition = .currentLane,
        isLeadVehicle: Bool = false
    ) {
        self.id = id
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.distanceMeters = distanceMeters
        self.headwaySeconds = headwaySeconds
        self.lanePosition = lanePosition
        self.isLeadVehicle = isLeadVehicle
    }
}
