import Foundation
import SwiftData

/// Writes all points as one CSV file (`locations.csv`) into a folder the user picked
/// (e.g. in iCloud Drive), overwriting it at most once per `interval`.
///
/// Uses a security-scoped bookmark instead of an iCloud container, so it also works
/// with a free Apple developer account. The hourly timer fires while the app is alive,
/// which, while tracking, includes the background.
@MainActor
@Observable
final class BackupManager {
    static let interval: TimeInterval = 3600
    static let fileName = "locations.csv"

    private(set) var folderName: String? = UserDefaults.standard.string(forKey: "backupFolderName")
    private(set) var lastBackup: Date? = UserDefaults.standard.object(forKey: "lastBackup") as? Date {
        didSet { UserDefaults.standard.set(lastBackup, forKey: "lastBackup") }
    }
    private(set) var lastError: String?

    private let context: ModelContext
    private var timer: Timer?

    init(context: ModelContext) {
        self.context = context
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.backupIfDue() }
        }
        backupIfDue()
    }

    var isConfigured: Bool { UserDefaults.standard.data(forKey: "backupFolderBookmark") != nil }

    /// Called with the folder URL returned by the folder picker.
    func setFolder(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: "backupFolderBookmark")
            folderName = url.lastPathComponent
            UserDefaults.standard.set(folderName, forKey: "backupFolderName")
            lastError = nil
        } catch {
            lastError = "Could not remember folder: \(error.localizedDescription)"
            return
        }
        backupNow()
    }

    func removeFolder() {
        UserDefaults.standard.removeObject(forKey: "backupFolderBookmark")
        UserDefaults.standard.removeObject(forKey: "backupFolderName")
        folderName = nil
        lastBackup = nil
        lastError = nil
    }

    func backupIfDue() {
        guard isConfigured else { return }
        if let lastBackup, Date.now.timeIntervalSince(lastBackup) < Self.interval { return }
        backupNow()
    }

    func backupNow() {
        guard let data = UserDefaults.standard.data(forKey: "backupFolderBookmark") else { return }
        do {
            var stale = false
            let folder = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
            let accessing = folder.startAccessingSecurityScopedResource()
            defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
            if stale, let fresh = try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: "backupFolderBookmark")
            }

            let points = try context.fetch(FetchDescriptor<LocationPoint>(sortBy: [SortDescriptor(\.timestamp)]))
            let csv = Data(LocationCSV.make(points).utf8)
            let target = folder.appendingPathComponent(Self.fileName)

            // Coordinate with the iCloud Drive file provider while replacing the file.
            var coordError: NSError?
            var writeError: Error?
            NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordError) { url in
                do { try csv.write(to: url, options: .atomic) } catch { writeError = error }
            }
            if let e = coordError ?? writeError { throw e }

            lastBackup = .now
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}

/// CSV with timestamps in local time incl. UTC offset, e.g. 2026-11-17T14:03:00+01:00
enum LocationCSV {
    static func make(_ points: [LocationPoint]) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.timeZone = .current
        var csv = "time_local,latitude,longitude,accuracy_m\n"
        for p in points.sorted(by: { $0.timestamp < $1.timestamp }) {
            csv += "\(fmt.string(from: p.timestamp)),\(p.latitude),\(p.longitude),\(p.accuracy)\n"
        }
        return csv
    }
}
