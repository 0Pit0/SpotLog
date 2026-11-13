import SwiftUI
import SwiftData
import MapKit
import Combine

extension Notification.Name {
    static let spotDidUpdate = Notification.Name("spotDidUpdate")
}

enum StileMappa: String, CaseIterable, Identifiable {
    case standard = "Standard"
    case ibrida = "Ibrida"
    case satellite = "Satellite"

    var id: String { rawValue }

    var mapStyle: MapStyle {
        switch self {
        case .standard: .standard
        case .ibrida: .hybrid
        case .satellite: .imagery
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

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var swiftUIColor: Color { Color(hex: colorHex) ?? .blue }
    var markerID: String { "\(id.uuidString)-\(colorHex)-\(icon)-\(name)-\(latitude)-\(longitude)" }

    func distanzaFormattata(da posizione: CLLocation) -> String {
        let metri = posizione.distance(from: CLLocation(latitude: latitude, longitude: longitude))
        if metri < 1000 { return "\(Int(metri)) m" }
        return Measurement(value: metri / 1000, unit: UnitLength.kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
    }
}

extension Color {
    init?(hex: String) {
        guard let rgb = UInt64(hex.trimmed.replacingOccurrences(of: "#", with: ""), radix: 16) else { return nil }
        self.init(red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }

    func toHex() -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: nil) else { return "#007AFF" }
        let byte = { (c: CGFloat) in Int((min(max(c, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    func uguale(_ altra: String) -> Bool { localizedCaseInsensitiveCompare(altra) == .orderedSame }
}

struct HomePage: View {
    var body: some View {
        TabView {
            Tab("Mappa", systemImage: "map") { Pagina() }
            Tab("Creazione Spot", systemImage: "plus") { CreazioneSpot() }
            Tab("Spots", systemImage: "mappin") { MieiSpot() }
        }
    }
}

struct Pagina: View {
    @Query(sort: \FavoritePlaces.dataCreazione, order: .reverse) private var places: [FavoritePlaces]
    @AppStorage("stileMappa") private var stileMappa: StileMappa = .satellite
    @StateObject private var locationManager = LocationManager()

    @State private var searchText = ""
    @State private var filtroSelezionato = "Tutti"
    @State private var position: MapCameraPosition = .automatic
    @State private var haCentratoSuUtente = false
    @State private var mapSelection: FavoritePlaces?
    @State private var sheetPlace: FavoritePlaces?
    @State private var refreshVersion = 0

    private var tags: [(nome: String, icona: String)] {
        var tags = [(nome: "Tutti", icona: "map.fill")]
            + TipologiaSpot.predefinite.map { (nome: $0.titolo, icona: $0.icona) }
        for place in places {
            let cat = place.categoria.trimmed
            if !cat.isEmpty && !tags.contains(where: { $0.nome.uguale(cat) }) { tags.append((cat, place.icon)) }
        }
        return tags
    }

    private var placesFiltrati: [FavoritePlaces] {
        let query = searchText.trimmed
        return places.filter { place in
            (filtroSelezionato == "Tutti" || place.categoria.uguale(filtroSelezionato))
                && (query.isEmpty || [place.name, place.descrizione, place.nazione].contains { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        let filtrati = placesFiltrati
        Map(position: $position, selection: $mapSelection) {
            UserAnnotation()
            ForEach(filtrati, id: \.markerID) { place in
                Marker(place.name, systemImage: place.icon, coordinate: place.coordinate)
                    .tint(place.swiftUIColor)
                    .tag(place)
            }
        }
        .id("\(refreshVersion)-\(filtrati.map(\.markerID).joined(separator: "|"))")
        .mapStyle(stileMappa.mapStyle)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { position = .region($0.region) }
        .onChange(of: mapSelection) { _, place in
            guard let place else { return }
            sheetPlace = place
            mapSelection = nil
        }
        .sheet(item: $sheetPlace, onDismiss: { refreshVersion += 1 }) { Dettaglio(place: $0) }
        .onReceive(NotificationCenter.default.publisher(for: .spotDidUpdate)) { _ in refreshVersion += 1 }
        .onAppear { locationManager.start() }
        .onChange(of: locationManager.lastLocation) { _, location in
            guard !haCentratoSuUtente, let center = location?.coordinate else { return }
            haCentratoSuUtente = true
            position = .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
        }
        .onChange(of: places) {
            if !tags.contains(where: { $0.nome.uguale(filtroSelezionato) }) { filtroSelezionato = "Tutti" }
        }
        .safeAreaInset(edge: .top, spacing: 0) { barraSuperiore }
    }

    private var barraSuperiore: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Cerca nei tuoi posti", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .vetro()

                Menu {
                    Picker("Stile Mappa", selection: $stileMappa) {
                        ForEach(StileMappa.allCases) { Text($0.rawValue).tag($0) }
                    }
                    if filtroSelezionato != "Tutti" || !searchText.isEmpty {
                        Divider()
                        Button("Reimposta filtri", systemImage: "arrow.counterclockwise", role: .destructive) {
                            withAnimation {
                                filtroSelezionato = "Tutti"
                                searchText = ""
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .vetro()
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.nome) { tag in
                        ButtonTipologie(text: tag.nome, icon: tag.icona, isSelected: filtroSelezionato.uguale(tag.nome)) {
                            filtroSelezionato = tag.nome
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

struct ButtonTipologie: View {
    let text: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button { withAnimation(.snappy, action) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption)
                Text(text).font(.subheadline).fontWeight(isSelected ? .semibold : .medium)
            }
            .foregroundStyle(isSelected ? Color(.systemBackground) : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AnyShapeStyle(Color.primary) : AnyShapeStyle(.regularMaterial), in: Capsule())
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func vetro() -> some View {
        background(.regularMaterial, in: .rect(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func start() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            locationManagerDidChangeAuthorization(manager)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
    }
}

#Preview {
    HomePage()
        .modelContainer(for: FavoritePlaces.self, inMemory: true)
}
