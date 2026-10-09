import SwiftUI

/// Chế độ Sơ đồ (Schematic Radar HUD View)
/// Biểu diễn làn đường, xe ta, xe dẫn đầu và xe làn bên cạnh dưới dạng vector trên nền đen OLED (#0A0C10)
/// Giúp người lái liếc nhìn nhanh ngoại vi, chống chói nắng ban ngày và giảm lóa kính lái ban đêm
public struct SchematicView: View {

    let vehicles: [DetectedVehicle]
    let assessment: SafetyAssessment
    var onTouchDistanceSelected: ((Float) -> Void)?

    @State private var dashPhase: CGFloat = 0

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let horizonY = h * 0.22
            let bottomY = h * 0.94

            ZStack {
                // 1. Nền đen sâu OLED chống lóa
                Color(red: 10/255, green: 12/255, blue: 16/255)
                    .ignoresSafeArea()

                // 2. Mặt đường nhựa phối cảnh 3 làn
                Path { path in
                    let roadTopLeft = w * 0.35
                    let roadTopRight = w * 0.65
                    let roadBottomLeft = w * 0.05
                    let roadBottomRight = w * 0.95

                    path.move(to: CGPoint(x: roadTopLeft, y: horizonY))
                    path.addLine(to: CGPoint(x: roadTopRight, y: horizonY))
                    path.addLine(to: CGPoint(x: roadBottomRight, y: bottomY))
                    path.addLine(to: CGPoint(x: roadBottomLeft, y: bottomY))
                    path.closeSubpath()
                }
                .fill(Color(red: 20/255, green: 24/255, blue: 32/255))

                // Viền mép đường hai bên
                Path { path in
                    let roadTopLeft = w * 0.35
                    let roadTopRight = w * 0.65
                    let roadBottomLeft = w * 0.05
                    let roadBottomRight = w * 0.95

                    path.move(to: CGPoint(x: roadTopLeft, y: horizonY))
                    path.addLine(to: CGPoint(x: roadBottomLeft, y: bottomY))

                    path.move(to: CGPoint(x: roadTopRight, y: horizonY))
                    path.addLine(to: CGPoint(x: roadBottomRight, y: bottomY))
                }
                .stroke(Color(red: 75/255, green: 85/255, blue: 101/255), lineWidth: 4)

                // Vạch kẻ chia làn đường (Animated dashes)
                Path { path in
                    let roadTopLeft = w * 0.35
                    let roadTopRight = w * 0.65
                    let roadBottomLeft = w * 0.05
                    let roadBottomRight = w * 0.95

                    // Vạch phân làn giữa và làn trái
                    let l1Top = roadTopLeft + (roadTopRight - roadTopLeft) * 0.33
                    let l1Bot = roadBottomLeft + (roadBottomRight - roadBottomLeft) * 0.33
                    path.move(to: CGPoint(x: l1Top, y: horizonY))
                    path.addLine(to: CGPoint(x: l1Bot, y: bottomY))

                    // Vạch phân làn giữa và làn phải
                    let l2Top = roadTopLeft + (roadTopRight - roadTopLeft) * 0.66
                    let l2Bot = roadBottomLeft + (roadBottomRight - roadBottomLeft) * 0.66
                    path.move(to: CGPoint(x: l2Top, y: horizonY))
                    path.addLine(to: CGPoint(x: l2Bot, y: bottomY))
                }
                .stroke(
                    Color(red: 58/255, green: 68/255, blue: 84/255),
                    style: StrokeStyle(lineWidth: 3, dash: [20, 20], dashPhase: dashPhase)
                )

                // 3. Vạch ngưỡng luật quy định (Threshold Line)
                let thresholdM = assessment.requiredThresholdMeters
                let thresholdY = mapDistanceToY(dist: thresholdM, horizonY: horizonY, bottomY: bottomY)

                Path { path in
                    path.move(to: CGPoint(x: w * 0.16, y: thresholdY))
                    path.addLine(to: CGPoint(x: w * 0.84, y: thresholdY))
                }
                .stroke(
                    assessment.alertLevel.color.opacity(0.45),
                    style: StrokeStyle(lineWidth: 2, dash: [10, 10])
                )

                Text(assessment.speedKmh <= 60 ? "Chủ động giữ KC" : "Ngưỡng luật: \(Int(thresholdM))m")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(assessment.alertLevel.color.opacity(0.8))
                    .position(x: w * 0.80, y: thresholdY - 12)

                // 4. Xe của mình (Ego Car) ở đáy làn giữa
                let egoW: CGFloat = 52
                let egoH: CGFloat = 80
                let egoY = bottomY - egoH / 2 - 8
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 224/255, green: 230/255, blue: 237/255))
                        .frame(width: egoW, height: egoH)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    Text("XE BẠN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                }
                .position(x: w * 0.50, y: egoY)

                // 5. Các xe làn bên cạnh
                ForEach(vehicles.filter { !$0.isLeadVehicle }) { v in
                    let sideY = mapDistanceToY(dist: v.distanceMeters, horizonY: horizonY, bottomY: bottomY)
                    let sideX = (v.lanePosition == .leftLane) ? w * 0.23 : w * 0.77

                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 74/255, green: 85/255, blue: 104/255))
                            .frame(width: 44, height: 68)

                        if v.distanceMeters > 0 {
                            Text("\(Int(v.distanceMeters))m")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    .position(x: sideX, y: sideY)
                }

                // 6. Xe dẫn đầu cùng làn (Lead Vehicle)
                if let lead = vehicles.first(where: { $0.isLeadVehicle }) {
                    let leadY = mapDistanceToY(dist: lead.distanceMeters, horizonY: horizonY, bottomY: bottomY)
                    let leadW: CGFloat = 64
                    let leadH: CGFloat = 94

                    VStack(spacing: 4) {
                        // Thẻ mét và giây nổi phía trên nóc xe
                        HStack(spacing: 4) {
                            Text("\(Int(lead.distanceMeters))m")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            Text("· \(String(format: "%.1f", lead.headwaySeconds))s")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 30/255, green: 36/255, blue: 46/255))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(assessment.alertLevel.color, lineWidth: 1))

                        // Thân xe dẫn đầu
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(assessment.alertLevel.color.opacity(0.2))
                                .frame(width: leadW + 16, height: leadH + 16)
                                .blur(radius: 6)

                            RoundedRectangle(cornerRadius: 14)
                                .fill(assessment.alertLevel.color)
                                .frame(width: leadW, height: leadH)
                        }
                    }
                    .position(x: w * 0.50, y: leadY)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedY = min(max(value.location.y, horizonY), bottomY)
                        let factor = Float((bottomY - clampedY) / (bottomY - horizonY))
                        let dist = 8.0 + (factor * factor * 112.0)
                        onTouchDistanceSelected?(dist)
                    }
            )
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                dashPhase = 40
            }
        }
    }

    private func mapDistanceToY(dist: Float, horizonY: CGFloat, bottomY: CGFloat) -> CGFloat {
        let clamped = min(max(dist, 5.0), 130.0)
        let factor = 1.0 - CGFloat(clamped / 130.0)
        return horizonY + (bottomY - horizonY) * (factor * factor)
    }
}
