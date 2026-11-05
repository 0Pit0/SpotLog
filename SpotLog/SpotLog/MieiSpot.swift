import SwiftUI
import CoreLocation

// MARK: - Modello Placeholder (Sostituibile con @Model di SwiftData o CoreData)
struct SpotItem: Identifiable, Hashable {
    let id: UUID
    var nome: String
    var nazione: String
    var note: String
    var distanza: String
    var icona: String
    var latitudine: Double
    var longitudine: Double
    
    init(
        id: UUID = UUID(),
        nome: String,
        nazione: String,
        note: String,
        distanza: String,
        icona: String = "star.fill",
        latitudine: Double = 43.7629,
        longitudine: Double = 11.2650
    ) {
        self.id = id
        self.nome = nome
        self.nazione = nazione
        self.note = note
        self.distanza = distanza
        self.icona = icona
        self.latitudine = latitudine
        self.longitudine = longitudine
    }
    
    var asFavoritePlace: FavoritePlaces {
        FavoritePlaces(
            id: id,
            name: nome,
            icon: icona,
            descrizione: note,
            latitude: latitudine,
            longitude: longitudine
        )
    }
}

// MARK: - Dati Mock dal Wireframe (2c)
extension SpotItem {
    static let placeholderData: [SpotItem] = [
        SpotItem(
            nome: "Belvedere San Miniato",
            nazione: "Italia",
            note: "Tramonto pazzesco su Firenze, salire a piedi dalle scale di San Niccolò, portare qualcosa da bere...",
            distanza: "1,2 km",
            icona: "mountain.2",
            latitudine: 43.7593,
            longitudine: 11.2647
        ),
        SpotItem(
            nome: "Trattoria da Mario",
            nazione: "Italia",
            note: "Solo pranzo, niente prenotazioni. Bistecca da dividere in due...",
            distanza: "2,8 km",
            icona: "fork.knife",
            latitudine: 43.7764,
            longitudine: 11.2539
        ),
        SpotItem(
            nome: "Parco delle Cascine",
            nazione: "Italia",
            note: "Corsa domenicale lungo l'Arno...",
            distanza: "4,1 km",
            icona: "tree",
            latitudine: 43.7820,
            longitudine: 11.2190
        ),
        SpotItem(
            nome: "Miradouro da Graça",
            nazione: "Portogallo",
            note: "Chiosco con vinho verde, meglio alle 19...",
            distanza: "1.840 km",
            icona: "mountain.2",
            latitudine: 38.7163,
            longitudine: -9.1315
        ),
        SpotItem(
            nome: "Time Out Market",
            nazione: "Portogallo",
            note: "Pastéis de nata, banco a destra...",
            distanza: "1.842 km",
            icona: "fork.knife",
            latitudine: 38.7071,
            longitudine: -9.1459
        )
    ]
}

struct MieiSpot: View {
    @State private var spots: [SpotItem] = SpotItem.placeholderData
    @State private var testoRicerca: String = ""
    @State private var spotDaEliminare: SpotItem? = nil
    
    private var spotsFiltrati: [SpotItem] {
        guard !testoRicerca.trimmingCharacters(in: .whitespaces).isEmpty else {
            return spots
        }
        return spots.filter {
            $0.nome.localizedCaseInsensitiveContains(testoRicerca) ||
            $0.note.localizedCaseInsensitiveContains(testoRicerca) ||
            $0.nazione.localizedCaseInsensitiveContains(testoRicerca)
        }
    }
    
    private var sezioniPerNazione: [(nazione: String, spots: [SpotItem])] {
        let raggruppati = Dictionary(grouping: spotsFiltrati, by: { $0.nazione })
        return raggruppati
            .map { (nazione: $0.key, spots: $0.value) }
            .sorted { $0.nazione < $1.nazione }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(sezioniPerNazione, id: \.nazione) { sezione in
                    Section {
                        ForEach(sezione.spots) { spot in
                            ZStack {
                                NavigationLink(destination: Dettaglio(place: spot.asFavoritePlace)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                RigaSpot(spot: spot)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    spotDaEliminare = spot
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    } header: {
                        Text("\(sezione.nazione.uppercased()) · \(sezione.spots.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("I Miei Spot")
            .searchable(text: $testoRicerca, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca")
            .alert(
                spotDaEliminare.map { "Eliminare \"\($0.nome)\"?" } ?? "Eliminare spot?",
                isPresented: Binding(
                    get: { spotDaEliminare != nil },
                    set: { if !$0 { spotDaEliminare = nil } }
                ),
                presenting: spotDaEliminare
            ) { spot in
                Button("Annulla", role: .cancel) {
                    spotDaEliminare = nil
                }
                Button("Elimina", role: .destructive) {
                    eliminaSpot(spot)
                }
            } message: { _ in
                Text("Foto e note verranno rimosse dal dispositivo. L'azione non è reversibile.")
            }
            .overlay {
                if spotsFiltrati.isEmpty {
                    ContentUnavailableView(
                        "Nessuno spot trovato",
                        systemImage: "mappin.slash",
                        description: Text("Non ci sono spot corrispondenti alla tua ricerca.")
                    )
                }
            }
        }
    }
    
    // MARK: - Funzione di eliminazione (Punto di aggancio per il futuro DB)
    private func eliminaSpot(_ spot: SpotItem) {
        withAnimation {
            spots.removeAll { $0.id == spot.id }
        }
        spotDaEliminare = nil
    }
}

struct RigaSpot: View {
    let spot: SpotItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(spot.nome)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer(minLength: 4)
                    
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(spot.distanza)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                }
                
                Text(spot.note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MieiSpot()
}
