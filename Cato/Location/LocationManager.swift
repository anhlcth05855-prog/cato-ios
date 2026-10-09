import Foundation
import CoreLocation

/// Quản lý vị trí GPS và tính toán tốc độ di chuyển thực tế từ chip định vị vệ tinh của iPhone
public class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    public static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var currentSpeedKmh: Float = 0
    @Published public var lastLocation: CLLocation?
    @Published public var currentRoadName: String = "Đang xác định vị trí"
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
            currentRoadName = "Cao tốc Hà Nội – Hải Phòng (Demo)"
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

            let road = placemark.thoroughfare ?? placemark.name ?? placemark.subLocality ?? "Đường đang chạy"
            let locality = placemark.subAdministrativeArea ?? placemark.locality ?? ""
            let displayName = locality.isEmpty ? road : "\(road), \(locality)"

            DispatchQueue.main.async {
                self.currentRoadName = displayName
            }
        }
    }
}
