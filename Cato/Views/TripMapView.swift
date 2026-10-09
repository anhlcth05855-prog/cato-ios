import SwiftUI
import MapKit
import UIKit

/// Bản đồ Apple Maps hiển thị lộ trình và lịch sử đường đi vẽ bằng GPS Polyline
public struct TripMapView: View {

    let trip: TripRecord
    @Environment(\.presentationMode) var presentationMode

    public init(trip: TripRecord) {
        self.trip = trip
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Bản đồ Apple Maps vẽ đường đi GPS
            MapRouteRepresentable(trip: trip)
                .ignoresSafeArea()

            // Thanh tiêu đề phía trên
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                        Text("Quay lại")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 22/255, green: 26/255, blue: 33/255).opacity(0.85))
                    .cornerRadius(20)
                }

                Spacer()

                Text(trip.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(red: 22/255, green: 26/255, blue: 33/255).opacity(0.85))
                    .cornerRadius(20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Thẻ tóm tắt thông số chuyến đi ở phía dưới
            VStack {
                Spacer()

                VStack(spacing: 12) {
                    // Hàng thống kê: Quãng đường, Thời gian, Tốc độ tối đa, Tốc độ trung bình
                    HStack(spacing: 16) {
                        StatItem(title: "QUÃNG ĐƯỜNG", value: trip.distanceKmString, color: Color(red: 46/255, green: 204/255, blue: 113/255))
                        StatItem(title: "THỜI GIAN", value: trip.durationFormatted, color: .white)
                        StatItem(title: "TỐC ĐỘ MAX", value: "\(Int(trip.maxSpeedKmh)) km/h", color: Color(red: 245/255, green: 197/255, blue: 24/255))
                        StatItem(title: "TB", value: "\(Int(trip.avgSpeedKmh)) km/h", color: Color(red: 154/255, green: 164/255, blue: 178/255))
                    }

                    Divider()
                        .background(Color.white.opacity(0.15))

                    // Điểm xuất phát và Điểm đến
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text(trip.startAddress)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }

                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text(trip.endAddress)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(16)
                .background(Color(red: 16/255, green: 20/255, blue: 28/255).opacity(0.95))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 154/255, green: 164/255, blue: 178/255))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

/// MKMapView UIViewRepresentable vẽ Polyline và Marker hành trình trên Apple Maps
struct MapRouteRepresentable: UIViewRepresentable {
    let trip: TripRecord

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.showsCompass = true
        mapView.showsScale = true
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        guard !trip.points.isEmpty else { return }

        let coordinates = trip.points.map { $0.coordinate }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)

        // Điểm bắt đầu
        if let first = trip.points.first {
            let startPin = MKPointAnnotation()
            startPin.coordinate = first.coordinate
            startPin.title = "Khởi hành"
            startPin.subtitle = trip.startAddress
            mapView.addAnnotation(startPin)
        }

        // Điểm kết thúc
        if let last = trip.points.last {
            let endPin = MKPointAnnotation()
            endPin.coordinate = last.coordinate
            endPin.title = "Điểm đến"
            endPin.subtitle = trip.endAddress
            mapView.addAnnotation(endPin)
        }

        // Zoom fit toàn bộ lộ trình
        let rect = polyline.boundingMapRect
        mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 180, right: 40), animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 0.95)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "TripPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }

            if annotation.title == "Khởi hành" {
                view?.markerTintColor = UIColor(red: 46/255, green: 204/255, blue: 113/255, alpha: 1.0)
                view?.glyphImage = UIImage(systemName: "flag.fill")
            } else {
                view?.markerTintColor = UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1.0)
                view?.glyphImage = UIImage(systemName: "mappin.and.ellipse")
            }

            return view
        }
    }
}
