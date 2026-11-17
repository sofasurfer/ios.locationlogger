import CoreLocation
import Foundation
import SwiftData

/// Keeps location updates running (also in the background) and stores a point
/// at most once per `interval` seconds, and only after moving `minDistance` meters.
@MainActor
@Observable
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    static let interval: TimeInterval = 60
    static let minDistance: CLLocationDistance = 20

    private(set) var isTracking = UserDefaults.standard.bool(forKey: "isTracking") {
        didSet { UserDefaults.standard.set(isTracking, forKey: "isTracking") }
    }
    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var lastSaved: Date?
    private var lastSavedLocation: CLLocation?

    private let manager = CLLocationManager()
    private let context: ModelContext
    private var timer: Timer?

    init(context: ModelContext) {
        self.context = context
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .other
        authorization = manager.authorizationStatus
        lastSavedLocation = Self.latestStoredLocation(in: context)
        if isTracking { start() } // resume after relaunch
    }

    private func log(_ msg: String) { print("[LL] \(msg)") }

    func start() {
        log("start() auth=\(manager.authorizationStatus.rawValue) locationServices=\(CLLocationManager.locationServicesEnabled())")
        isTracking = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return // continues in locationManagerDidChangeAuthorization
        case .authorizedWhenInUse:
            // Ask to upgrade so tracking survives the app being in the background.
            manager.requestAlwaysAuthorization()
        case .denied, .restricted:
            isTracking = false
            return
        default:
            break
        }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()

        // Safety net: if the app gets terminated (e.g. swiped away), iOS relaunches it
        // in the background after a significant move (~500 m). On relaunch, `init`
        // sees `isTracking == true` and resumes per-minute logging. Needs "Always".
        if manager.authorizationStatus == .authorizedAlways,
           CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }

        // Fallback tick: re-check the last known fix in case no new update arrives.
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard let loc = self.manager.location else { return }
                self.saveIfDue(loc, now: .now)
            }
        }
    }

    func stop() {
        isTracking = false
        timer?.invalidate()
        timer = nil
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func saveIfDue(_ location: CLLocation, now: Date) {
        if let lastSaved, now.timeIntervalSince(lastSaved) < Self.interval { return }
        guard location.horizontalAccuracy >= 0 else { return } // invalid fix
        if let last = lastSavedLocation {
            // Also require the move to be larger than the fix's uncertainty,
            // so GPS jitter while standing still doesn't create points.
            let threshold = max(Self.minDistance, location.horizontalAccuracy)
            if location.distance(from: last) < threshold { return }
        }
        let point = LocationPoint(
            timestamp: now,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy
        )
        context.insert(point)
        do { try context.save() } catch { log("save failed: \(error)") }
        log("saved \(location.coordinate.latitude),\(location.coordinate.longitude) ±\(location.horizontalAccuracy)")
        lastSaved = now
        lastSavedLocation = location
    }

    private static func latestStoredLocation(in context: ModelContext) -> CLLocation? {
        var fetch = FetchDescriptor<LocationPoint>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        fetch.fetchLimit = 1
        guard let p = try? context.fetch(fetch).first else { return nil }
        return CLLocation(latitude: p.latitude, longitude: p.longitude)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        MainActor.assumeIsolated { saveIfDue(loc, now: .now) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("[LL] authorization changed: \(status.rawValue)")
        MainActor.assumeIsolated {
            authorization = status
            if isTracking, authorization != .notDetermined { start() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LL] didFailWithError: \(error)")
    }
}
