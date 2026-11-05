import SwiftUI
import MapKit

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

struct CreazioneSpot: View {
    @State private var tipologia: TipologiaSpot = .panorama
    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var nuovaTipologia: String = ""
    @State private var iconColor: Color = .blue

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
            }
            .navigationTitle("Creazione Spot")
        }
    }
}

#Preview {
    CreazioneSpot()
}
