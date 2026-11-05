import SwiftUI
import MapKit
import PhotosUI

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
    @State private var tipologia: TipologiaSpot = .panorama
    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var nuovaTipologia: String = ""
    @State private var iconColor: Color = .blue
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []

    @State private var valutazione: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    UserLocationMap()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
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
                        TextField("Nuova tipologia", text: $nuovaTipologia)
                    }

                    ColorPicker("Colore", selection: $iconColor)
                }

                Section("Dettagli") {
                    TextField("Nome spot", text: $nomeSpot)
                    TextField("Note viaggio", text: $noteViaggio, axis: .vertical)
                }

                Section("Foto Spot") {
                    if !loadedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<loadedImages.count, id: \.self) { index in
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
            .navigationTitle("Creazione Spot")
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
}

#Preview {
    CreazioneSpot()
}
