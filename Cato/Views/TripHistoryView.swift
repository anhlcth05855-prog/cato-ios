import SwiftUI

/// Màn hình Lịch sử hành trình GPS và Dòng thời gian Điểm đỗ xe / Di chuyển
/// Liệt kê các điểm đã đi theo ngày và xem vẽ bản đồ Apple Maps đường đi
public struct TripHistoryView: View {

    @ObservedObject var historyManager = TripHistoryManager.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedTab: HistoryTab = .trips
    @State private var selectedFilter: String = "ALL"
    @State private var selectedTripForMap: TripRecord?

    public enum HistoryTab: String, CaseIterable {
        case trips = "Chuyến đi"
        case timeline = "Dòng thời gian"
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 10/255, green: 12/255, blue: 16/255)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Thanh điều khiển Tab & Bộ lọc ngày
                    VStack(spacing: 12) {
                        Picker("Tab", selection: $selectedTab) {
                            ForEach(HistoryTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 16)

                        // Bộ lọc ngày: Tất cả, Hôm nay, Hôm qua, 7 ngày
                        HStack(spacing: 8) {
                            FilterChip(title: "Tất cả", isSelected: selectedFilter == "ALL") { selectedFilter = "ALL" }
                            FilterChip(title: "Hôm nay", isSelected: selectedFilter == "TODAY") { selectedFilter = "TODAY" }
                            FilterChip(title: "Hôm qua", isSelected: selectedFilter == "YESTERDAY") { selectedFilter = "YESTERDAY" }
                            FilterChip(title: "7 ngày qua", isSelected: selectedFilter == "WEEK") { selectedFilter = "WEEK" }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 12)
                    .background(Color(red: 16/255, green: 20/255, blue: 28/255))

                    // Nội dung danh sách theo Tab
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if selectedTab == .trips {
                                tripsContent
                            } else {
                                timelineContent
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Lịch sử hành trình")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .sheet(item: $selectedTripForMap) { trip in
                TripMapView(trip: trip)
            }
        }
    }

    // MARK: - Chuyến đi Tab
    private var tripsContent: some View {
        let grouped = historyManager.getGroupedByDate(filter: selectedFilter)

        return Group {
            if grouped.isEmpty {
                EmptyHistoryStateView()
            } else {
                ForEach(grouped) { summary in
                    VStack(alignment: .leading, spacing: 10) {
                        // Header ngày
                        HStack {
                            Text(summary.displayDate)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f km · %d chuyến", summary.totalDistanceKm, summary.trips.count))
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                        }
                        .padding(.horizontal, 16)

                        // Các chuyến đi trong ngày
                        ForEach(summary.trips) { trip in
                            TripCardView(trip: trip) {
                                selectedTripForMap = trip
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Dòng thời gian Tab
    private var timelineContent: some View {
        let days = historyManager.timelineDays

        return Group {
            if days.isEmpty {
                EmptyHistoryStateView()
            } else {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 12) {
                        // Thống kê ngày
                        VStack(alignment: .leading, spacing: 6) {
                            Text(day.displayDate)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)

                            HStack(spacing: 16) {
                                Label(day.totalDrivingFormatted, systemImage: "car.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))

                                Label(day.totalParkingFormatted, systemImage: "parkingsign.circle.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(red: 245/255, green: 197/255, blue: 24/255))

                                Label(String(format: "%.1f km", day.totalDistanceKm), systemImage: "arrow.triangle.swap")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Các sự kiện Dừng đỗ vs Di chuyển
                        ForEach(day.events) { event in
                            TimelineEventCardView(event: event) {
                                if event.type == .driving && !event.points.isEmpty {
                                    let trip = TripRecord(
                                        id: event.id,
                                        title: event.locationName,
                                        dateString: day.dateString,
                                        startTime: event.startTime,
                                        endTime: event.endTime,
                                        totalDistanceMeters: event.distanceKm * 1000,
                                        maxSpeedKmh: event.maxSpeedKmh,
                                        avgSpeedKmh: event.avgSpeedKmh,
                                        startAddress: event.startAddress,
                                        endAddress: event.endAddress,
                                        points: event.points
                                    )
                                    selectedTripForMap = trip
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
    }
}

/// Thẻ một chuyến đi
struct TripCardView: View {
    let trip: TripRecord
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(trip.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(trip.timeRangeString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 11))
                        Text(trip.distanceKmString)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(trip.durationFormatted)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 11))
                        Text("\(Int(trip.maxSpeedKmh)) km/h")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(Color(red: 245/255, green: 197/255, blue: 24/255))

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Bản đồ")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white.opacity(0.8))
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text(trip.startAddress)
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                            .lineLimit(1)
                    }
                    HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text(trip.endAddress)
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
            .background(Color(red: 20/255, green: 24/255, blue: 33/255))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
}

/// Thẻ sự kiện dòng thời gian (Điểm dừng đỗ xe hoặc Chặng di chuyển)
struct TimelineEventCardView: View {
    let event: TimelineEvent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Icon loại sự kiện
                ZStack {
                    Circle()
                        .fill(event.type == .stop ? Color(red: 245/255, green: 197/255, blue: 24/255).opacity(0.2) : Color(red: 46/255, green: 204/255, blue: 113/255).opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: event.type.iconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(event.type == .stop ? Color(red: 245/255, green: 197/255, blue: 24/255) : Color(red: 46/255, green: 204/255, blue: 113/255))
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(event.type.titleVi)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(event.type == .stop ? Color(red: 245/255, green: 197/255, blue: 24/255) : Color(red: 46/255, green: 204/255, blue: 113/255))

                        Spacer()

                        Text(event.timeRangeString)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    Text(event.locationName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Text("Thời gian: \(event.durationFormatted)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))

                        if event.type == .driving && event.distanceKm > 0 {
                            Text(String(format: "· %.1f km", event.distanceKm))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                        }

                        if event.type == .driving && !event.points.isEmpty {
                            Spacer()
                            Text("Xem bản đồ >")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(red: 20/255, green: 24/255, blue: 33/255))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color(red: 46/255, green: 204/255, blue: 113/255) : Color(red: 26/255, green: 32/255, blue: 44/255))
                .cornerRadius(12)
        }
    }
}

struct EmptyHistoryStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Chưa có lộ trình nào được ghi nhận")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Text("Khi bạn lái xe, Cato sẽ tự động ghi vết GPS và vẽ bản đồ lộ trình tại đây.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
    }
}
