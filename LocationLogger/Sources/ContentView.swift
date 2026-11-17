import CoreLocation
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(LocationTracker.self) private var tracker
    @Environment(\.modelContext) private var context
    @Query(sort: \LocationPoint.timestamp, order: .reverse) private var points: [LocationPoint]
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        tracker.isTracking ? tracker.stop() : tracker.start()
                    } label: {
                        Label(tracker.isTracking ? "Stop tracking" : "Start tracking",
                              systemImage: tracker.isTracking ? "stop.circle.fill" : "location.circle.fill")
                    }
                    LabeledContent("Permission", value: tracker.authorization.label)
                    LabeledContent("Points stored", value: "\(points.count)")
                } footer: {
                    if tracker.authorization == .authorizedWhenInUse {
                        Text("Set location access to “Always” in Settings so logging continues in the background.")
                    }
                }

                Section("Log (local time)") {
                    ForEach(points) { p in
                        NavigationLink {
                            PointMapView(point: p)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.timestamp.formatted(date: .abbreviated, time: .standard))
                                    .font(.headline)
                                Text(String(format: "%.6f, %.6f  ±%.0f m", p.latitude, p.longitude, p.accuracy))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { idx in
                        idx.map { points[$0] }.forEach(context.delete)
                    }
                }
            }
            .navigationTitle("Location Logger")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) { confirmClear = true }
                        .disabled(points.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: CSVExport(points), preview: SharePreview("locations.csv"))
                        .disabled(points.isEmpty)
                }
            }
            .confirmationDialog("Delete all points?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) {
                    try? context.delete(model: LocationPoint.self)
                }
            }
        }
    }
}

/// CSV with timestamps in local time incl. UTC offset, e.g. 2026-11-17T14:03:00+01:00
struct CSVExport: Transferable {
    let csv: String

    init(_ points: [LocationPoint]) {
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = .current
        var csv = "time_local,latitude,longitude,accuracy_m\n"
        for p in points.sorted(by: { $0.timestamp < $1.timestamp }) {
            csv += "\(fmt.string(from: p.timestamp)),\(p.latitude),\(p.longitude),\(p.accuracy)\n"
        }
        self.csv = csv
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("locations.csv")
            try export.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
    }
}

extension CLAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined: "Not asked"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .authorizedAlways: "Always"
        case .authorizedWhenInUse: "While using"
        @unknown default: "Unknown"
        }
    }
}
