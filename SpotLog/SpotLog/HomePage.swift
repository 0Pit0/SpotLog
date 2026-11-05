import SwiftUI
import MapKit
import CoreLocation
import Combine

enum StileMappa: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case ibrida = "Ibrida"
    case satellite = "Satellite"
    
    var id: String { rawValue }
    
    var mapStyle: MapStyle {
        switch self {
        case .standard: return .standard
        case .ibrida: return .hybrid
        case .satellite: return .imagery
        }
    }
}

struct Pagina: View {
    @State private var searchText: String = ""
    @State private var filtroSelezionato: String = "Tutti"
    @State private var stileMappa: StileMappa = .standard
    
    private let filtri: [String] = [
        "Tutti", "Ristorante", "Panorama", "Ricordo", "Museo"
    ]

    var body: some View {
        UserLocationMap(
            searchText: searchText,
            filtroSelezionato: filtroSelezionato,
            stileMappa: stileMappa
        )
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Cerca nei tuoi posti", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                    
                    Menu {
                        Picker("Stile Mappa", selection: $stileMappa) {
                            ForEach(StileMappa.allCases) { stile in
                                Text(stile.rawValue).tag(stile)
                            }
                        }
                        
                        if filtroSelezionato != "Tutti" || !searchText.isEmpty {
                            Divider()
                            Button(role: .destructive) {
                                withAnimation {
                                    filtroSelezionato = "Tutti"
                                    searchText = ""
                                }
                            } label: {
                                Label("Reimposta filtri", systemImage: "arrow.counterclockwise")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                    }
                }
                .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filtri, id: \.self) { filtro in
                            ButtonTipologie(
                                text: filtro,
                                isSelected: filtroSelezionato == filtro
                            ) {
                                withAnimation(.snappy) {
                                    filtroSelezionato = filtro
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }
}

#Preview {
    HomePage()
}

struct ButtonTipologie: View {
    let text: String
    var isSelected: Bool = false
    var action: () -> Void = { }
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.regularMaterial))
                )
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct HomePage: View {
    var body: some View {
        TabView {
            Pagina()
                .tabItem { Label("Mappa", systemImage: "map") }
            CreazioneSpot()
                .tabItem {
                    Label("Creazione Spot", systemImage: "plus")
                }
            Preferiti()
                .tabItem {
                    Label("Spots", systemImage: "mappin")
                }
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
    var categoria: String = "Panorama"
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
    // Valori di default per mantenere la compatibilità con CreazioneSpot()
    var searchText: String = ""
    var filtroSelezionato: String = "Tutti"
    var stileMappa: StileMappa = .standard

    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic
    @State private var favoritePlaces: FavoritePlaces?

    @State private var places: [FavoritePlaces] = [
        FavoritePlaces(
            name: "Duomo di Milano",
            icon: "mountain.2.fill",
            descrizione: "Vista panoramica dalle terrazze del Duomo sul centro di Milano.",
            categoria: "Panorama",
            latitude: 45.4642,
            longitude: 9.1900
        ),
        FavoritePlaces(
            name: "Colosseo",
            icon: "building.columns.fill",
            descrizione: "Anfiteatro Flavio nel cuore archeologico di Roma.",
            categoria: "Museo",
            latitude: 41.8902,
            longitude: 12.4922
        ),
        FavoritePlaces(
            name: "Trattoria da Mario",
            icon: "fork.knife",
            descrizione: "Solo pranzo, bistecca alla fiorentina tradizionale.",
            categoria: "Ristorante",
            latitude: 43.7764,
            longitude: 11.2539
        )
    ]

    private var placesFiltrati: [FavoritePlaces] {
        places.filter { place in
            let matchCategoria = (filtroSelezionato == "Tutti") ||
                                 (place.categoria.localizedCaseInsensitiveCompare(filtroSelezionato) == .orderedSame)
            
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchTesto = query.isEmpty ||
                             place.name.localizedCaseInsensitiveContains(query) ||
                             place.descrizione.localizedCaseInsensitiveContains(query)
            
            return matchCategoria && matchTesto
        }
    }

    var body: some View {
        Map(position: $position, selection: $favoritePlaces) {
            UserAnnotation()

            ForEach(placesFiltrati) { place in
                Marker(place.name, systemImage: place.icon, coordinate: place.coordinate)
                    .tint(.orange)
                    .tag(place)
            }
        }
        .mapStyle(stileMappa.mapStyle)
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
