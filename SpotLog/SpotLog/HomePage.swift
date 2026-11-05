import SwiftUI
import MapKit
import CoreLocation
import Combine

struct Pagina: View {
    @State private var searchText: String = ""
    
    @State private var filtri: [String] = [
        "Esplora", "Ristorante", "Panorama", "Ricordo", "Museo"
    ]

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
            
            
            ScrollView(.horizontal) {
                HStack{
                    ForEach(filtri, id: \.self) { filtro in
                        ButtonTipologie(text: filtro) {
                            print("Hai premuto \(filtro)")
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(5)
            }
            
            UserLocationMap()
        }.background(Color.gray)
    }
}

#Preview {
    HomePage()
}

struct ButtonTipologie: View {
    var text: String!
    var action: () -> Void = { }
    
    var body: some View {
        Button(action: action){
            Text(text)
            
        }.padding(7)
            .background(Color.white).cornerRadius(16)
    }
}

struct HomePage: View {
    var body: some View {
        TabView {
            Pagina()
                .tabItem { Label("Home", systemImage: "person.fill") }
            CreazioneSpot()
                .tabItem {
                    Label("Creazione Spot", systemImage: "plus")
                }
            Preferiti()
                .tabItem {
                    Label("Spots", systemImage: "mappin") }
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
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error)
    }
}

struct FavoritePlaces: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var icon: String
    var descrizione: String
    var latitude: Double
    var longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
extension FavoritePlaces {
    func distanzaFormattata(da posizione: CLLocation) -> String {
        let destinazione = CLLocation(latitude: latitude, longitude: longitude)
        let metri = posizione.distance(from: destinazione)

        if metri < 1000 {
            return "\(Int(metri)) m"
        }
        let km = Measurement(value: metri / 1000, unit: UnitLength.kilometers)
        return km.formatted(.measurement(width: .abbreviated,
                                         usage: .asProvided,
                                         numberFormatStyle: .number.precision(.fractionLength(1))))
    }
}

struct UserLocationMap: View {
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic

    @State private var favoritePlaces: FavoritePlaces?

    @State private var places: [FavoritePlaces] = [
        FavoritePlaces(name: "Duomo di Milano", icon: "star.fill", descrizione: "Bel posto molto antico e pieno di cose fantastiche e di fregna", latitude: 45.4642, longitude: 9.1900),
        FavoritePlaces(name: "Colosseo", icon: "house.fill", descrizione: "Bel posto molto antico e pieno di cose fantastiche e di fregna", latitude: 41.8902, longitude: 12.4922)
    ]

    var body: some View {
        Map(position: $position, selection: $favoritePlaces) {
            UserAnnotation()

            ForEach(places) { place in
                Marker(place.name, systemImage: place.icon, coordinate: place.coordinate)
                    .tint(.orange)
                    .tag(place)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .sheet(item: $favoritePlaces) { place in
            Dettaglio(place: place)
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

struct DettaglioPosto: View {
    let place: FavoritePlaces
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Nome") {
                    Text(place.name)
                        .font(.headline)
                }

                Section("Posizione") {
                    Text("Latitudine: \(place.latitude)")
                    Text("Longitudine: \(place.longitude)")
                }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
}
