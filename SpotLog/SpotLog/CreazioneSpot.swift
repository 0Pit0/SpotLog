import SwiftUI
import SwiftData
import MapKit
import PhotosUI
import CoreLocation

enum TipologiaSpot: Int, CaseIterable, Identifiable {
    case panorama = 0
    case monumento = 1
    case natura = 2
    case ristoro = 3
    case cultura = 4
    case spiaggia = 5
    case divertimento = 6
    case shopping = 7
    case nuovaTipologia = 8

    var id: Int { rawValue }

    var titolo: String {
        switch self {
        case .panorama: return "Panorama"
        case .monumento: return "Monumento"
        case .natura: return "Natura"
        case .ristoro: return "Ristoro"
        case .cultura: return "Cultura"
        case .spiaggia: return "Spiaggia"
        case .divertimento: return "Divertimento"
        case .shopping: return "Shopping"
        case .nuovaTipologia: return "Nuova Tipologia"
        }
    }

    var icona: String {
        switch self {
        case .panorama: return "mountain.2"
        case .monumento: return "building.columns"
        case .natura: return "tree"
        case .ristoro: return "fork.knife"
        case .cultura: return "book"
        case .spiaggia: return "water.waves"
        case .divertimento: return "party.popper"
        case .shopping: return "cart"
        case .nuovaTipologia: return "star"
        }
    }
}

struct StarRatingView: View {
    @Binding var rating: Int
    var maxRating: Int = 5

    var body: some View {
        HStack {
            ForEach(1...maxRating, id: \.self) { number in
                Button {
                    if rating == number {
                        rating = 0
                    } else {
                        rating = number
                    }
                } label: {
                    Image(systemName: number <= rating ? "star.fill" : "star")
                        .foregroundStyle(number <= rating ? .yellow : .gray.opacity(0.4))
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CreazioneSpot: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var places: [FavoritePlaces]
    
    @StateObject private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var coordinateScelte = CLLocationCoordinate2D(latitude: 43.7696, longitude: 11.2558)
    @State private var haImpostatoPosizioneIniziale = false
    @State private var nazioneRilevata: String = "Italia"

    @State private var tipologia: TipologiaSpot = .panorama
    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var nuovaTipologia: String = ""
    @State private var iconColor: Color = .blue
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var valutazione: Int = 0
    @State private var mostraConfermaSalvataggio = false

    private var categoriaFinale: String {
        if tipologia == .nuovaTipologia {
            let pulita = nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines)
            return pulita.isEmpty ? "Personalizzato" : pulita
        }
        return tipologia.titolo
    }
    
    private var suggerimentiCategorie: [(nome: String, count: Int)] {
        let query = nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        
        let nomiStandard = Set(
            TipologiaSpot.allCases
                .filter { $0 != .nuovaTipologia }
                .map { $0.titolo.lowercased() }
        )
        
        var conteggi: [String: (nomeOriginale: String, count: Int)] = [:]
        for spot in places {
            let cat = spot.categoria.trimmingCharacters(in: .whitespacesAndNewlines)
            let chiave = cat.lowercased()
            guard !chiave.isEmpty,
                  spot.tipologiaRaw == TipologiaSpot.nuovaTipologia.rawValue || !nomiStandard.contains(chiave) else {
                continue
            }
            if let esistente = conteggi[chiave] {
                conteggi[chiave] = (esistente.nomeOriginale, esistente.count + 1)
            } else {
                conteggi[chiave] = (cat, 1)
            }
        }
        
        return conteggi.values
            .filter { $0.nomeOriginale.localizedCaseInsensitiveContains(query) }
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : $0.nomeOriginale.localizedCaseInsensitiveCompare($1.nomeOriginale) == .orderedAscending
            }
            .map { (nome: $0.nomeOriginale, count: $0.count) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .bottomLeading) {
                        MapReader { proxy in
                            Map(position: $cameraPosition) {
                                UserAnnotation()
                                
                                Marker(
                                    nomeSpot.isEmpty ? "Nuovo Spot" : nomeSpot,
                                    systemImage: tipologia.icona,
                                    coordinate: coordinateScelte
                                )
                                .tint(iconColor)
                            }
                            .onTapGesture { screenPoint in
                                if let coord = proxy.convert(screenPoint, from: .local) {
                                    coordinateScelte = coord
                                    aggiornaNazione(per: coord)
                                }
                            }
                        }
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        
                        HStack(spacing: 8) {
                            Label(Date.now.formatted(date: .abbreviated, time: .omitted), systemImage: "clock")
                            Label(nazioneRilevata, systemImage: "flag.fill")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding(10)
                    }
                } footer: {
                    Text("Tocca un punto sulla mappa per spostare il segnalino dello spot.")
                        .font(.caption2)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Stile Spot") {
                    LabeledContent("Icona") {
                        Menu {
                            Picker("", selection: $tipologia) {
                                ForEach(TipologiaSpot.allCases) { tipo in
                                    Label(tipo.titolo, systemImage: tipo.icona)
                                        .tag(tipo)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(tipologia.titolo)
                                Image(systemName: tipologia.icona)
                            }
                        }
                    }
                    .tint(iconColor)

                    if tipologia == .nuovaTipologia {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Nuova tipologia", text: $nuovaTipologia)
                                .autocorrectionDisabled()
                            
                            if !suggerimentiCategorie.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggerimentiCategorie, id: \.nome) { suggerimento in
                                            Button {
                                                nuovaTipologia = suggerimento.nome
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "star.fill")
                                                        .font(.caption2)
                                                    Text("\(suggerimento.nome) (\(suggerimento.count))")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(iconColor.opacity(0.15), in: Capsule())
                                                .foregroundStyle(iconColor)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }

                    ColorPicker("Colore", selection: $iconColor, supportsOpacity: false)
                }

                Section("Dettagli") {
                    TextField("Nome spot", text: $nomeSpot)
                    TextField("Note viaggio", text: $noteViaggio, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Foto Spot") {
                    if !loadedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(loadedImages.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: loadedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            loadedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                        }
                                        .buttonStyle(.plain)
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(
                        selection: $selectedItems,
                        matching: .images
                    ) {
                        Label("Aggiungi Foto", systemImage: "photo.badge.plus")
                    }
                }

                Section("Valutazione") {
                    LabeledContent("Voto") {
                        StarRatingView(rating: $valutazione)
                    }
                }
                
                Section {
                    Button {
                        salvaNuovoSpot()
                    } label: {
                        Text("Salva Spot")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        nomeSpot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        (tipologia == .nuovaTipologia && nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Creazione Spot")
            .onAppear {
                locationManager.start()
            }
            .onChange(of: locationManager.lastLocation) { _, nuovaPosizione in
                guard !haImpostatoPosizioneIniziale, let coord = nuovaPosizione?.coordinate else { return }
                haImpostatoPosizioneIniziale = true
                coordinateScelte = coord
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                )
                aggiornaNazione(per: coord)
            }
            .onChange(of: selectedItems) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            loadedImages.append(uiImage)
                        }
                    }
                    selectedItems.removeAll()
                }
            }
            .alert("Spot salvato!", isPresented: $mostraConfermaSalvataggio) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Il nuovo spot è stato aggiunto alla mappa e alla tua lista.")
            }
        }
    }
    
    private func aggiornaNazione(per coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            if let country = placemarks?.first?.country, !country.isEmpty {
                DispatchQueue.main.async {
                    self.nazioneRilevata = country
                }
            }
        }
    }
    
    private func salvaNuovoSpot() {
        let immaginiCompressaData = loadedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        
        let nuovoSpot = FavoritePlaces(
            name: nomeSpot.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: tipologia.icona,
            descrizione: noteViaggio.trimmingCharacters(in: .whitespacesAndNewlines),
            categoria: categoriaFinale,
            tipologiaRaw: tipologia.rawValue,
            colorHex: iconColor.toHex(),
            nazione: nazioneRilevata,
            dataCreazione: .now,
            valutazione: valutazione,
            latitude: coordinateScelte.latitude,
            longitude: coordinateScelte.longitude,
            fotoData: immaginiCompressaData
        )
        
        modelContext.insert(nuovoSpot)
        try? modelContext.save()
        
        // Reset del form
        nomeSpot = ""
        noteViaggio = ""
        nuovaTipologia = ""
        tipologia = .panorama
        iconColor = .blue
        loadedImages.removeAll()
        valutazione = 0
        mostraConfermaSalvataggio = true
    }
}

#Preview {
    CreazioneSpot()
        .modelContainer(for: FavoritePlaces.self, inMemory: true)
}
