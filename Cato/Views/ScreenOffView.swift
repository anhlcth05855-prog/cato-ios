import SwiftUI

/// Chế độ Tắt màn hình (Chỉ âm thanh / Audio-Only Mode)
/// Màn hình đen OLED tiết kiệm pin và chống nóng máy tối đa khi điện thoại đặt trên taplo dưới trời nắng gắt.
/// Hệ thống nhận diện camera và âm thanh cảnh báo ADAS vẫn hoạt động bình thường, chạm 2 lần để bật sáng lại.
public struct ScreenOffView: View {

    let assessment: SafetyAssessment
    let onWakeUp: () -> Void

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Đèn chấm nhỏ tinh tế hiển thị trạng thái an toàn
                Circle()
                    .fill(assessment.alertLevel.color.opacity(0.3))
                    .frame(width: 10, height: 10)

                Text("Chế độ chỉ âm thanh đang bật")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.2))

                Text("Chạm 2 lần vào màn hình để bật sáng")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.15))
            }
        }
        .onTapGesture(count: 2) {
            onWakeUp()
        }
    }
}
