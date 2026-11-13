import SwiftUI
import SwiftData
import MapKit

struct ModificaSpot: View {
    let place: FavoritePlaces
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var dati = DatiSpot()
    @State private var coordinata: CLLocationCoordinate2D
    @State private var cameraPosition: MapCameraPosition
    @State private var nazione: String

    init(place: FavoritePlaces) {
        self.place = place
        _coordinata = State(initialValue: place.coordinate)
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(center: place.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))
        _nazione = State(initialValue: place.nazione)
    }

    var body: some View {
        NavigationStack {
            Form {
                SelettorePosizioneSpot(cameraPosition: $cameraPosition, coordinata: coordinata, dati: dati, titoloPredefinito: place.name) { coord in
                    sposta(su: coord)
                }

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
                        place.latitude = coordinata.latitude
                        place.longitude = coordinata.longitude
                        place.nazione = nazione
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

    private func sposta(su coord: CLLocationCoordinate2D) {
        coordinata = coord
        Task {
            if let paese = await coord.nazione() { nazione = paese }
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
