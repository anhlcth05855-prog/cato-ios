import Foundation
import CoreLocation
import QuartzCore

/// Quản lý vị trí GPS và tính toán tốc độ di chuyển thực tế từ chip định vị vệ tinh của iPhone
public class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    public static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentSpeedKmh: Float = 0
    @Published public var lastLocation: CLLocation?
    @Published public var currentRoadName: String = "Locating..."
    @Published public var isDemoMode: Bool = false
    @Published public var simulatedSpeedKmh: Float = 82.0 // Mặc định ví dụ Cato trên cao tốc (82 km/h)

    public var onLocationUpdated: ((CLLocation, Float, String) -> Void)?

    private var previousLocation: CLLocation?
    private var smoothedSpeedKmh: Float = 0
    private var lastGeocodingTime: TimeInterval = 0

    override public init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 3.0 // Cập nhật mỗi khi di chuyển 3 mét
        locationManager.allowsBackgroundLocationUpdates = false
    }

    public func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    public func start() {
        if isDemoMode {
            currentSpeedKmh = simulatedSpeedKmh
            return
        }

        currentSpeedKmh = 0
        smoothedSpeedKmh = 0
        locationManager.startUpdatingLocation()
    }

    public func stop() {
        locationManager.stopUpdatingLocation()
    }

    public func setDemoMode(enabled: Bool) {
        isDemoMode = enabled
        if enabled {
            stop()
            currentSpeedKmh = simulatedSpeedKmh
            let demoLocation = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 20.978, longitude: 105.748),
                altitude: 15,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: Date()
            )
            lastLocation = demoLocation
            currentRoadName = "Hanoi – Hai Phong Expressway (Demo)"
            onLocationUpdated?(demoLocation, simulatedSpeedKmh, currentRoadName)
        } else {
            start()
            currentSpeedKmh = 0
        }
    }

    public func setSimulatedSpeed(_ speed: Float) {
        simulatedSpeedKmh = speed
        if isDemoMode {
            currentSpeedKmh = speed
            if let loc = lastLocation {
                onLocationUpdated?(loc, speed, currentRoadName)
            }
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                self.start()
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !isDemoMode else { return }

        lastLocation = location

        var calculatedSpeedMps: Double = 0
        if location.speed >= 0 {
            calculatedSpeedMps = location.speed
        } else if let prev = previousLocation {
            let dt = location.timestamp.timeIntervalSince(prev.timestamp)
            if dt > 0.3 && dt < 10.0 {
                let dist = location.distance(from: prev)
                if dist >= 2.0 {
                    calculatedSpeedMps = dist / dt
                }
            }
        }
        previousLocation = location

        let rawSpeedKmh = Float(calculatedSpeedMps * 3.6)

        // Ngưỡng đứng yên: nếu dưới 2.5 km/h coi như xe đang dừng đỗ
        if rawSpeedKmh < 2.5 {
            smoothedSpeedKmh = 0
        } else {
            // Bộ lọc làm mượt EMA (70% giá trị mới, 30% giá trị cũ) chống giật số
            smoothedSpeedKmh = (smoothedSpeedKmh == 0) ? rawSpeedKmh : (0.70 * rawSpeedKmh + 0.30 * smoothedSpeedKmh)
        }

        currentSpeedKmh = smoothedSpeedKmh

        // Tra cứu tên đường định kỳ (khoảng cách tối thiểu 30s giữa các lần geocode)
        let now = CACurrentMediaTime()
        if now - lastGeocodingTime > 30.0 {
            lastGeocodingTime = now
            reverseGeocode(location: location)
        }

        onLocationUpdated?(location, currentSpeedKmh, currentRoadName)
    }

    private func reverseGeocode(location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, error == nil, let placemark = placemarks?.first else { return }

            let road = placemark.thoroughfare ?? placemark.name ?? placemark.subLocality ?? "Current Road"
            let locality = placemark.subAdministrativeArea ?? placemark.locality ?? ""
            let displayName = locality.isEmpty ? road : "\(road), \(locality)"

            DispatchQueue.main.async {
                self.currentRoadName = displayName
            }
        }
    }
}

/// Dữ liệu giới hạn tốc độ & camera phạt nguội Offline cho các tuyến đường huyết mạch Việt Nam
public class RoadSpeedLimitManager: ObservableObject {

    public static let shared = RoadSpeedLimitManager()

    @Published public var currentSpeedLimitKmh: Int? = nil
    @Published public var nearbySpeedCameraDistanceMeters: Int? = nil

    private struct SpeedZone {
        let name: String
        let lat: Double
        let lng: Double
        let radiusMeters: Double
        let limitKmh: Int
    }

    private struct SpeedCamera {
        let name: String
        let lat: Double
        let lng: Double
    }

    private let zones: [SpeedZone] = [
        SpeedZone(name: "Cao tốc Long Thành – Dầu Giây", lat: 10.812, lng: 106.885, radiusMeters: 18000, limitKmh: 120),
        SpeedZone(name: "Cao tốc Hà Nội – Hải Phòng", lat: 20.950, lng: 106.150, radiusMeters: 45000, limitKmh: 120),
        SpeedZone(name: "Cao tốc Pháp Vân – Cầu Giẽ", lat: 20.895, lng: 105.875, radiusMeters: 22000, limitKmh: 100),
        SpeedZone(name: "Cao tốc Phan Thiết – Dầu Giây", lat: 10.910, lng: 107.650, radiusMeters: 40000, limitKmh: 120),
        SpeedZone(name: "Vành đai 3 trên cao Hà Nội", lat: 20.985, lng: 105.805, radiusMeters: 12000, limitKmh: 80),
        SpeedZone(name: "Đại lộ Võ Văn Kiệt TP.HCM", lat: 10.748, lng: 106.668, radiusMeters: 10000, limitKmh: 60)
    ]

    private let cameras: [SpeedCamera] = [
        SpeedCamera(name: "Camera Cao tốc HN-HP Km12", lat: 20.978, lng: 105.751),
        SpeedCamera(name: "Camera Cao tốc LT-DG", lat: 10.808, lng: 106.862),
        SpeedCamera(name: "Camera Pháp Vân", lat: 20.922, lng: 105.852)
    ]

    public init() {}

    public func update(location: CLLocation, speedKmh: Float, isDemoMode: Bool) {
        if isDemoMode {
            currentSpeedLimitKmh = 120
            nearbySpeedCameraDistanceMeters = nil
            return
        }

        // Chỉ kích hoạt biển báo cao tốc khi đang chạy trên 50 km/h để tránh báo nhầm 120 km/h trong phố
        var matchedLimit: Int? = nil
        if speedKmh > 50 {
            for zone in zones {
                let zoneLoc = CLLocation(latitude: zone.lat, longitude: zone.lng)
                if location.distance(from: zoneLoc) <= zone.radiusMeters {
                    matchedLimit = zone.limitKmh
                    break
                }
            }
        }

        var nearestCamDist: Int? = nil
        for cam in cameras {
            let camLoc = CLLocation(latitude: cam.lat, longitude: cam.lng)
            let dist = Int(location.distance(from: camLoc))
            if dist <= 500 {
                if nearestCamDist == nil || dist < nearestCamDist! {
                    nearestCamDist = dist
                }
            }
        }

        DispatchQueue.main.async {
            self.currentSpeedLimitKmh = matchedLimit
            self.nearbySpeedCameraDistanceMeters = nearestCamDist
        }
    }
}
