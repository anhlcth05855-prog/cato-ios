import SwiftUI
import AVFoundation

/// Giao diện hiển thị luồng Camera thời gian thực và Bounding Box các xe nhận diện
public struct CameraView: View {

    let vehicles: [DetectedVehicle]
    let assessment: SafetyAssessment
    @ObservedObject var cameraFeed = CameraFeedManager.shared

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Luồng camera thực tế hoặc Mô phỏng kính lái nếu trên Simulator
                if cameraFeed.isCameraAvailable && cameraFeed.isAuthorized {
                    CameraPreviewRepresentable(session: cameraFeed.captureSession)
                        .ignoresSafeArea()
                } else {
                    // Chế độ mô phỏng hình ảnh kính lái cao tốc
                    SimulatedCameraBackground()
                        .ignoresSafeArea()
                }

                // Vạch hướng dẫn làn đường phối cảnh
                PerspectiveLaneOverlay(size: geo.size)

                // Vẽ Bounding Box và Thẻ khoảng cách lên từng xe
                ForEach(vehicles) { vehicle in
                    VehicleBoundingBoxView(
                        vehicle: vehicle,
                        screenSize: geo.size,
                        alertColor: assessment.alertLevel.color
                    )
                }
            }
        }
    }
}

/// UIViewRepresentable bọc AVCaptureVideoPreviewLayer
struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

/// Nền mô phỏng đường cao tốc khi chạy trên Simulator hoặc chưa cấp quyền camera
struct SimulatedCameraBackground: View {
    var body: some View {
        ZStack {
            // Nền tối và bầu trời hoàng hôn trên cao tốc
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 18/255, green: 24/255, blue: 38/255),
                    Color(red: 30/255, green: 38/255, blue: 50/255),
                    Color(red: 15/255, green: 18/255, blue: 24/255)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            // Mặt đường nhựa cao tốc
            Path { path in
                let w = UIScreen.main.bounds.width
                let h = UIScreen.main.bounds.height
                path.move(to: CGPoint(x: w * 0.38, y: h * 0.40))
                path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.40))
                path.addLine(to: CGPoint(x: w * 0.96, y: h))
                path.addLine(to: CGPoint(x: w * 0.04, y: h))
                path.closeSubpath()
            }
            .fill(Color(red: 20/255, green: 24/255, blue: 32/255))
        }
    }
}

/// Vạch hướng dẫn làn đường phối cảnh
struct PerspectiveLaneOverlay: View {
    let size: CGSize

    var body: some View {
        Path { path in
            let w = size.width
            let h = size.height
            let horizonY = h * 0.42

            // Vạch mép trái làn giữa
            path.move(to: CGPoint(x: w * 0.44, y: horizonY))
            path.addLine(to: CGPoint(x: w * 0.28, y: h))

            // Vạch mép phải làn giữa
            path.move(to: CGPoint(x: w * 0.56, y: horizonY))
            path.addLine(to: CGPoint(x: w * 0.72, y: h))
        }
        .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [16, 16]))
    }
}

/// Vẽ Bounding Box và huy hiệu mét/giây lên từng xe
struct VehicleBoundingBoxView: View {
    let vehicle: DetectedVehicle
    let screenSize: CGSize
    let alertColor: Color

    var body: some View {
        let box = vehicle.boundingBox
        let rect = CGRect(
            x: box.origin.x * screenSize.width,
            y: box.origin.y * screenSize.height,
            width: box.width * screenSize.width,
            height: box.height * screenSize.height
        )

        let isLead = vehicle.isLeadVehicle
        let strokeColor = isLead ? alertColor : Color.white.opacity(0.4)
        let strokeWidth: CGFloat = isLead ? 3.0 : 1.5

        ZStack(alignment: .top) {
            // Khung Bounding Box
            RoundedRectangle(cornerRadius: 8)
                .stroke(strokeColor, lineWidth: strokeWidth)
                .frame(width: max(rect.width, 30), height: max(rect.height, 30))
                .shadow(color: isLead ? alertColor.opacity(0.4) : .clear, radius: 8)
                .position(x: rect.midX, y: rect.midY)

            // Thẻ thông tin khoảng cách nổi phía trên nóc xe
            if vehicle.distanceMeters > 0 {
                HStack(spacing: 4) {
                    Text("\(Int(vehicle.distanceMeters))m")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    if isLead && vehicle.headwaySeconds > 0 {
                        Text("· \(String(format: "%.1f", vehicle.headwaySeconds))s")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 22/255, green: 26/255, blue: 33/255).opacity(0.9))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: 1))
                .position(x: rect.midX, y: max(rect.minY - 16, 20))
            }
        }
    }
}
