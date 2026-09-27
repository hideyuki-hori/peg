import CoreLocation

enum AccessState {
    case needsAccess
    case denied
    case granted
}

@MainActor
final class LocationAccess: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onChange: () -> Void = {}

    override init() {
        super.init()
        manager.delegate = self
    }

    var state: AccessState {
        switch manager.authorizationStatus {
        case .notDetermined:
            return .needsAccess
        case .authorizedAlways, .authorizedWhenInUse:
            return .granted
        default:
            return .denied
        }
    }

    func request() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.onChange()
        }
    }
}
