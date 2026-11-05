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
                    rating = (rating == number) ? 0 : number
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
    @State private var categoriaCustomSelezionata: String? = nil
    @State private var nuovaTipologia: String = ""
    @FocusState private var campoNuovaTipologiaFocussato: Bool

    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var iconColor: Color = .blue
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var valutazione: Int = 0
    @State private var mostraConfermaSalvataggio = false
    @State private var fotoSelezionata: FotoSelezionata? = nil

    private var tipologiePredefinite: [TipologiaSpot] {
        TipologiaSpot.allCases.filter { $0 != .nuovaTipologia }
    }

    private var categoriePersonalizzateEsistenti: [(nome: String, count: Int)] {
        let nomiStandard = Set(tipologiePredefinite.map { $0.titolo.lowercased() })
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
            .sorted {
                $0.count != $1.count
                    ? $0.count > $1.count
                    : $0.nomeOriginale.localizedCaseInsensitiveCompare($1.nomeOriginale) == .orderedAscending
            }
            .map { (nome: $0.nomeOriginale, count: $0.count) }
    }

    private func conteggioSpot(per tipo: TipologiaSpot) -> Int {
        places.filter {
            $0.categoria.localizedCaseInsensitiveCompare(tipo.titolo) == .orderedSame
        }.count
    }

    private var mostraCampoNuovaTipologia: Bool {
        tipologia == .nuovaTipologia && categoriaCustomSelezionata == nil
    }

    private var etichettaMenuTipologia: String {
        if tipologia == .nuovaTipologia {
            if let custom = categoriaCustomSelezionata {
                return custom
            }
            let digitata = nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines)
            return digitata.isEmpty ? "Nuova Tipologia…" : digitata
        }
        return tipologia.titolo
    }

    private var categoriaFinale: String {
        if tipologia == .nuovaTipologia {
            if let custom = categoriaCustomSelezionata {
                return custom
            }
            let pulita = nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines)
            return pulita.isEmpty ? "Personalizzato" : pulita
        }
        return tipologia.titolo
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
                            .id("\(tipologia.icona)-\(iconColor.toHex())-\(nomeSpot)")
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
                    LabeledContent("Tipologia") {
                        Menu {
                            Section("Predefinite") {
                                ForEach(tipologiePredefinite) { tipo in
                                    let count = conteggioSpot(per: tipo)
                                    Button {
                                        withAnimation(.snappy) {
                                            tipologia = tipo
                                            categoriaCustomSelezionata = nil
                                            nuovaTipologia = ""
                                        }
                                    } label: {
                                        HStack {
                                            Text(count > 0 ? "\(tipo.titolo) (\(count))" : tipo.titolo)
                                            Image(systemName: tipo.icona)
                                            if tipologia == tipo {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            }

                            if !categoriePersonalizzateEsistenti.isEmpty {
                                Section("Le tue categorie") {
                                    ForEach(categoriePersonalizzateEsistenti, id: \.nome) { custom in
                                        Button {
                                            withAnimation(.snappy) {
                                                tipologia = .nuovaTipologia
                                                categoriaCustomSelezionata = custom.nome
                                                nuovaTipologia = custom.nome
                                            }
                                        } label: {
                                            HStack {
                                                Text("\(custom.nome) (\(custom.count))")
                                                Image(systemName: "star.fill")
                                                if tipologia == .nuovaTipologia && categoriaCustomSelezionata == custom.nome {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Section {
                                Button {
                                    withAnimation(.snappy) {
                                        tipologia = .nuovaTipologia
                                        categoriaCustomSelezionata = nil
                                        nuovaTipologia = ""
                                        campoNuovaTipologiaFocussato = true
                                    }
                                } label: {
                                    Label("Nuova Tipologia…", systemImage: "plus.circle.fill")
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(etichettaMenuTipologia)
                                    .fontWeight(.medium)
                                Image(systemName: tipologia.icona)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(iconColor.opacity(0.12), in: Capsule())
                        }
                    }
                    .tint(iconColor)

                    if mostraCampoNuovaTipologia {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(iconColor)
                            TextField("Nome nuova tipologia (es. Escursione)", text: $nuovaTipologia)
                                .autocorrectionDisabled()
                                .focused($campoNuovaTipologiaFocussato)
                            
                            if !nuovaTipologia.isEmpty {
                                Button {
                                    nuovaTipologia = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(loadedImages.indices, id: \.self) { index in
                                ZStack(alignment: .topTrailing) {
                                    Button {
                                        fotoSelezionata = FotoSelezionata(indiceIniziale: index)
                                    } label: {
                                        Image(uiImage: loadedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)

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

                            PhotosPicker(
                                selection: $selectedItems,
                                matching: .images
                            ) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 80, height: 80)
                                    .overlay {
                                        Image(systemName: "plus")
                                            .font(.title2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
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
                        (mostraCampoNuovaTipologia && nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Creazione Spot")
            .fullScreenCover(item: $fotoSelezionata) { selezione in
                VisualizzatoreFotoFullScreen(
                    immagini: loadedImages,
                    indiceIniziale: selezione.indiceIniziale
                )
            }
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
        NotificationCenter.default.post(name: .spotDidUpdate, object: nil)
        
        nomeSpot = ""
        noteViaggio = ""
        nuovaTipologia = ""
        categoriaCustomSelezionata = nil
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
