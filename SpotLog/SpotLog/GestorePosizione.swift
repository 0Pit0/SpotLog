import CoreLocation

final class GestorePosizione: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var posizione: CLLocation?
    @Published var autorizzazione: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        autorizzazione = manager.authorizationStatus
    }

    func avvia() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func ferma() {
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let stato = manager.authorizationStatus
        Task { @MainActor in
            self.autorizzazione = stato
            if stato == .authorizedWhenInUse || stato == .authorizedAlways {
                self.manager.startUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let ultima = locations.last else { return }
        Task { @MainActor in
            self.posizione = ultima
        }
    }
}
