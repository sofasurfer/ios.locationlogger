# Location Logger

A small iOS app that logs your GPS position in the background and keeps the data on the device. It shows the points as a list and as a day timeline on a map.

<img src="design/AppIcon.svg" width="120" alt="App icon">

## Features

- **Background logging.** Records latitude, longitude, time and GPS accuracy. It keeps running when the app is in the background or the phone is locked.
- **Saves only when you move.** A point is stored at most once a minute, and only after you've moved at least 20 m from the last stored point. If the GPS reading is less precise than 20 m, you have to move further than that uncertainty, so GPS drift while standing still doesn't create points.
- **Restarts itself.** If the app is quit, iOS can relaunch it after a larger move (about 500 m) using significant-location-change monitoring, and logging continues.
- **Log list.** All points, newest first, shown in local time. Tap an entry to see it on a map. Swipe to delete one, or use **Clear** to delete all.
- **Timeline map.** Choose a day to see its route. Drag the slider or press **Play** to move a marker through the points in time order.
- **CSV export.** Share all points as `locations.csv`:
  ```
  time_local,latitude,longitude,accuracy_m
  2026-11-17T14:49:32+01:00,47.3769,8.5417,5.0
  ```
- **Hourly backup.** Choose a folder once, for example in iCloud Drive. The app then overwrites a single `locations.csv` there every hour while it's running (which includes the background while tracking). Use **Back up now** to save immediately. This works with a free Apple developer account because it doesn't use an iCloud container.
- **Private.** No account, no server and no analytics. Data stays on the device unless you export it.

## Requirements

- Xcode 16 or later
- iPhone with iOS 17 or later
- An Apple ID or Apple Developer account for signing

## Getting started

1. Clone the repo and open `LocationLogger.xcodeproj`.
2. In the target's **Signing & Capabilities**, select your team. If your team can't use the bundle ID `ch.sofasurfer.LocationLogger`, change it.
3. Connect your iPhone. Turn on **Developer Mode** (*Settings → Privacy & Security → Developer Mode*) and trust the Mac when asked.
4. Select the iPhone as the run destination and press **Run**.
5. In the app, tap **Start tracking** and allow location access **Always**. With "While Using" access, logging stops when the app goes to the background.

If launching the app says "Untrusted Developer", trust the developer under *Settings → General → VPN & Device Management*.

## How tracking works

`LocationTracker` runs continuous location updates (`CLLocationManager`) with background updates enabled. The `location` background mode is set in `Info.plist`. Every update, plus a 5-second fallback timer, checks whether a point is due:

1. at least 60 s since the last saved point, and
2. at least `max(20 m, current accuracy)` away from the last saved point.

The tracking state is saved in `UserDefaults`. When the app launches, tracking resumes automatically.

### Limitations

- If you swipe the app away in the app switcher, continuous updates stop. Logging resumes once iOS relaunches the app after a significant move, or when you open it again.
- After a phone restart, iOS may require the phone to be unlocked once before the app can be relaunched.
- GPS running all the time uses noticeable battery.
- With a free Apple developer account, the app's signing expires after 7 days. After that it won't launch, and won't log, until you run it from Xcode again.
- On the timeline, the slider moves from point to point, not by clock time. A long stay at one place is a single point.

## Storage

Points are stored with SwiftData (SQLite), at roughly 50 bytes per point. Even if you moved all day, every day (one point per minute), a full year would be about 25–30 MB. With the 20 m rule it is usually much less.

## Project structure

```
LocationLogger/
├── Info.plist                  # Background mode + location permission texts
└── Sources/
    ├── LocationLoggerApp.swift # App entry, SwiftData container, tabs (+ debug demo data)
    ├── LocationPoint.swift     # SwiftData model: timestamp, latitude, longitude, accuracy
    ├── LocationTracker.swift   # CoreLocation logic: permissions, background updates, save rules
    ├── ContentView.swift       # Log tab: start/stop, list, delete, CSV export
    ├── BackupManager.swift     # Hourly CSV backup to a user-picked folder + CSV builder
    ├── PointMapView.swift      # Map for a single log entry
    ├── TimelineMapView.swift   # Map tab: day route with time slider and playback
    └── Assets.xcassets/        # App icon
design/
├── AppIcon.svg                 # Vector source of the app icon
└── make_icon.swift             # Generates AppIcon.png and AppIcon.svg
```

## Development

**Demo data (debug builds only).** These launch arguments can be set in the scheme or passed with `simctl launch`:

| Argument | Effect |
|---|---|
| `-seedDemoData` | **Deletes all stored points** and inserts a fake walk around Zurich for today |
| `-openMap` | Opens the app on the Map tab |

**Regenerate the app icon** after changing colours or shapes in `design/make_icon.swift`:

```sh
cd design
swift make_icon.swift ../LocationLogger/Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png AppIcon.svg
```
