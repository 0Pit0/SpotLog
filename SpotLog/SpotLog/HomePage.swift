import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import Combine
import UIKit

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

@Model
final class FavoritePlaces {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var descrizione: String
    var categoria: String
    var tipologiaRaw: Int
    var colorHex: String
    var nazione: String
    var dataCreazione: Date
    var valutazione: Int
    var latitude: Double
    var longitude: Double
    @Attribute(.externalStorage) var fotoData: [Data]
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "mountain.2",
        descrizione: String = "",
        categoria: String = "Panorama",
        tipologiaRaw: Int = 0,
        colorHex: String = "#007AFF",
        nazione: String = "Italia",
        dataCreazione: Date = .now,
        valutazione: Int = 0,
        latitude: Double,
        longitude: Double,
        fotoData: [Data] = []
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.descrizione = descrizione
        self.categoria = categoria
        self.tipologiaRaw = tipologiaRaw
        self.colorHex = colorHex
        self.nazione = nazione
        self.dataCreazione = dataCreazione
        self.valutazione = valutazione
        self.latitude = latitude
        self.longitude = longitude
        self.fotoData = fotoData
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var swiftUIColor: Color {
        Color(hex: colorHex) ?? .blue
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
        return km.formatted(
            .measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(1))
            )
        )
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "#007AFF"
        }
        return String(
            format: "#%02X%02X%02X",
            Int(round(r * 255)),
            Int(round(g * 255)),
            Int(round(b * 255))
        )
    }
}

struct Pagina: View {
    @Query(sort: \FavoritePlaces.dataCreazione, order: .reverse) private var places: [FavoritePlaces]
    
    @AppStorage("stileMappa") private var stileMappaRaw: String = StileMappa.standard.rawValue
    
    @State private var searchText: String = ""
    @State private var filtroSelezionato: String = "Tutti"
    
    private var stileMappaBinding: Binding<StileMappa> {
        Binding(
            get: { StileMappa(rawValue: stileMappaRaw) ?? .standard },
            set: { stileMappaRaw = $0.rawValue }
        )
    }

    private var tagsDisponibili: [(nome: String, icona: String)] {
        var base: [(String, String)] = [("Tutti", "map.fill")]
        for tipo in TipologiaSpot.allCases where tipo != .nuovaTipologia {
            base.append((tipo.titolo, tipo.icona))
        }
        
        for place in places {
            let cat = place.categoria.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cat.isEmpty else { continue }
            if !base.contains(where: { $0.0.localizedCaseInsensitiveCompare(cat) == .orderedSame }) {
                base.append((cat, place.icon))
            }
        }
        return base
    }

    var body: some View {
        UserLocationMap(
            searchText: searchText,
            filtroSelezionato: filtroSelezionato,
            stileMappa: stileMappaBinding.wrappedValue
        )
        .onChange(of: places) { _, _ in
            // Se la categoria filtrata non esiste più perché i suoi spot sono stati eliminati, torna a "Tutti"
            if !tagsDisponibili.contains(where: { $0.nome.localizedCaseInsensitiveCompare(filtroSelezionato) == .orderedSame }) {
                filtroSelezionato = "Tutti"
            }
        }
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
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    
                    Menu {
                        Picker("Stile Mappa", selection: stileMappaBinding) {
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
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    }
                }
                .padding(.horizontal, 16)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tagsDisponibili, id: \.nome) { tag in
                            ButtonTipologie(
                                text: tag.nome,
                                icon: tag.icona,
                                isSelected: filtroSelezionato.localizedCaseInsensitiveCompare(tag.nome) == .orderedSame
                            ) {
                                withAnimation(.snappy) {
                                    filtroSelezionato = tag.nome
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

struct ButtonTipologie: View {
    let text: String
    var icon: String? = nil
    var isSelected: Bool = false
    var action: () -> Void = { }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(text)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .medium)
            }
            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.regularMaterial))
            )
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct HomePage: View {
    @State private var tabSelezionata: Int = 0

    var body: some View {
        TabView(selection: $tabSelezionata) {
            Pagina()
                .tabItem { Label("Mappa", systemImage: "map") }
                .tag(0)
            
            CreazioneSpot()
                .tabItem { Label("Creazione Spot", systemImage: "plus") }
                .tag(1)
            
            MieiSpot()
                .tabItem { Label("Spots", systemImage: "mappin") }
                .tag(2)
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

struct UserLocationMap: View {
    var searchText: String = ""
    var filtroSelezionato: String = "Tutti"
    var stileMappa: StileMappa = .standard

    @Query(sort: \FavoritePlaces.dataCreazione, order: .reverse) private var places: [FavoritePlaces]
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedPlace: FavoritePlaces?

    private var placesFiltrati: [FavoritePlaces] {
        places.filter { place in
            let matchCategoria = (filtroSelezionato == "Tutti") ||
                                 (place.categoria.localizedCaseInsensitiveCompare(filtroSelezionato) == .orderedSame)
            
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchTesto = query.isEmpty ||
                             place.name.localizedCaseInsensitiveContains(query) ||
                             place.descrizione.localizedCaseInsensitiveContains(query) ||
                             place.nazione.localizedCaseInsensitiveContains(query)
            
            return matchCategoria && matchTesto
        }
    }

    var body: some View {
        Map(position: $position, selection:$selectedPlace) {
            UserAnnotation()

            ForEach(placesFiltrati) { place in
                Marker(place.name, systemImage: place.icon, coordinate: place.coordinate)
                    .tint(place.swiftUIColor)
                    .tag(place)
            }
        }
        .mapStyle(stileMappa.mapStyle)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .sheet(item: $selectedPlace) { place in
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

#Preview {
    HomePage()
        .modelContainer(for: FavoritePlaces.self, inMemory: true)
}
