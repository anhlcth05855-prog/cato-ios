import SwiftUI

/// Màn hình Cài đặt thông số xe, camera và ngưỡng cảnh báo
public struct SettingsView: View {

    @ObservedObject var distanceEstimator: DistanceEstimator
    @ObservedObject var thresholdManager: SafetyThresholdManager
    @ObservedObject var soundManager = AlertSoundManager.shared
    @ObservedObject var locationManager = LocationManager.shared

    @Environment(\.presentationMode) var presentationMode
    @State private var showingDisclaimer = false

    public init(
        distanceEstimator: DistanceEstimator,
        thresholdManager: SafetyThresholdManager
    ) {
        self.distanceEstimator = distanceEstimator
        self.thresholdManager = thresholdManager
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 10/255, green: 12/255, blue: 16/255)
                    .ignoresSafeArea()

                Form {
                    // PHẦN 1: THIẾT LẬP CAMERA GẮN KÍNH
                    Section(header: Text("VỊ TRÍ CAMERA").foregroundColor(.gray)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Chiều cao gắn camera")
                                    .foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%.2f mét", distanceEstimator.cameraHeightMeters))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                            }

                            Slider(
                                value: $distanceEstimator.cameraHeightMeters,
                                in: 1.00...2.00,
                                step: 0.05
                            )
                            .accentColor(Color(red: 46/255, green: 204/255, blue: 113/255))

                            Text("Xe sedan / hatchback ~1.25m; Crossover / SUV ~1.40m")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // PHẦN 2: NGƯỠNG CẢNH BÁO AN TOÀN (THÔNG TƯ 38/2024)
                    Section(header: Text("CẢNH BÁO SỚM HƠN NGƯỠNG LUẬT").foregroundColor(.gray)) {
                        Picker("Khoảng cách cộng thêm", selection: $thresholdManager.thresholdBufferMeters) {
                            Text("+0 m (Đúng luật)").tag(Float(0.0))
                            Text("+5 m (Khuyên dùng)").tag(Float(5.0))
                            Text("+10 m (An toàn cao)").tag(Float(10.0))
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // PHẦN 3: ÂM THANH CẢNH BÁO ADAS
                    Section(header: Text("ÂM THANH CẢNH BÁO").foregroundColor(.gray)) {
                        Toggle("Tắt chuông cảnh báo", isOn: $soundManager.isMuted)
                            .foregroundColor(.white)

                        if !soundManager.isMuted {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Âm lượng")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(soundManager.volumePercent)%")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.gray)
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(soundManager.volumePercent) },
                                        set: { soundManager.volumePercent = Int($0) }
                                    ),
                                    in: 10...100,
                                    step: 5
                                )
                                .accentColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // PHẦN 4: CHẾ ĐỘ MÔ PHỎNG / KIỂM THỬ (DEMO MODE)
                    Section(header: Text("MÔ PHỎNG / KIỂM THỬ").foregroundColor(.gray)) {
                        Toggle("Bật chế độ lái xe mô phỏng", isOn: Binding(
                            get: { locationManager.isDemoMode },
                            set: { locationManager.setDemoMode(enabled: $0) }
                        ))
                        .foregroundColor(.white)

                        if locationManager.isDemoMode {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Tốc độ xe mô phỏng")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(locationManager.simulatedSpeedKmh)) km/h")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(Color(red: 245/255, green: 197/255, blue: 24/255))
                                }
                                Slider(
                                    value: Binding(
                                        get: { Double(locationManager.simulatedSpeedKmh) },
                                        set: { locationManager.setSimulatedSpeed(Float($0)) }
                                    ),
                                    in: 20...120,
                                    step: 5
                                )
                                .accentColor(Color(red: 245/255, green: 197/255, blue: 24/255))

                                Text("Hỗ trợ kiểm thử trọn vẹn các trạng thái cảnh báo ngay trong nhà / phòng làm việc.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))

                    // PHẦN 5: THÔNG TIN & PHÁP LÝ
                    Section(header: Text("THÔNG TIN").foregroundColor(.gray)) {
                        Button(action: { showingDisclaimer = true }) {
                            HStack {
                                Text("Tuyên bố trách nhiệm pháp lý")
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }

                        HStack {
                            Text("Quy chuẩn khoảng cách")
                                .foregroundColor(.white)
                            Spacer()
                            Text("Thông tư 38/2024")
                                .foregroundColor(.gray)
                        }

                        HStack {
                            Text("Bảo mật dữ liệu")
                                .foregroundColor(.white)
                            Spacer()
                            Text("100% On-Device Offline")
                                .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                        }

                        HStack {
                            Text("Phiên bản")
                                .foregroundColor(.white)
                            Spacer()
                            Text("1.0.0 (Build 1)")
                                .foregroundColor(.gray)
                        }
                    }
                    .listRowBackground(Color(red: 20/255, green: 24/255, blue: 33/255))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                }
            }
            .sheet(isPresented: $showingDisclaimer) {
                DisclaimerView()
            }
        }
    }
}
