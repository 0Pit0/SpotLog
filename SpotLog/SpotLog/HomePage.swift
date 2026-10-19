import SwiftUI
import MapKit
import CoreLocation
import Combine

struct Pagina: View {
    @State private var searchText: String = ""

    var body: some View {
        
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("cerca nei tuoi posti", text: $searchText)
                Button(action: {
                    print("Hamburger")
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
            }
            .padding(5)
            .background(.white)
            .cornerRadius(10)
            .padding(5)
            
            HStack{
                Button("Explore"){
                    
                }
            }
            UserLocationMap()
        }.background(Color.gray)
    }
}

#Preview {
    HomePage()
}

struct HomePage: View {
    var body: some View {
        TabView {
            Pagina()
                .tabItem { Label("Home", systemImage: "person.fill") }
            CreazioneSpot()
                .tabItem {
                    Image(systemName: "plus")
                }
            Preferiti()
                .tabItem { Label("Preferiti", systemImage: "star.fill") }
        }
    }
}


final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = manager.authorizationStatus
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
        }
        print("Autorizzazione", manager.authorizationStatus.rawValue)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}

struct UserLocationMap: View {
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onAppear { locationManager.start() }
        .onChange(of: locationManager.lastLocation) { _, newValue in
            guard let coordinate = newValue?.coordinate else { return }
            position = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            )
        }
    }
}
