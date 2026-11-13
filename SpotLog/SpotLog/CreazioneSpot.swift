import SwiftUI
import SwiftData
import MapKit
import PhotosUI

enum TipologiaSpot: Int, CaseIterable, Identifiable {
    case panorama, monumento, natura, ristoro, cultura, spiaggia, divertimento, shopping, nuovaTipologia

    static let predefinite = allCases.filter { $0 != .nuovaTipologia }

    var id: Int { rawValue }
    /// Nome salvato nel database (sempre in italiano): non usarlo direttamente nella UI.
    var titolo: String { info.titolo }
    var icona: String { info.icona }

    /// Nome tradotto da mostrare all'utente (la chiave è il titolo italiano in Localizable.xcstrings).
    var nomeVisualizzato: String { String(localized: String.LocalizationValue(titolo)) }

    /// Traduce una categoria salvata se è predefinita; le categorie create dall'utente restano invariate.
    static func nomeVisualizzato(categoria: String) -> String {
        predefinite.first { $0.titolo.uguale(categoria) }?.nomeVisualizzato ?? categoria
    }

    private var info: (titolo: String, icona: String) {
        switch self {
        case .panorama: ("Panorama", "mountain.2")
        case .monumento: ("Monumento", "building.columns")
        case .natura: ("Natura", "tree")
        case .ristoro: ("Ristoro", "fork.knife")
        case .cultura: ("Cultura", "book")
        case .spiaggia: ("Spiaggia", "water.waves")
        case .divertimento: ("Divertimento", "party.popper")
        case .shopping: ("Shopping", "cart")
        case .nuovaTipologia: ("Nuova Tipologia", "star")
        }
    }
}

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating = 5

    var body: some View {
        HStack {
            ForEach(1...maxRating, id: \.self) { n in
                Button { rating = rating == n ? 0 : n } label: {
                    Image(systemName: n <= rating ? "star.fill" : "star")
                        .foregroundStyle(n <= rating ? .yellow : .gray.opacity(0.4))
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct DatiSpot {
    var nome = ""
    var note = ""
    var tipologia: TipologiaSpot = .panorama
    var categoriaCustom: String?
    var nuovaTipologia = ""
    var colore: Color = .blue
    var immagini: [UIImage] = []
    var valutazione = 0

    init() {}

    init(_ place: FavoritePlaces) {
        nome = place.name
        note = place.descrizione
        tipologia = TipologiaSpot(rawValue: place.tipologiaRaw) ?? .panorama
        if tipologia == .nuovaTipologia { (categoriaCustom, nuovaTipologia) = (place.categoria, place.categoria) }
        colore = place.swiftUIColor
        immagini = place.fotoData.compactMap(UIImage.init(data:))
        valutazione = place.valutazione
    }

    var mostraCampoNuovaTipologia: Bool { tipologia == .nuovaTipologia && categoriaCustom == nil }
    var valido: Bool { !nome.trimmed.isEmpty && !(mostraCampoNuovaTipologia && nuovaTipologia.trimmed.isEmpty) }
    var firmaMarker: String { "\(tipologia.icona)-\(colore.toHex())-\(nome)" }

    func categoria(fallback: String = "Personalizzato") -> String {
        guard tipologia == .nuovaTipologia else { return tipologia.titolo }
        let nome = (categoriaCustom ?? nuovaTipologia).trimmed
        return nome.isEmpty ? fallback : nome
    }

    mutating func seleziona(_ tipo: TipologiaSpot, custom: String? = nil) {
        (tipologia, categoriaCustom, nuovaTipologia) = (tipo, custom, custom ?? "")
    }

    func applica(a place: FavoritePlaces) {
        place.name = nome.trimmed
        place.descrizione = note.trimmed
        place.tipologiaRaw = tipologia.rawValue
        place.icon = tipologia.icona
        place.categoria = categoria()
        place.colorHex = colore.toHex()
        place.valutazione = valutazione
        place.fotoData = immagini.compactMap { $0.jpegData(compressionQuality: 0.8) }
    }
}

struct CampiSpot: View {
    @Binding var dati: DatiSpot
    @Query private var places: [FavoritePlaces]
    @FocusState private var focusNuovaTipologia: Bool
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var fotoSelezionata: FotoSelezionata?

    private var categoriePersonalizzate: [String] {
        let standard = Set(TipologiaSpot.predefinite.map { $0.titolo.lowercased() })
        let nomi = places.compactMap { spot -> String? in
            let cat = spot.categoria.trimmed
            let isCustom = spot.tipologiaRaw == TipologiaSpot.nuovaTipologia.rawValue || !standard.contains(cat.lowercased())
            return !cat.isEmpty && isCustom ? cat : nil
        }
        return Dictionary(grouping: nomi) { $0.lowercased() }.values
            .map { $0[0] }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var body: some View {
        Section("Stile Spot") {
            LabeledContent("Tipologia") { menuTipologia }
                .tint(dati.colore)
            if dati.mostraCampoNuovaTipologia {
                HStack {
                    Image(systemName: "star.fill").foregroundStyle(dati.colore)
                    TextField("Nome nuova tipologia (es. Escursione)", text: $dati.nuovaTipologia)
                        .autocorrectionDisabled()
                        .focused($focusNuovaTipologia)
                    if !dati.nuovaTipologia.isEmpty {
                        Button { dati.nuovaTipologia = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ColorPicker("Colore", selection: $dati.colore, supportsOpacity: false)
        }

        Section("Dettagli") {
            TextField("Nome spot", text: $dati.nome)
            TextField("Note viaggio", text: $dati.note, axis: .vertical)
                .lineLimit(3...6)
        }

        Section("Foto Spot") { galleria }

        Section("Valutazione") {
            LabeledContent("Voto") { StarRatingView(rating: $dati.valutazione) }
        }
    }

    private var menuTipologia: some View {
        Menu {
            Section("Predefinite") {
                ForEach(TipologiaSpot.predefinite) { tipo in
                    voce(tipo.nomeVisualizzato, icona: tipo.icona, selezionata: dati.tipologia == tipo) {
                        dati.seleziona(tipo)
                    }
                }
            }
            let personalizzate = categoriePersonalizzate
            if !personalizzate.isEmpty {
                Section("Le tue categorie") {
                    ForEach(personalizzate, id: \.self) { nome in
                        voce(nome, icona: "star.fill", selezionata: dati.tipologia == .nuovaTipologia && dati.categoriaCustom == nome) {
                            dati.seleziona(.nuovaTipologia, custom: nome)
                        }
                    }
                }
            }
            Section {
                Button("Nuova Tipologia…", systemImage: "plus.circle.fill") {
                    withAnimation(.snappy) { dati.seleziona(.nuovaTipologia) }
                    focusNuovaTipologia = true
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(dati.tipologia == .nuovaTipologia ? dati.categoria(fallback: String(localized: "Nuova Tipologia…")) : dati.tipologia.nomeVisualizzato)
                    .fontWeight(.medium)
                Image(systemName: dati.tipologia.icona)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(dati.colore.opacity(0.12), in: Capsule())
        }
    }

    private func voce(_ titolo: String, icona: String, selezionata: Bool, azione: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy, azione) } label: {
            HStack {
                Text(titolo)
                Image(systemName: icona)
                if selezionata { Image(systemName: "checkmark") }
            }
        }
    }

    private var galleria: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dati.immagini.indices, id: \.self) { index in
                    Button { fotoSelezionata = FotoSelezionata(indiceIniziale: index) } label: {
                        Image(uiImage: dati.immagini[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .overlay(alignment: .topTrailing) {
                        Button { dati.immagini.remove(at: index) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .red)
                        }
                        .offset(x: 4, y: -4)
                    }
                }
                PhotosPicker(selection: $selectedItems, matching: .images) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        }
        .fullScreenCover(item: $fotoSelezionata) {
            VisualizzatoreFotoFullScreen(immagini: dati.immagini, indiceIniziale: $0.indiceIniziale)
        }
        .onChange(of: selectedItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                        dati.immagini.append(img)
                    }
                }
                selectedItems.removeAll()
            }
        }
    }
}

extension CLLocationCoordinate2D {
    func nazione() async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude))
        guard let paese = placemarks?.first?.country, !paese.isEmpty else { return nil }
        return paese
    }
}

/// Mappa usata in Creazione e Modifica Spot: il segnalino si sposta solo toccando la mappa.
struct SelettorePosizioneSpot: View {
    @Binding var cameraPosition: MapCameraPosition
    let coordinata: CLLocationCoordinate2D
    let dati: DatiSpot
    var titoloPredefinito = "Spot"
    /// Spot già salvati da mostrare come riferimento: sempre in grigio, senza toccare il loro colore salvato.
    var altriSpot: [FavoritePlaces] = []
    let onTocco: (CLLocationCoordinate2D) -> Void

    var body: some View {
        Section {
            MapReader { proxy in
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    ForEach(altriSpot, id: \.markerID) { spot in
                        Marker(spot.name, systemImage: spot.icon, coordinate: spot.coordinate)
                            .tint(.gray)
                    }
                    Marker(dati.nome.isEmpty ? titoloPredefinito : dati.nome, systemImage: dati.tipologia.icona, coordinate: coordinata)
                        .tint(dati.colore)
                }
                .id(dati.firmaMarker)
                .onMapCameraChange(frequency: .onEnd) { cameraPosition = .camera($0.camera) }
                .mapControls { MapUserLocationButton() }
                .simultaneousGesture(
                    SpatialTapGesture(coordinateSpace: .local).onEnded { tocco in
                        guard let coord = proxy.convert(tocco.location, from: .local) else { return }
                        onTocco(coord)
                    }
                )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
        } footer: {
            Text("Tocca un punto sulla mappa per spostare il segnalino dello spot.").font(.caption2)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear).mapStyle(.imagery)
    }
}

struct CreazioneSpot: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var places: [FavoritePlaces]
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var coordinata = CLLocationCoordinate2D(latitude: 43.7696, longitude: 11.2558)
    @State private var haImpostatoPosizioneIniziale = false
    @State private var nazioneRilevata = "Italia"
    @State private var dati = DatiSpot()
    var onSalvato: () -> Void = {}

    var body: some View {
        NavigationStack {
            Form {
                SelettorePosizioneSpot(cameraPosition: $cameraPosition, coordinata: coordinata, dati: dati, titoloPredefinito: String(localized: "Nuovo Spot"), altriSpot: places) { coord in
                    haImpostatoPosizioneIniziale = true
                    sposta(su: coord)
                }

                CampiSpot(dati: $dati)

                Section {
                    Button(action: salva) {
                        Text("Salva Spot")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!dati.valido)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Creazione Spot")
            .onAppear { locationManager.start() }
            .onChange(of: locationManager.lastLocation) { _, posizione in
                guard !haImpostatoPosizioneIniziale else { return }
                centraSuPosizioneAttuale(posizione)
            }
        }
    }

    private func centraSuPosizioneAttuale(_ posizione: CLLocation?) {
        guard let coord = posizione?.coordinate else { return }
        haImpostatoPosizioneIniziale = true
        cameraPosition = .region(MKCoordinateRegion(center: coord, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
        sposta(su: coord)
    }

    private func sposta(su coord: CLLocationCoordinate2D) {
        coordinata = coord
        Task {
            if let paese = await coord.nazione() { nazioneRilevata = paese }
        }
    }

    private func salva() {
        let spot = FavoritePlaces(name: "", nazione: nazioneRilevata, latitude: coordinata.latitude, longitude: coordinata.longitude)
        dati.applica(a: spot)
        modelContext.insert(spot)
        try? modelContext.save()
        NotificationCenter.default.post(name: .spotDidUpdate, object: nil)
        dati = DatiSpot()
        // Il prossimo spot riparte dalla posizione attuale, non da quella appena salvata.
        haImpostatoPosizioneIniziale = false
        centraSuPosizioneAttuale(locationManager.lastLocation)
        onSalvato()
    }
}

#Preview {
    CreazioneSpot()
        .modelContainer(for: FavoritePlaces.self, inMemory: true)
}
