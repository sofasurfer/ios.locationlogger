import SwiftData
import SwiftUI

@main
struct LocationLoggerApp: App {
    let container: ModelContainer
    @State private var tracker: LocationTracker
    @State private var tab = CommandLine.arguments.contains("-openMap") ? 1 : 0

    init() {
        let container = try! ModelContainer(for: LocationPoint.self)
        self.container = container
        #if DEBUG
        if CommandLine.arguments.contains("-seedDemoData") { Self.seedDemoData(container.mainContext) }
        #endif
        _tracker = State(initialValue: LocationTracker(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                ContentView()
                    .tabItem { Label("Log", systemImage: "list.bullet") }
                    .tag(0)
                TimelineMapView()
                    .tabItem { Label("Map", systemImage: "map") }
                    .tag(1)
            }
            .environment(tracker)
        }
        .modelContainer(container)
    }

    #if DEBUG
    /// Debug only: replaces the store with a fake day (a walk around Zurich). Launch with `-seedDemoData`.
    private static func seedDemoData(_ context: ModelContext) {
        try? context.delete(model: LocationPoint.self)
        let waypoints = [(47.3769, 8.5417), (47.3717, 8.5389), (47.3667, 8.5450), (47.3660, 8.5500),
                         (47.3700, 8.5480), (47.3745, 8.5440), (47.3769, 8.5417)]
        var t = Calendar.current.startOfDay(for: .now).addingTimeInterval(9 * 3600)
        for (a, b) in zip(waypoints, waypoints.dropFirst()) {
            for i in 0..<8 {
                let f = Double(i) / 8
                context.insert(LocationPoint(timestamp: t,
                                             latitude: a.0 + (b.0 - a.0) * f,
                                             longitude: a.1 + (b.1 - a.1) * f,
                                             accuracy: 5))
                t += 120
            }
        }
        try? context.save()
    }
    #endif
}
