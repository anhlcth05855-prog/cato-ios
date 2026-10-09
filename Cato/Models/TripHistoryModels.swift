import Foundation
import CoreLocation

/// Điểm tọa độ GPS trong hành trình di chuyển
public struct GpsPoint: Identifiable, Codable, Equatable {
    public var id: String { "\(latitude)_\(longitude)_\(timestamp)" }
    public let latitude: Double
    public let longitude: Double
    public let speedKmh: Float
    public let timestamp: Int64
    public var roadName: String

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        latitude: Double,
        longitude: Double,
        speedKmh: Float,
        timestamp: Int64,
        roadName: String = ""
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.speedKmh = speedKmh
        self.timestamp = timestamp
        self.roadName = roadName
    }
}

/// Phân loại sự kiện trên dòng thời gian hành trình
public enum TimelineEventType: String, Codable, CaseIterable {
    case stop = "STOP"          // Dừng đỗ xe (Parking / Stop)
    case driving = "DRIVING"    // Đang di chuyển (Driving leg)

    public var titleVi: String {
        switch self {
        case .stop: return "Dừng đỗ xe"
        case .driving: return "Đang di chuyển"
        }
    }

    public var iconName: String {
        switch self {
        case .stop: return "parkingsign.circle.fill"
        case .driving: return "car.fill"
        }
    }
}

/// Một sự kiện trên dòng thời gian (Điểm dừng đỗ hoặc Chặng di chuyển)
public struct TimelineEvent: Identifiable, Codable, Equatable {
    public let id: String
    public let type: TimelineEventType
    public var locationName: String
    public let startTime: Int64
    public let endTime: Int64
    public let durationMinutes: Int64
    public var distanceKm: Float
    public var maxSpeedKmh: Float
    public var avgSpeedKmh: Float
    public let latitude: Double
    public let longitude: Double
    public var endLatitude: Double
    public var endLongitude: Double
    public var startAddress: String
    public var endAddress: String
    public var points: [GpsPoint]

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }

    public var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: Double(startTime) / 1000.0))
    }

    public var endTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date(timeIntervalSince1970: Double(endTime) / 1000.0))
    }

    public var timeRangeString: String {
        "\(startTimeString) - \(endTimeString)"
    }

    public var durationFormatted: String {
        let mins = durationMinutes
        let h = mins / 60
        let m = mins % 60
        if h > 0 && m > 0 {
            return "\(h) tiếng \(m) phút"
        } else if h > 0 {
            return "\(h) tiếng"
        } else {
            return "\(mins) phút"
        }
    }

    public init(
        id: String,
        type: TimelineEventType,
        locationName: String,
        startTime: Int64,
        endTime: Int64,
        durationMinutes: Int64,
        distanceKm: Float = 0,
        maxSpeedKmh: Float = 0,
        avgSpeedKmh: Float = 0,
        latitude: Double,
        longitude: Double,
        endLatitude: Double = 0,
        endLongitude: Double = 0,
        startAddress: String = "",
        endAddress: String = "",
        points: [GpsPoint] = []
    ) {
        self.id = id
        self.type = type
        self.locationName = locationName
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.distanceKm = distanceKm
        self.maxSpeedKmh = maxSpeedKmh
        self.avgSpeedKmh = avgSpeedKmh
        self.latitude = latitude
        self.longitude = longitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.points = points
    }
}

/// Bản ghi một chuyến đi hoàn chỉnh
public struct TripRecord: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var dateString: String // yyyy-MM-dd
    public let startTime: Int64
    public let endTime: Int64
    public var totalDistanceMeters: Float
    public var maxSpeedKmh: Float
    public var avgSpeedKmh: Float
    public var startAddress: String
    public var endAddress: String
    public var points: [GpsPoint]

    public var distanceKmString: String {
        String(format: "%.1f km", totalDistanceMeters / 1000.0)
    }

    public var durationMinutes: Int64 {
        max(1, (endTime - startTime) / 60000)
    }

    public var durationFormatted: String {
        let mins = durationMinutes
        let h = mins / 60
        let m = mins % 60
        if h > 0 && m > 0 {
            return "\(h) tiếng \(m) phút"
        } else if h > 0 {
            return "\(h) tiếng"
        } else {
            return "\(mins) phút"
        }
    }

    public var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let startStr = formatter.string(from: Date(timeIntervalSince1970: Double(startTime) / 1000.0))
        let endStr = formatter.string(from: Date(timeIntervalSince1970: Double(endTime) / 1000.0))
        return "\(startStr) - \(endStr)"
    }

    public init(
        id: String,
        title: String,
        dateString: String,
        startTime: Int64,
        endTime: Int64,
        totalDistanceMeters: Float,
        maxSpeedKmh: Float,
        avgSpeedKmh: Float,
        startAddress: String,
        endAddress: String,
        points: [GpsPoint]
    ) {
        self.id = id
        self.title = title
        self.dateString = dateString
        self.startTime = startTime
        self.endTime = endTime
        self.totalDistanceMeters = totalDistanceMeters
        self.maxSpeedKmh = maxSpeedKmh
        self.avgSpeedKmh = avgSpeedKmh
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.points = points
    }
}

/// Tổng hợp dòng thời gian và các chặng di chuyển theo từng ngày
public struct TimelineDay: Identifiable, Codable, Equatable {
    public var id: String { dateString }
    public let dateString: String              // yyyy-MM-dd
    public var displayDate: String             // "Hôm nay", "Hôm qua", "15/09/2026"
    public var totalDistanceKm: Float
    public var totalDrivingMinutes: Int64
    public var totalParkingMinutes: Int64
    public var events: [TimelineEvent]

    public var totalDrivingFormatted: String {
        let h = totalDrivingMinutes / 60
        let m = totalDrivingMinutes % 60
        if h > 0 { return "\(h)h \(m)p" }
        return "\(m) phút"
    }

    public var totalParkingFormatted: String {
        let h = totalParkingMinutes / 60
        let m = totalParkingMinutes % 60
        if h > 0 { return "\(h)h \(m)p" }
        return "\(m) phút"
    }

    public init(
        dateString: String,
        displayDate: String,
        totalDistanceKm: Float,
        totalDrivingMinutes: Int64,
        totalParkingMinutes: Int64,
        events: [TimelineEvent]
    ) {
        self.dateString = dateString
        self.displayDate = displayDate
        self.totalDistanceKm = totalDistanceKm
        self.totalDrivingMinutes = totalDrivingMinutes
        self.totalParkingMinutes = totalParkingMinutes
        self.events = events
    }
}

/// Tổng hợp chuyến đi theo từng ngày
public struct DayTripSummary: Identifiable, Equatable {
    public var id: String { dateString }
    public let dateString: String
    public let displayDate: String
    public let totalDistanceKm: Float
    public let totalDurationMinutes: Int64
    public let trips: [TripRecord]
}
