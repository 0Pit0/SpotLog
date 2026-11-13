import SwiftUI
import SwiftData

struct ModificaSpot: View {
    let place: FavoritePlaces
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dati = DatiSpot()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MiniMappaSpot(titolo: dati.nome.isEmpty ? place.name : dati.nome, icona: dati.tipologia.icona, colore: dati.colore, coordinate: place.coordinate)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                CampiSpot(dati: $dati)
            }
            .navigationTitle("Modifica Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        dati.applica(a: place)
                        try? modelContext.save()
                        NotificationCenter.default.post(name: .spotDidUpdate, object: nil)
                        dismiss()
                    }
                    .disabled(!dati.valido)
                }
            }
            .onAppear { dati = DatiSpot(place) }
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: FavoritePlaces.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let place = FavoritePlaces(
        name: "Colosseo",
        icon: "building.columns",
        descrizione: "Anfiteatro Flavio nel cuore di Roma.",
        categoria: "Monumento",
        tipologiaRaw: TipologiaSpot.monumento.rawValue,
        colorHex: "#FF9500",
        nazione: "Italia",
        valutazione: 4,
        latitude: 41.8902,
        longitude: 12.4922
    )
    container.mainContext.insert(place)
    return ModificaSpot(place: place)
        .modelContainer(container)
}
