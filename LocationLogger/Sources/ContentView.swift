import CoreLocation
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(LocationTracker.self) private var tracker
    @Environment(BackupManager.self) private var backup
    @Environment(\.modelContext) private var context
    @Query(sort: \LocationPoint.timestamp, order: .reverse) private var points: [LocationPoint]
    @State private var confirmClear = false
    @State private var pickingFolder = false

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

                Section {
                    if backup.isConfigured {
                        LabeledContent("Folder", value: backup.folderName ?? "–")
                        LabeledContent("Last backup", value: backup.lastBackup?
                            .formatted(date: .abbreviated, time: .shortened) ?? "Never")
                        Button("Back up now") { backup.backupNow() }
                        Button("Change folder…") { pickingFolder = true }
                        Button("Turn off backup", role: .destructive) { backup.removeFolder() }
                    } else {
                        Button {
                            pickingFolder = true
                        } label: {
                            Label("Choose backup folder…", systemImage: "icloud.and.arrow.up")
                        }
                    }
                } header: {
                    Text("Hourly backup")
                } footer: {
                    if let error = backup.lastError {
                        Text("Backup failed: \(error)").foregroundStyle(.red)
                    } else {
                        Text("Saves all points as one file, locations.csv, in the chosen folder (e.g. in iCloud Drive). It is overwritten every hour while the app is running.")
                    }
                }
                .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                    if case .success(let url) = result { backup.setFolder(url) }
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

/// Share-sheet wrapper for the CSV export.
struct CSVExport: Transferable {
    let csv: String

    init(_ points: [LocationPoint]) { csv = LocationCSV.make(points) }

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
