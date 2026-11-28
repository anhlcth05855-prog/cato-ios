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
                    Text("Legal Disclaimer")
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
                        // Core Cato motto
                        VStack(alignment: .leading, spacing: 8) {
                            Text("IMPORTANT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 245/255, green: 197/255, blue: 24/255))

                            Text("“This is an estimate, not a measuring instrument. Margin of error increases with distance. A green line is not a license to tailgate.”")
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

                        // Safety principles
                        VStack(alignment: .leading, spacing: 12) {
                            DisclaimerItem(
                                number: "01",
                                title: "Cato is a Vision Assistance Tool",
                                description: "The app estimates distance using a single smartphone camera to assist peripheral awareness. It does not replace the driver's own senses and judgment."
                            )

                            DisclaimerItem(
                                number: "02",
                                title: "Circular 38/2024/TT-BGTVT",
                                description: "Minimum safe distances (35m, 55m, 70m, 100m) apply on dry roads in normal weather and clear visibility. In rain, fog, or slippery conditions, keep a greater following distance."
                            )

                            DisclaimerItem(
                                number: "03",
                                title: "100% On-Device Privacy",
                                description: "All camera frames and GPS coordinates are processed locally on your device. Cato never records video, uploads data, or collects personal information."
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Text("I Understand & Agree")
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
