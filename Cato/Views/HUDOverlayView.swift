import SwiftUI

/// Giao diện HUD hiển thị thông số lái xe, radar khoảng cách và cảnh báo an toàn
public struct HUDOverlayView: View {

    @ObservedObject var thresholdManager: SafetyThresholdManager
    let assessment: SafetyAssessment
    let vehicles: [DetectedVehicle]
    let currentSpeed: Float
    let isMuted: Bool
    let currentMode: ViewMode

    let onToggleMute: () -> Void
    let onOpenHistory: () -> Void
    let onOpenSettings: () -> Void
    let onSelectMode: (ViewMode) -> Void

    public enum ViewMode: String, CaseIterable {
        case camera = "Camera"
        case schematic = "Sơ đồ"
        case screenOff = "Tắt màn"
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
                HStack(spacing: 12) {
                    // Pill ngưỡng khoảng cách
                    HStack(spacing: 8) {
                        Circle()
                            .fill(assessment.alertLevel.color)
                            .frame(width: 8, height: 8)
                        Text(assessment.thresholdDisplayText)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 10/255, green: 12/255, blue: 16/255).opacity(0.85))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    Spacer()

                    // Pill tốc độ GPS hiện tại
                    HStack(spacing: 4) {
                        Text("\(Int(currentSpeed))")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("km/h")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 10/255, green: 12/255, blue: 16/255).opacity(0.85))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

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
                            Text(String(format: "%.1f", assessment.headwaySeconds))
                                .font(.system(size: 24, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("s")
                                .font(.system(size: 16, weight: .regular, design: .monospaced))
                                .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                        }
                    } else {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Làn trước trống")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 10/255, green: 12/255, blue: 16/255).opacity(0.90))
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(assessment.alertLevel.color.opacity(0.6), lineWidth: 1.5)
                )

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

    private func iconForMode(_ mode: ViewMode) -> String {
        switch mode {
        case .camera: return "camera.fill"
        case .schematic: return "point.3.filled.connected.trianglepath.dotted"
        case .screenOff: return "moon.fill"
        }
    }
}
