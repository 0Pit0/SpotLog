import SwiftUI
import SwiftData
import MapKit
import PhotosUI

struct ModificaSpot: View {
    @Bindable var place: FavoritePlaces
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var places: [FavoritePlaces]

    @State private var tipologia: TipologiaSpot = .panorama
    @State private var categoriaCustom: String?
    @State private var nuovaTipologia = ""
    @FocusState private var nuovaTipologiaFocus: Bool
    @State private var nomeSpot = ""
    @State private var noteViaggio = ""
    @State private var iconColor: Color = .blue
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var valutazione = 0
    @State private var fotoSelezionata: FotoSelezionata?
    @State private var contatoreCentra = 0 // Incrementandolo la mappa viene ricreata e ricentrata sullo spot

    private let predefinite = TipologiaSpot.allCases.filter { $0 != .nuovaTipologia }

    private var categoriePersonalizzate: [(nome: String, count: Int)] {
        let standard = Set(predefinite.map { $0.titolo.lowercased() })
        let nomi = places.compactMap { spot -> String? in
            let cat = spot.categoria.trimmed
            let isCustom = spot.tipologiaRaw == TipologiaSpot.nuovaTipologia.rawValue || !standard.contains(cat.lowercased())
            return !cat.isEmpty && isCustom ? cat : nil
        }
        return Dictionary(grouping: nomi) { $0.lowercased() }.values
            .map { (nome: $0[0], count: $0.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
    }

    private var mostraCampoNuovaTipologia: Bool { tipologia == .nuovaTipologia && categoriaCustom == nil }

    private func categoria(fallback: String) -> String {
        guard tipologia == .nuovaTipologia else { return tipologia.titolo }
        let nome = (categoriaCustom ?? nuovaTipologia).trimmed
        return nome.isEmpty ? fallback : nome
    }

    private func seleziona(_ tipo: TipologiaSpot, custom: String? = nil, focus: Bool = false) {
        withAnimation(.snappy) {
            tipologia = tipo
            categoriaCustom = custom
            nuovaTipologia = custom ?? ""
            nuovaTipologiaFocus = focus
        }
    }

    private func voce(_ titolo: String, icona: String, selezionata: Bool, azione: @escaping () -> Void) -> some View {
        Button(action: azione) {
            HStack {
                Text(titolo)
                Image(systemName: icona)
                if selezionata { Image(systemName: "checkmark") }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Map(initialPosition: .region(.init(center: place.coordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        UserAnnotation()
                        Marker(nomeSpot.isEmpty ? place.name : nomeSpot, systemImage: tipologia.icona, coordinate: place.coordinate)
                            .tint(iconColor)
                    }
                    .mapStyle(.imagery)
                    // Forza il ridisegno del Marker e ricentra la mappa quando premo il pulsante
                    .id("\(tipologia.icona)-\(iconColor.toHex())-\(nomeSpot)-\(contatoreCentra)")
                    .overlay(alignment: .topTrailing) {
                        Button { contatoreCentra += 1 } label: {
                            Image(systemName: "mappin")
                                .font(.title2)
                                .foregroundStyle(Color.primary)
                                .padding(8)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.borderless)
                        .padding(8)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Stile Spot") {
                    LabeledContent("Tipologia") {
                        Menu {
                            Section("Predefinite") {
                                ForEach(predefinite) { tipo in
                                    let count = places.count(where: { $0.categoria.localizedCaseInsensitiveCompare(tipo.titolo) == .orderedSame })
                                    voce(count > 0 ? "\(tipo.titolo) (\(count))" : tipo.titolo, icona: tipo.icona, selezionata: tipologia == tipo) {
                                        seleziona(tipo)
                                    }
                                }
                            }
                            let personalizzate = categoriePersonalizzate
                            if !personalizzate.isEmpty {
                                Section("Le tue categorie") {
                                    ForEach(personalizzate, id: \.nome) { custom in
                                        voce("\(custom.nome) (\(custom.count))", icona: "star.fill", selezionata: tipologia == .nuovaTipologia && categoriaCustom == custom.nome) {
                                            seleziona(.nuovaTipologia, custom: custom.nome)
                                        }
                                    }
                                }
                            }
                            Section {
                                Button("Nuova Tipologia…", systemImage: "plus.circle.fill") {
                                    seleziona(.nuovaTipologia, focus: true)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(categoria(fallback: "Nuova Tipologia…")).fontWeight(.medium)
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
                            Image(systemName: "star.fill").foregroundStyle(iconColor)
                            TextField("Nome nuova tipologia", text: $nuovaTipologia)
                                .autocorrectionDisabled()
                                .focused($nuovaTipologiaFocus)
                        }
                    }

                    ColorPicker("Colore", selection: $iconColor, supportsOpacity: false)
                }

                Section("Dettagli") {
                    TextField("Nome spot", text: $nomeSpot)
                    TextField("Note viaggio", text: $noteViaggio, axis: .vertical)
                }

                Section("Foto Spot") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(loadedImages.indices, id: \.self) { index in
                                Button { fotoSelezionata = FotoSelezionata(indiceIniziale: index) } label: {
                                    Image(uiImage: loadedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .overlay(alignment: .topTrailing) {
                                    Button { loadedImages.remove(at: index) } label: {
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
                }

                Section("Valutazione") {
                    LabeledContent("Voto") { StarRatingView(rating: $valutazione) }
                }
            }
            .navigationTitle("Modifica Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { salvaModifiche(); dismiss() }
                        .disabled(nomeSpot.trimmed.isEmpty || (mostraCampoNuovaTipologia && nuovaTipologia.trimmed.isEmpty))
                }
            }
            .fullScreenCover(item: $fotoSelezionata) {
                VisualizzatoreFotoFullScreen(immagini: loadedImages, indiceIniziale: $0.indiceIniziale)
            }
            .onAppear(perform: caricaDati)
            .onChange(of: selectedItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                            loadedImages.append(img)
                        }
                    }
                    selectedItems.removeAll()
                }
            }
        }
    }

    private func caricaDati() {
        nomeSpot = place.name
        noteViaggio = place.descrizione
        tipologia = TipologiaSpot(rawValue: place.tipologiaRaw) ?? .panorama
        if tipologia == .nuovaTipologia {
            categoriaCustom = place.categoria
            nuovaTipologia = place.categoria
        }
        iconColor = place.swiftUIColor
        valutazione = place.valutazione
        loadedImages = place.fotoData.compactMap(UIImage.init(data:))
    }

    private func salvaModifiche() {
        place.name = nomeSpot.trimmed
        place.descrizione = noteViaggio.trimmed
        place.tipologiaRaw = tipologia.rawValue
        place.icon = tipologia.icona
        place.categoria = categoria(fallback: "Personalizzato")
        place.colorHex = iconColor.toHex()
        place.valutazione = valutazione
        place.fotoData = loadedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        try? modelContext.save()
        NotificationCenter.default.post(name: .spotDidUpdate, object: nil)
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
