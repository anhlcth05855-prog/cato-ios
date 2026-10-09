import Foundation
import CoreLocation

/// Quản lý lưu vết lịch sử hành trình GPS và dòng thời gian Điểm đỗ xe / Di chuyển (Timeline Tracker)
public class TripHistoryManager: ObservableObject {

    public static let shared = TripHistoryManager()

    private let tripsFileName = "cato_trips_history.json"
    private let timelineFileName = "cato_timeline_history.json"

    @Published public var trips: [TripRecord] = []
    @Published public var timelineDays: [TimelineDay] = []

    // Chuyến đi đang được ghi nhận thời gian thực
    private var currentTripPoints: [GpsPoint] = []
    private var currentTripStartTime: Int64 = 0
    private var currentTripRoadName: String = "Hành trình hiện tại"
    private var currentTripDistanceMeters: Float = 0
    private var currentTripMaxSpeed: Float = 0

    // Theo dõi trạng thái dừng đỗ thời gian thực
    private var isCurrentlyStopped: Bool = false
    private var currentStopStartTime: Int64 = 0
    private var currentStopLocationName: String = ""
    private var currentStopLat: Double = 0
    private var currentStopLng: Double = 0

    public init() {
        loadTripsFromStorage()
        if trips.isEmpty {
            generateSampleTrips()
            saveTripsToStorage()
        }
        generateSampleTimeline()
    }

    private var storageDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ??
        FileManager.default.temporaryDirectory
    }

    /// Bắt đầu ghi một chuyến đi mới
    public func startNewTrip(initialRoadName: String = "Hành trình di chuyển") {
        currentTripPoints.removeAll()
        currentTripStartTime = Int64(Date().timeIntervalSince1970 * 1000)
        currentTripRoadName = initialRoadName
        currentTripDistanceMeters = 0
        currentTripMaxSpeed = 0
    }

    /// Ghi nhận một tọa độ GPS mới vào chuyến đi hiện tại và phát hiện dừng đỗ
    public func recordPoint(lat: Double, lng: Double, speedKmh: Float, roadName: String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // 1. Logic phát hiện Dừng đỗ vs Di chuyển (Stop Detection)
        if speedKmh <= 2.5 {
            if !isCurrentlyStopped {
                isCurrentlyStopped = true
                currentStopStartTime = now
                currentStopLocationName = roadName.isEmpty ? "Vị trí dừng đỗ" : roadName
                currentStopLat = lat
                currentStopLng = lng
            }
        } else {
            // Xe bắt đầu lăn bánh trở lại
            if isCurrentlyStopped {
                let stopDurationMins = (now - currentStopStartTime) / 60000
                if stopDurationMins >= 5 { // Dừng trên 5 phút được tính là 1 điểm đỗ
                    addStopEventToToday(
                        location: currentStopLocationName,
                        start: currentStopStartTime,
                        end: now,
                        lat: currentStopLat,
                        lng: currentStopLng
                    )
                }
                isCurrentlyStopped = false
                currentStopStartTime = 0
            }
        }

        // 2. Logic ghi nhận tọa độ lộ trình di chuyển
        if currentTripStartTime == 0 {
            startNewTrip(initialRoadName: roadName)
        }

        if let lastPoint = currentTripPoints.last {
            let dist = calculateDistanceMeters(lat1: lastPoint.latitude, lon1: lastPoint.longitude, lat2: lat, lon2: lng)
            if dist < 4.0 && (now - lastPoint.timestamp < 10000) {
                return
            }
            currentTripDistanceMeters += dist
        }

        currentTripMaxSpeed = max(currentTripMaxSpeed, speedKmh)
        if (currentTripRoadName.isEmpty || currentTripRoadName == "Hành trình hiện tại" || currentTripRoadName == "Hành trình di chuyển") && !roadName.isEmpty {
            currentTripRoadName = roadName
        }

        let newPoint = GpsPoint(
            latitude: lat,
            longitude: lng,
            speedKmh: speedKmh,
            timestamp: now,
            roadName: roadName
        )
        currentTripPoints.append(newPoint)
    }

    /// Kết thúc và lưu chuyến đi hiện tại
    @discardableResult
    public func finishCurrentTrip() -> TripRecord? {
        guard currentTripPoints.count >= 2 else {
            currentTripPoints.removeAll()
            currentTripStartTime = 0
            return nil
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date(timeIntervalSince1970: Double(currentTripStartTime) / 1000.0))

        let totalSpeed = currentTripPoints.reduce(0.0) { $0 + Float($1.speedKmh) }
        let avgSpeed = currentTripPoints.isEmpty ? 0 : totalSpeed / Float(currentTripPoints.count)

        let startAddr = currentTripPoints.first?.roadName.isEmpty == false ? currentTripPoints.first!.roadName : "Điểm khởi hành"
        let endAddr = currentTripPoints.last?.roadName.isEmpty == false ? currentTripPoints.last!.roadName : "Điểm đến"

        let newTrip = TripRecord(
            id: "TRIP_\(now)",
            title: currentTripRoadName,
            dateString: dateStr,
            startTime: currentTripStartTime,
            endTime: now,
            totalDistanceMeters: currentTripDistanceMeters,
            maxSpeedKmh: currentTripMaxSpeed,
            avgSpeedKmh: avgSpeed,
            startAddress: startAddr,
            endAddress: endAddr,
            points: currentTripPoints
        )

        trips.insert(newTrip, at: 0)
        saveTripsToStorage()
        addDrivingEventToToday(trip: newTrip)

        currentTripPoints.removeAll()
        currentTripStartTime = 0
        currentTripDistanceMeters = 0
        currentTripMaxSpeed = 0

        return newTrip
    }

    private func addDrivingEventToToday(trip: TripRecord) {
        let dateStr = trip.dateString
        let drivingEvent = TimelineEvent(
            id: "DRIVE_\(Date().timeIntervalSince1970)",
            type: .driving,
            locationName: "\(trip.startAddress) → \(trip.endAddress)",
            startTime: trip.startTime,
            endTime: trip.endTime,
            durationMinutes: trip.durationMinutes,
            distanceKm: trip.totalDistanceMeters / 1000.0,
            maxSpeedKmh: trip.maxSpeedKmh,
            avgSpeedKmh: trip.avgSpeedKmh,
            latitude: trip.points.first?.latitude ?? 0,
            longitude: trip.points.first?.longitude ?? 0,
            endLatitude: trip.points.last?.latitude ?? 0,
            endLongitude: trip.points.last?.longitude ?? 0,
            startAddress: trip.startAddress,
            endAddress: trip.endAddress,
            points: trip.points
        )

        if let index = timelineDays.firstIndex(where: { $0.dateString == dateStr }) {
            var day = timelineDays[index]
            day.events.append(drivingEvent)
            day.totalDistanceKm += trip.totalDistanceMeters / 1000.0
            day.totalDrivingMinutes += trip.durationMinutes
            timelineDays[index] = day
        } else {
            let newDay = TimelineDay(
                dateString: dateStr,
                displayDate: "Hôm nay (\(dateStr))",
                totalDistanceKm: trip.totalDistanceMeters / 1000.0,
                totalDrivingMinutes: trip.durationMinutes,
                totalParkingMinutes: 0,
                events: [drivingEvent]
            )
            timelineDays.insert(newDay, at: 0)
        }
    }

    private func addStopEventToToday(location: String, start: Int64, end: Int64, lat: Double, lng: Double) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date(timeIntervalSince1970: Double(start) / 1000.0))
        let duration = max(1, (end - start) / 60000)

        let stopEvent = TimelineEvent(
            id: "STOP_\(Date().timeIntervalSince1970)",
            type: .stop,
            locationName: location,
            startTime: start,
            endTime: end,
            durationMinutes: duration,
            latitude: lat,
            longitude: lng
        )

        if let index = timelineDays.firstIndex(where: { $0.dateString == todayStr }) {
            var day = timelineDays[index]
            day.events.append(stopEvent)
            day.totalParkingMinutes += duration
            timelineDays[index] = day
        } else {
            let newDay = TimelineDay(
                dateString: todayStr,
                displayDate: "Hôm nay (\(todayStr))",
                totalDistanceKm: 0,
                totalDrivingMinutes: 0,
                totalParkingMinutes: duration,
                events: [stopEvent]
            )
            timelineDays.insert(newDay, at: 0)
        }
    }

    /// Gom nhóm các chuyến đi theo từng ngày
    public func getGroupedByDate(filter: String = "ALL") -> [DayTripSummary] {
        let filteredTrips = getTripsByFilter(filter: filter)
        let grouped = Dictionary(grouping: filteredTrips, by: { $0.dateString })

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        let yesterdayStr = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())

        var summaries: [DayTripSummary] = []
        for (dateStr, dayTrips) in grouped {
            let displayDate: String
            if dateStr == todayStr {
                displayDate = "Hôm nay (\(dateStr))"
            } else if dateStr == yesterdayStr {
                displayDate = "Hôm qua (\(dateStr))"
            } else {
                displayDate = "Ngày \(dateStr)"
            }

            let totalDistM = dayTrips.reduce(0.0) { $0 + $1.totalDistanceMeters }
            let totalMins = dayTrips.reduce(0) { $0 + $1.durationMinutes }

            summaries.append(
                DayTripSummary(
                    dateString: dateStr,
                    displayDate: displayDate,
                    totalDistanceKm: totalDistM / 1000.0,
                    totalDurationMinutes: totalMins,
                    trips: dayTrips.sorted(by: { $0.startTime > $1.startTime })
                )
            )
        }

        return summaries.sorted(by: { $0.dateString > $1.dateString })
    }

    /// Lọc chuyến đi theo mốc thời gian
    public func getTripsByFilter(filter: String) -> [TripRecord] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        let yesterdayStr = formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        let weekAgoTime = Int64((Calendar.current.date(byAdding: .day, value: -7, to: Date())?.timeIntervalSince1970 ?? 0) * 1000)

        switch filter {
        case "TODAY":
            return trips.filter { $0.dateString == todayStr }
        case "YESTERDAY":
            return trips.filter { $0.dateString == yesterdayStr }
        case "WEEK":
            return trips.filter { $0.startTime >= weekAgoTime }
        default:
            return trips
        }
    }

    private func loadTripsFromStorage() {
        let fileURL = storageDirectory.appendingPathComponent(tripsFileName)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let loaded = try? JSONDecoder().decode([TripRecord].self, from: data) else {
            return
        }
        self.trips = loaded
    }

    public func saveTripsToStorage() {
        let fileURL = storageDirectory.appendingPathComponent(tripsFileName)
        guard let data = try? JSONEncoder().encode(trips) else { return }
        try? data.write(to: fileURL)
    }

    /// Khởi tạo các chuyến đi mẫu sống động phục vụ kiểm thử
    private func generateSampleTrips() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let todayStr = formatter.string(from: today)

        // 1. Chuyến đi Hôm nay: Cao tốc Long Thành - Dầu Giây
        let trip1StartTime = Int64((today.timeIntervalSince1970 - 7200) * 1000)
        let trip1EndTime = trip1StartTime + 2520000 // 42 phút
        let pointsTrip1 = generatePolylinePoints(
            startLat: 10.795, startLng: 106.745,
            endLat: 10.940, endLng: 107.185,
            count: 30,
            avgSpeed: 102.0, maxSpeed: 118.0,
            roadName: "Cao tốc Long Thành - Dầu Giây",
            startTime: trip1StartTime, endTime: trip1EndTime
        )

        let trip1 = TripRecord(
            id: "TRIP_SAMPLE_001",
            title: "Cao tốc TP.HCM – Dầu Giây",
            dateString: todayStr,
            startTime: trip1StartTime,
            endTime: trip1EndTime,
            totalDistanceMeters: 54200,
            maxSpeedKmh: 118.0,
            avgSpeedKmh: 102.0,
            startAddress: "Nút giao An Phú, TP. Thủ Đức",
            endAddress: "Nút giao Dầu Giây, Đồng Nai",
            points: pointsTrip1
        )

        // 2. Chuyến đi Hôm nay: Đại lộ Võ Văn Kiệt
        let trip2StartTime = Int64((today.timeIntervalSince1970 - 18000) * 1000)
        let trip2EndTime = trip2StartTime + 1500000 // 25 phút
        let pointsTrip2 = generatePolylinePoints(
            startLat: 10.725, startLng: 106.605,
            endLat: 10.772, endLng: 106.705,
            count: 22,
            avgSpeed: 51.0, maxSpeed: 62.0,
            roadName: "Đại lộ Võ Văn Kiệt",
            startTime: trip2StartTime, endTime: trip2EndTime
        )

        let trip2 = TripRecord(
            id: "TRIP_SAMPLE_002",
            title: "Đại lộ Võ Văn Kiệt – Hầm Thủ Thiêm",
            dateString: todayStr,
            startTime: trip2StartTime,
            endTime: trip2EndTime,
            totalDistanceMeters: 13800,
            maxSpeedKmh: 62.0,
            avgSpeedKmh: 51.0,
            startAddress: "Cầu Lò Gốm, Quận 6",
            endAddress: "Hầm Thủ Thiêm, Quận 1",
            points: pointsTrip2
        )

        // 3. Chuyến đi Hôm qua: Vũng Tàu - TP.HCM
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return }
        let yestStr = formatter.string(from: yesterday)
        let trip3StartTime = Int64((yesterday.timeIntervalSince1970 - 14400) * 1000)
        let trip3EndTime = trip3StartTime + 4800000 // 80 phút
        let pointsTrip3 = generatePolylinePoints(
            startLat: 10.355, startLng: 107.085,
            endLat: 10.795, endLng: 106.745,
            count: 35,
            avgSpeed: 72.0, maxSpeed: 95.0,
            roadName: "Quốc lộ 51",
            startTime: trip3StartTime, endTime: trip3EndTime
        )

        let trip3 = TripRecord(
            id: "TRIP_SAMPLE_003",
            title: "Vũng Tàu – TP. Hồ Chí Minh",
            dateString: yestStr,
            startTime: trip3StartTime,
            endTime: trip3EndTime,
            totalDistanceMeters: 88000,
            maxSpeedKmh: 95.0,
            avgSpeedKmh: 72.0,
            startAddress: "Bãi Trước, TP. Vũng Tàu",
            endAddress: "Nút giao An Phú, TP. Thủ Đức",
            points: pointsTrip3
        )

        self.trips = [trip1, trip2, trip3]
    }

    /// Khởi tạo dòng thời gian mẫu với kịch bản các điểm dừng và chặng đi
    private func generateSampleTimeline() {
        timelineDays.removeAll()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        let todayStr = formatter.string(from: today)

        var calendar = Calendar.current
        calendar.timeZone = .current
        var comps = calendar.dateComponents([.year, .month, .day], from: today)
        comps.hour = 7
        comps.minute = 0
        let baseTime = calendar.date(from: comps) ?? today

        let stop1Start = Int64(baseTime.timeIntervalSince1970 * 1000)
        let stop1End = stop1Start + 4 * 3600000 // 11:00 (đỗ 4 tiếng)

        let drive1Start = stop1End
        let drive1End = drive1Start + 3 * 3600000 // 14:00 (chạy 3 tiếng)
        let drive1Points = generatePolylinePoints(
            startLat: 20.978, startLng: 105.748,
            endLat: 20.865, endLng: 106.685,
            count: 40,
            avgSpeed: 68.0, maxSpeed: 115.0,
            roadName: "Đường Louis VII → Hải Phòng",
            startTime: drive1Start, endTime: drive1End
        )

        let stop2Start = drive1End
        let stop2End = stop2Start + 2 * 3600000 // 16:00 (đỗ 2 tiếng)

        let drive2Start = stop2End
        let drive2End = drive2Start + 5400000 // 17:30 (chạy 1.5 tiếng)
        let drive2Points = generatePolylinePoints(
            startLat: 20.865, startLng: 106.685,
            endLat: 20.978, endLng: 105.748,
            count: 30,
            avgSpeed: 58.0, maxSpeed: 90.0,
            roadName: "Hải Phòng → Hà Nội",
            startTime: drive2Start, endTime: drive2End
        )

        let events: [TimelineEvent] = [
            TimelineEvent(
                id: "EVT_1",
                type: .stop,
                locationName: "Đường Louis VII, KĐT Louis City, Nam Từ Liêm, Hà Nội",
                startTime: stop1Start,
                endTime: stop1End,
                durationMinutes: 240,
                latitude: 20.978,
                longitude: 105.748,
                startAddress: "Số 25 Đường Louis VII, Hà Nội",
                endAddress: "Số 25 Đường Louis VII, Hà Nội"
            ),
            TimelineEvent(
                id: "EVT_2",
                type: .driving,
                locationName: "Đường Louis VII → Phố Hoàng Diệu, Hải Phòng",
                startTime: drive1Start,
                endTime: drive1End,
                durationMinutes: 180,
                distanceKm: 112.5,
                maxSpeedKmh: 115.0,
                avgSpeedKmh: 68.0,
                latitude: 20.978,
                longitude: 105.748,
                endLatitude: 20.865,
                endLongitude: 106.685,
                startAddress: "Số 25 Đường Louis VII, Hà Nội",
                endAddress: "Phố Hoàng Diệu, Hồng Bàng, Hải Phòng",
                points: drive1Points
            ),
            TimelineEvent(
                id: "EVT_3",
                type: .stop,
                locationName: "Phố Hoàng Diệu, Phường Minh Khai, Hồng Bàng, Hải Phòng",
                startTime: stop2Start,
                endTime: stop2End,
                durationMinutes: 120,
                latitude: 20.865,
                longitude: 106.685,
                startAddress: "Phố Hoàng Diệu, Hải Phòng",
                endAddress: "Phố Hoàng Diệu, Hải Phòng"
            ),
            TimelineEvent(
                id: "EVT_4",
                type: .driving,
                locationName: "Hải Phòng → Đường Louis VII, Hà Nội",
                startTime: drive2Start,
                endTime: drive2End,
                durationMinutes: 90,
                distanceKm: 64.0,
                maxSpeedKmh: 90.0,
                avgSpeedKmh: 58.0,
                latitude: 20.865,
                longitude: 106.685,
                endLatitude: 20.978,
                endLongitude: 105.748,
                startAddress: "Phố Hoàng Diệu, Hải Phòng",
                endAddress: "Số 25 Đường Louis VII, Hà Nội",
                points: drive2Points
            )
        ]

        let todayTimeline = TimelineDay(
            dateString: todayStr,
            displayDate: "Hôm nay (\(todayStr))",
            totalDistanceKm: 176.5,
            totalDrivingMinutes: 270,
            totalParkingMinutes: 360,
            events: events
        )

        timelineDays = [todayTimeline]
    }

    private func generatePolylinePoints(
        startLat: Double, startLng: Double,
        endLat: Double, endLng: Double,
        count: Int,
        avgSpeed: Float, maxSpeed: Float,
        roadName: String,
        startTime: Int64, endTime: Int64
    ) -> [GpsPoint] {
        var list: [GpsPoint] = []
        let timeStep = (endTime - startTime) / Int64(count)

        for i in 0...count {
            let ratio = Double(i) / Double(count)
            let curve = sin(ratio * .pi) * 0.015
            let lat = startLat + (endLat - startLat) * ratio + curve * 0.4
            let lng = startLng + (endLng - startLng) * ratio + curve

            let speed: Float
            if i == 0 || i == count {
                speed = 0
            } else if i == count / 2 {
                speed = maxSpeed
            } else {
                speed = max(0, avgSpeed + Float(sin(ratio * 10) * 8.0))
            }

            list.append(
                GpsPoint(
                    latitude: lat,
                    longitude: lng,
                    speedKmh: speed,
                    timestamp: startTime + Int64(i) * timeStep,
                    roadName: roadName
                )
            )
        }
        return list
    }

    private func calculateDistanceMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Float {
        let r = 6371000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) *
                sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return Float(r * c)
    }
}
