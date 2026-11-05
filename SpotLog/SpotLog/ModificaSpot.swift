import SwiftUI
import SwiftData
import MapKit
import PhotosUI
import UIKit

struct ModificaSpot: View {
    @Bindable var place: FavoritePlaces
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var places: [FavoritePlaces]

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: place.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )) {
                        Marker(
                            nomeSpot.isEmpty ? place.name : nomeSpot,
                            systemImage: tipologia.icona,
                            coordinate: place.coordinate
                        )
                        .tint(iconColor)
                    }
                    .id("\(tipologia.icona)-\(iconColor.toHex())-\(nomeSpot)")
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
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
                            TextField("Nome nuova tipologia", text: $nuovaTipologia)
                                .autocorrectionDisabled()
                                .focused($campoNuovaTipologiaFocussato)
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
            }
            .navigationTitle("Modifica Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        salvaModifiche()
                        dismiss()
                    }
                    .disabled(
                        nomeSpot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        (mostraCampoNuovaTipologia && nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                }
            }
            .fullScreenCover(item: $fotoSelezionata) { selezione in
                VisualizzatoreFotoFullScreen(
                    immagini: loadedImages,
                    indiceIniziale: selezione.indiceIniziale
                )
            }
            .onAppear {
                nomeSpot = place.name
                noteViaggio = place.descrizione
                tipologia = TipologiaSpot(rawValue: place.tipologiaRaw) ?? .panorama
                if tipologia == .nuovaTipologia {
                    categoriaCustomSelezionata = place.categoria
                    nuovaTipologia = place.categoria
                }
                iconColor = place.swiftUIColor
                valutazione = place.valutazione
                loadedImages = place.fotoData.compactMap { UIImage(data: $0) }
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
        }
    }
    
    private func salvaModifiche() {
        let categoriaScelta: String
        if tipologia == .nuovaTipologia {
            if let custom = categoriaCustomSelezionata {
                categoriaScelta = custom
            } else {
                let pulita = nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines)
                categoriaScelta = pulita.isEmpty ? "Personalizzato" : pulita
            }
        } else {
            categoriaScelta = tipologia.titolo
        }
        
        place.name = nomeSpot.trimmingCharacters(in: .whitespacesAndNewlines)
        place.descrizione = noteViaggio.trimmingCharacters(in: .whitespacesAndNewlines)
        place.tipologiaRaw = tipologia.rawValue
        place.icon = tipologia.icona
        place.categoria = categoriaScelta
        place.colorHex = iconColor.toHex()
        place.valutazione = valutazione
        place.fotoData = loadedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }
        
        try? modelContext.save()
        NotificationCenter.default.post(name: .spotDidUpdate, object: nil)
    }
}
