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
    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var nuovaTipologia: String = ""
    @State private var iconColor: Color = .blue
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var valutazione: Int = 0

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
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: place.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )) {
                        Marker(nomeSpot.isEmpty ? place.name : nomeSpot, systemImage: tipologia.icona, coordinate: place.coordinate)
                            .tint(iconColor)
                    }
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
                        (tipologia == .nuovaTipologia && nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )
                }
            }
            .onAppear {
                nomeSpot = place.name
                noteViaggio = place.descrizione
                tipologia = TipologiaSpot(rawValue: place.tipologiaRaw) ?? .panorama
                if tipologia == .nuovaTipologia {
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
            let pulita = nuovaTipologia.trimmingCharacters(in: .whitespacesAndNewlines)
            categoriaScelta = pulita.isEmpty ? "Personalizzato" : pulita
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
    }
}
