import SwiftUI
import SwiftData
import CoreLocation
import UIKit

struct MieiSpot: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoritePlaces.dataCreazione, order: .reverse) private var spots: [FavoritePlaces]
    @StateObject private var gestorePosizione = GestorePosizione()
    
    @State private var testoRicerca: String = ""
    @State private var spotDaEliminare: FavoritePlaces? = nil
    
    private var spotsFiltrati: [FavoritePlaces] {
        let query = testoRicerca.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return spots }
        return spots.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.descrizione.localizedCaseInsensitiveContains(query) ||
            $0.nazione.localizedCaseInsensitiveContains(query) ||
            $0.categoria.localizedCaseInsensitiveContains(query)
        }
    }
    
    private var sezioniPerNazione: [(nazione: String, spots: [FavoritePlaces])] {
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
                                NavigationLink(destination: Dettaglio(place: spot)) {
                                    EmptyView()
                                }
                                .opacity(0)
                                
                                RigaSpot(spot: spot, posizioneUtente: gestorePosizione.posizione)
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
            .onAppear { gestorePosizione.avvia() }
            .onDisappear { gestorePosizione.ferma() }
            .alert(
                spotDaEliminare.map { "Eliminare \"\($0.name)\"?" } ?? "Eliminare spot?",
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
                        spots.isEmpty ? "Nessuno spot salvato" : "Nessuno spot trovato",
                        systemImage: "mappin.slash",
                        description: Text(
                            spots.isEmpty
                            ? "Aggiungi il tuo primo posto dalla scheda Creazione Spot."
                            : "Non ci sono spot corrispondenti alla tua ricerca."
                        )
                    )
                }
            }
        }
    }
    
    private func eliminaSpot(_ spot: FavoritePlaces) {
        withAnimation {
            modelContext.delete(spot)
            try? modelContext.save()
        }
        spotDaEliminare = nil
    }
}

struct RigaSpot: View {
    let spot: FavoritePlaces
    var posizioneUtente: CLLocation?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Mostra la prima foto salvata oppure il badge con l'icona e il colore dello spot
            if let firstPhotoData = spot.fotoData.first,
               let uiImage = UIImage(data: firstPhotoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(spot.swiftUIColor.opacity(0.18))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: spot.icon)
                            .font(.title3)
                            .foregroundStyle(spot.swiftUIColor)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(spot.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 4)
                    
                    if let posizioneUtente {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text(spot.distanzaFormattata(da: posizioneUtente))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.blue)
                    }
                }
                
                Text(spot.descrizione.isEmpty ? spot.categoria : spot.descrizione)
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
        .modelContainer(for: FavoritePlaces.self, inMemory: true)
}
