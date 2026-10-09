import SwiftUI

/// Hộp thoại Tuyên bố từ chối trách nhiệm & Hướng dẫn an toàn
public struct DisclaimerView: View {

    @Environment(\.presentationMode) var presentationMode

    public var body: some View {
        ZStack {
            Color(red: 10/255, green: 12/255, blue: 16/255)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Tuyên bố trách nhiệm")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Câu châm ngôn cốt lõi của Cato
                        VStack(alignment: .leading, spacing: 8) {
                            Text("QUAN TRỌNG")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 245/255, green: 197/255, blue: 24/255))

                            Text("“Đây là ước lượng, không phải thiết bị đo. Sai số tăng theo khoảng cách. Vạch xanh không phải giấy phép bám đuôi nhé.”")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .italic()
                        }
                        .padding(16)
                        .background(Color(red: 245/255, green: 197/255, blue: 24/255).opacity(0.12))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 245/255, green: 197/255, blue: 24/255).opacity(0.35), lineWidth: 1)
                        )

                        // Các nguyên tắc an toàn
                        VStack(alignment: .leading, spacing: 12) {
                            DisclaimerItem(
                                number: "01",
                                title: "Cato là trợ lý hỗ trợ tầm nhìn",
                                description: "Ứng dụng ước tính khoảng cách bằng camera đơn của điện thoại nhằm hỗ trợ tầm nhìn ngoại vi. Ứng dụng không thay thế giác quan và phán đoán trực tiếp của người điều khiển phương tiện."
                            )

                            DisclaimerItem(
                                number: "02",
                                title: "Thông tư 38/2024/TT-BGTVT",
                                description: "Khoảng cách an toàn tối thiểu (35m, 55m, 70m, 100m) áp dụng trong điều kiện mặt đường khô ráo, thời tiết bình thường và tầm nhìn thông thoáng. Khi trời mưa, sương mù hoặc đường trơn trượt, người lái phải chủ động giữ khoảng cách xa hơn."
                            )

                            DisclaimerItem(
                                number: "03",
                                title: "Quyền riêng tư tuyệt đối (100% Offline)",
                                description: "Toàn bộ hình ảnh từ camera và tọa độ vị trí được xử lý trực tiếp trên thiết bị của bạn. Cato không lưu video, không gửi dữ liệu ra máy chủ và không thu thập thông tin cá nhân."
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("Tôi đã hiểu và đồng ý")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 46/255, green: 204/255, blue: 113/255))
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

struct DisclaimerItem: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 46/255, green: 204/255, blue: 113/255))
                .padding(6)
                .background(Color(red: 46/255, green: 204/255, blue: 113/255).opacity(0.15))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
                    .lineSpacing(3)
            }
        }
        .padding(.vertical, 6)
    }
}
