import MapKit
import SwiftData
import SwiftUI

extension LocationPoint {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

/// Shows one day's route; a slider (or Play) moves a marker through the points in time order.
struct TimelineMapView: View {
    @Query(sort: \LocationPoint.timestamp) private var points: [LocationPoint]
    @State private var day = Date.now
    @State private var position: Double = 0
    @State private var isPlaying = false
    @State private var camera: MapCameraPosition = .automatic

    private var dayPoints: [LocationPoint] {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return points.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    var body: some View {
        let pts = dayPoints
        let idx = pts.isEmpty ? 0 : min(max(Int(position.rounded()), 0), pts.count - 1)
        let coords = pts.map(\.coordinate)

        NavigationStack {
            Map(position: $camera) {
                if coords.count > 1 {
                    MapPolyline(coordinates: coords)
                        .stroke(.gray.opacity(0.6), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                if idx > 0 {
                    MapPolyline(coordinates: Array(coords[...idx]))
                        .stroke(.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                }
                if !pts.isEmpty {
                    Marker(pts[idx].timestamp.formatted(date: .omitted, time: .shortened),
                           systemImage: "location.fill", coordinate: coords[idx])
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .overlay {
                if pts.isEmpty {
                    ContentUnavailableView("No points", systemImage: "map",
                                           description: Text("Nothing logged on this day."))
                }
            }
            .safeAreaInset(edge: .top) {
                DatePicker("Day", selection: $day, in: ...Date.now, displayedComponents: .date)
                    .padding(12)
                    .background(.regularMaterial, in: .rect(cornerRadius: 16))
                    .padding(.horizontal)
            }
            .safeAreaInset(edge: .bottom) {
                if pts.count > 1 { timeSlider(pts, idx: idx) }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { position = Double(max(pts.count - 1, 0)) }
            .onChange(of: day) {
                isPlaying = false
                position = Double(max(dayPoints.count - 1, 0))
                camera = .automatic
            }
            .task(id: isPlaying) { await play() }
        }
    }

    private func timeSlider(_ pts: [LocationPoint], idx: Int) -> some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                VStack(alignment: .leading) {
                    Text(pts[idx].timestamp.formatted(date: .omitted, time: .standard))
                        .font(.title2.monospacedDigit().bold())
                    Text("Point \(idx + 1) of \(pts.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Slider(value: $position, in: 0...Double(pts.count - 1), step: 1) {
                Text("Time")
            } minimumValueLabel: {
                Text(pts.first!.timestamp.formatted(date: .omitted, time: .shortened)).font(.caption)
            } maximumValueLabel: {
                Text(pts.last!.timestamp.formatted(date: .omitted, time: .shortened)).font(.caption)
            } onEditingChanged: { editing in
                if editing { isPlaying = false }
            }
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .padding()
    }

    /// Steps through the day's points while `isPlaying` is on.
    private func play() async {
        guard isPlaying else { return }
        if Int(position) >= dayPoints.count - 1 { position = 0 } // restart from the beginning
        while isPlaying, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
            guard isPlaying, !Task.isCancelled else { return }
            if Int(position) >= dayPoints.count - 1 { isPlaying = false; return }
            position += 1
        }
    }
}
