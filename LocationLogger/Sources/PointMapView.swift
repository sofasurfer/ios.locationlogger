import MapKit
import SwiftUI

/// Shows a single log entry on the map, with its accuracy radius.
struct PointMapView: View {
    let point: LocationPoint
    @State private var camera: MapCameraPosition

    init(point: LocationPoint) {
        self.point = point
        let center = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        _camera = State(initialValue: .camera(MapCamera(centerCoordinate: center, distance: 1500)))
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    var body: some View {
        Map(position: $camera) {
            MapCircle(center: coordinate, radius: max(point.accuracy, 5))
                .foregroundStyle(.blue.opacity(0.15))
                .stroke(.blue.opacity(0.5), lineWidth: 1)
            Marker(point.timestamp.formatted(date: .omitted, time: .shortened), coordinate: coordinate)
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(point.timestamp.formatted(date: .complete, time: .standard))
                    .font(.headline)
                Text(String(format: "%.6f, %.6f  ±%.0f m", point.latitude, point.longitude, point.accuracy))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: .rect(cornerRadius: 16))
            .padding()
        }
        .navigationTitle("Entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}
