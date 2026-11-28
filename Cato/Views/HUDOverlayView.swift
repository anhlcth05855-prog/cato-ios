import SwiftUI

/// Giao diện HUD hiển thị thông số lái xe, radar khoảng cách và cảnh báo an toàn
public struct HUDOverlayView: View {

    @ObservedObject var thresholdManager: SafetyThresholdManager
    let assessment: SafetyAssessment
    let vehicles: [DetectedVehicle]
    let currentSpeed: Float
    let speedLimitKmh: Int?
    let nearbyCameraMeters: Int?
    let isMuted: Bool
    let isSimulatingTouch: Bool
    let currentMode: ViewMode

    let onToggleMute: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onSelectMode: (ViewMode) -> Void
    let onQuickTestDistance: (Float?) -> Void

    public enum ViewMode: String, CaseIterable {
        case camera = "Camera"
        case schematic = "Radar"
        case screenOff = "Screen Off"
    }

    public var body: some View {
        ZStack {
            // Viền nhấp nháy đỏ khi ở trạng thái DANGER (Quá gần)
            if assessment.alertLevel == .danger {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color(red: 1.0, green: 0.23, blue: 0.19), lineWidth: 8)
                    .ignoresSafeArea()
                    .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: assessment.alertLevel)
            }

            VStack {
                // Hàng trên cùng: Pills trạng thái & Nút điều khiển
                HStack(spacing: 8) {
                    // Pill ngưỡng khoảng cách
                    HStack(spacing: 6) {
                        Circle()
                            .fill(assessment.alertLevel.color)
                            .frame(width: 8, height: 8)
                        Text(assessment.thresholdDisplayText)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(red: 10/255, green: 12/255, blue: 16/255).opacity(0.85))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    Spacer(minLength: 4)

                    // Pill tốc độ GPS hiện tại & Biển báo giới hạn tốc độ
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Text("\(Int(currentSpeed))")
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                                .foregroundColor((speedLimitKmh != nil && currentSpeed > Float(speedLimitKmh!)) ? Color(red: 1.0, green: 0.23, blue: 0.19) : .white)
                            Text("km/h")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                        }
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color(red: 10/255, green: 12/255, blue: 16/255).opacity(0.85))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )

                        if let limit = speedLimitKmh {
                            Text("\(limit)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                                .frame(width: 28, height: 28)
                                .background(Color.white)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.red, lineWidth: 3.5))
                        }

                        if let camDist = nearbyCameraMeters {
                            HStack(spacing: 3) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 10))
                                Text("\(camDist)m")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.85))
                            .cornerRadius(12)
                        }
                    }

                    // Nút Lịch sử lộ trình GPS
                    Button(action: onOpenHistory) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(red: 22/255, green: 26/255, blue: 33/255).opacity(0.9))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }

                    // Nút Bật/Tắt âm thanh
                    Button(action: onToggleMute) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isMuted ? .gray : .white)
                            .padding(10)
                            .background(Color(red: 22/255, green: 26/255, blue: 33/255).opacity(0.9))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }

                    // Nút Cài đặt
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color(red: 22/255, green: 26/255, blue: 33/255).opacity(0.9))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Spacer()

                // Khối HUD chính giữa phía dưới màn hình
                HStack(spacing: 16) {
                    if assessment.currentDistanceMeters > 0 {
                        HStack(alignment: .lastTextBaseline, spacing: 6) {
                            Text("\(Int(assessment.currentDistanceMeters))")
                                .font(.system(size: 44, weight: .bold, design: .monospaced))
                                .foregroundColor(assessment.alertLevel.color)
                            Text("m")
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundColor(assessment.alertLevel.color)
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 36)

                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(assessment.headwaySeconds > 0 ? String(format: "%.1f", assessment.headwaySeconds) : "--")
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                .foregroundColor(assessment.headwaySeconds > 0 ? .white : Color(red: 154/255, green: 164/255, blue: 178/255))
                            Text("s")
                                .font(.system(size: 16, weight: .regular, design: .monospaced))
                                .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                        }

                        Text(assessment.alertLevel.titleVi)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(assessment.alertLevel == .safe ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(assessment.alertLevel.color)
                            .cornerRadius(10)
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Scanning lane...")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(red: 10/255, green: 12/255, blue: 16/255).opacity(0.90))
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(assessment.alertLevel.color.opacity(0.6), lineWidth: 1.5)
                )

                // Thanh thử khoảng cách nhanh (28m / 62m / 85m / Live)
                HStack(spacing: 6) {
                    quickTestChip("28m", color: Color(red: 1.0, green: 0.23, blue: 0.19), dist: 28)
                    quickTestChip("62m", color: Color(red: 245/255, green: 197/255, blue: 24/255), dist: 62)
                    quickTestChip("85m", color: Color(red: 46/255, green: 204/255, blue: 113/255), dist: 85)
                    if isSimulatingTouch {
                        Button(action: { onQuickTestDistance(nil) }) {
                            Text("Live AI")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.75))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 6)

                // Thanh chuyển đổi 3 chế độ xem (Camera, Sơ đồ, Tắt màn)
                HStack(spacing: 8) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Button(action: { onSelectMode(mode) }) {
                            HStack(spacing: 6) {
                                Image(systemName: iconForMode(mode))
                                    .font(.system(size: 12))
                                Text(mode.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(currentMode == mode ? .black : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(currentMode == mode ? Color(red: 46/255, green: 204/255, blue: 113/255) : Color(red: 22/255, green: 26/255, blue: 33/255).opacity(0.85))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
        }
    }

    private func quickTestChip(_ label: String, color: Color, dist: Float) -> some View {
        Button(action: { onQuickTestDistance(dist) }) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(color.opacity(0.28))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.85), lineWidth: 1))
        }
    }

    private func iconForMode(_ mode: ViewMode) -> String {
        switch mode {
        case .camera: return "camera.fill"
        case .schematic: return "point.3.filled.connected.trianglepath.dotted"
        case .screenOff: return "moon.fill"
        }
    }
}
