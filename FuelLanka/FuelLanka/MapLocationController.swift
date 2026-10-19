import CoreLocation
import Observation

@MainActor
@Observable
final class MapLocationController: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var requestedLocation = false
    var coordinate: CLLocationCoordinate2D?
    var locationRevision = 0
    var message: String?
    var isLocating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func locate() {
        message = nil
        requestedLocation = true
        isLocating = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
            requestedLocation = false
            message = "Location access is unavailable. You can still browse Sri Lanka or use list search."
        @unknown default:
            isLocating = false
            requestedLocation = false
            message = "Your location is unavailable. Use list search instead."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard requestedLocation, manager.authorizationStatus != .notDetermined else { return }
        locate()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false
        requestedLocation = false
        guard let location = locations.last,
              location.horizontalAccuracy >= 0,
              CLLocationCoordinate2DIsValid(location.coordinate) else {
            message = "Your location could not be determined. Use list search instead."
            return
        }
        coordinate = location.coordinate
        locationRevision += 1
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        requestedLocation = false
        message = "Your location could not be determined. You can still browse the map or use list search."
    }
}
