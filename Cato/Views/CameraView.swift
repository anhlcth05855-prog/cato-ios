import SwiftUI
import AVFoundation
import UIKit

/// Giao diện hiển thị luồng Camera thời gian thực và Bounding Box các xe nhận diện
public struct CameraView: View {

    let vehicles: [DetectedVehicle]
    let assessment: SafetyAssessment
    var onTouchDistanceSelected: ((Float) -> Void)?
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
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let h = geo.size.height
                        let horizonY = h * 0.35
                        let bottomY = h * 0.85
                        let clampedY = min(max(value.location.y, horizonY), bottomY)
                        let factor = Float((bottomY - clampedY) / (bottomY - horizonY))
                        let dist = 8.0 + (factor * factor * 112.0)
                        onTouchDistanceSelected?(dist)
                    }
            )
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
            guard let previewLayer = context.coordinator.previewLayer else { return }
            previewLayer.frame = uiView.bounds
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                let orientation = uiView.window?.windowScene?.interfaceOrientation ?? .portrait
                switch orientation {
                case .landscapeLeft:
                    connection.videoOrientation = .landscapeLeft
                case .landscapeRight:
                    connection.videoOrientation = .landscapeRight
                case .portraitUpsideDown:
                    connection.videoOrientation = .portraitUpsideDown
                default:
                    connection.videoOrientation = .portrait
                }
            }
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
            GeometryReader { geo in
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
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

/// Vẽ Bounding Box và huy hiệu loại xe / mét / giây lên từng xe
struct VehicleBoundingBoxView: View {
    let vehicle: DetectedVehicle
    let screenSize: CGSize
    let alertColor: Color

    private var vehicleTitle: String {
        switch vehicle.label.lowercased() {
        case "truck": return "TẢI"
        case "bus": return "XE KHÁCH"
        default: return "Ô TÔ"
        }
    }

    var body: some View {
        let box = vehicle.boundingBox
        let rect = CGRect(
            x: box.origin.x * screenSize.width,
            y: box.origin.y * screenSize.height,
            width: box.width * screenSize.width,
            height: box.height * screenSize.height
        )

        let isLead = vehicle.isLeadVehicle
        let strokeColor = isLead ? alertColor : Color.cyan.opacity(0.75)
        let boxW = max(rect.width, 36)
        let boxH = max(rect.height, 36)

        ZStack(alignment: .top) {
            if isLead {
                // Khung ngắm 4 góc ADAS cho xe dẫn đầu
                CornerBracketsShape(cornerLength: min(boxW, boxH) * 0.25)
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                    .frame(width: boxW, height: boxH)
                    .shadow(color: alertColor.opacity(0.45), radius: 8)
                    .position(x: rect.midX, y: rect.midY)
            } else {
                // Khung mảnh cho xe làn bên
                RoundedRectangle(cornerRadius: 6)
                    .stroke(strokeColor, lineWidth: 1.5)
                    .frame(width: boxW, height: boxH)
                    .position(x: rect.midX, y: rect.midY)
            }

            // Thẻ thông tin loại xe + khoảng cách nổi phía trên nóc xe
            if vehicle.distanceMeters > 0 {
                HStack(spacing: 4) {
                    Text(vehicleTitle)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(strokeColor)
                    Text("· \(Int(vehicle.distanceMeters))m")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    if isLead && vehicle.headwaySeconds > 0 {
                        Text("· \(String(format: "%.1f", vehicle.headwaySeconds))s")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 16/255, green: 20/255, blue: 28/255).opacity(0.9))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor, lineWidth: 1))
                .position(x: rect.midX, y: max(rect.minY - 16, 20))
            }
        }
    }
}

/// Hình 4 góc ngắm mục tiêu ADAS
struct CornerBracketsShape: Shape {
    let cornerLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = max(min(cornerLength, min(rect.width, rect.height) * 0.4), 8)

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))

        return path
    }
}
