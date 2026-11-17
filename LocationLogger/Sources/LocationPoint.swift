import Foundation
import SwiftData

@Model
final class LocationPoint {
    /// Absolute moment of the fix. Displayed/exported in the device's local time zone.
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    /// Horizontal accuracy in meters (lower is better).
    var accuracy: Double

    init(timestamp: Date, latitude: Double, longitude: Double, accuracy: Double) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
    }
}
