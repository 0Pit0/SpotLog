import SwiftUI
import SwiftData
import CoreLocation
import UIKit

enum OrdineSpot: String, CaseIterable, Identifiable {
    case piuRecenti = "Più recenti"
    case piuVicini = "Più vicini a te"
    case votoMigliore = "Voto più alto"
    case alfabetico = "Nome (A-Z)"
    
    var id: String { rawValue }
    
    var icona: String {
        switch self {
        case .piuRecenti: return "calendar"
        case .piuVicini: return "location"
        case .votoMigliore: return "star.fill"
        case .alfabetico: return "textformat.abc"
        }
    }
}

struct MieiSpot: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoritePlaces.dataCreazione, order: .reverse) private var spots: [FavoritePlaces]
    @StateObject private var gestorePosizione = GestorePosizione()
    
    @State private var testoRicerca: String = ""
    @State private var filtroCategoria: String = "Tutte"
    @State private var filtroNazione: String = "Tutte"
    @State private var votoMinimo: Int = 0
    @State private var soloConFoto: Bool = false
    @State private var ordinamento: OrdineSpot = .piuRecenti
    
    @State private var spotDaEliminare: FavoritePlaces? = nil
    
    private var categorieDisponibili: [(nome: String, icona: String, count: Int)] {
        var mappa: [String: (nome: String, icona: String, count: Int)] = [:]
        for spot in spots {
            let cat = spot.categoria.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cat.isEmpty else { continue }
            let key = cat.lowercased()
            if let esistente = mappa[key] {
                mappa[key] = (esistente.nome, esistente.icona, esistente.count + 1)
            } else {
                mappa[key] = (cat, spot.icon, 1)
            }
        }
        return mappa.values.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.nome < $1.nome
        }
    }
    
    private var nazioniDisponibili: [String] {
        Array(Set(spots.map { $0.nazione }.filter { !$0.isEmpty })).sorted()
    }
    
    private var haFiltriAttivi: Bool {
        filtroCategoria != "Tutte" ||
        filtroNazione != "Tutte" ||
        votoMinimo > 0 ||
        soloConFoto
    }
    
    private var spotsFiltrati: [FavoritePlaces] {
        let query = testoRicerca.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let filtrati = spots.filter { spot in
            let matchTesto = query.isEmpty ||
                spot.name.localizedCaseInsensitiveContains(query) ||
                spot.descrizione.localizedCaseInsensitiveContains(query) ||
                spot.nazione.localizedCaseInsensitiveContains(query) ||
                spot.categoria.localizedCaseInsensitiveContains(query)
            
            let matchCategoria = (filtroCategoria == "Tutte") ||
                (spot.categoria.localizedCaseInsensitiveCompare(filtroCategoria) == .orderedSame)
            
            let matchNazione = (filtroNazione == "Tutte") ||
                (spot.nazione.localizedCaseInsensitiveCompare(filtroNazione) == .orderedSame)
            
            let matchVoto = spot.valutazione >= votoMinimo
            let matchFoto = !soloConFoto || !spot.fotoData.isEmpty
            
            return matchTesto && matchCategoria && matchNazione && matchVoto && matchFoto
        }
        
        return ordinaLista(filtrati)
    }
    
    private func ordinaLista(_ lista: [FavoritePlaces]) -> [FavoritePlaces] {
        switch ordinamento {
        case .piuRecenti:
            return lista.sorted { $0.dataCreazione > $1.dataCreazione }
        case .piuVicini:
            guard let posUtente = gestorePosizione.posizione else {
                return lista.sorted { $0.dataCreazione > $1.dataCreazione }
            }
            return lista.sorted {
                let d1 = posUtente.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                let d2 = posUtente.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
                return d1 < d2
            }
        case .votoMigliore:
            return lista.sorted {
                $0.valutazione != $1.valutazione
                    ? $0.valutazione > $1.valutazione
                    : $0.dataCreazione > $1.dataCreazione
            }
        case .alfabetico:
            return lista.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }
    
    private var sezioniPerNazione: [(nazione: String, spots: [FavoritePlaces])] {
        let raggruppati = Dictionary(grouping: spotsFiltrati, by: { $0.nazione })
        return raggruppati
            .map { (nazione: $0.key, spots: ordinaLista($0.value)) }
            .sorted { $0.nazione < $1.nazione }
    }
    
    var body: some View {
        NavigationStack {
            listaSpot
                .listStyle(.plain)
                .navigationTitle("I Miei Spot")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $testoRicerca, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca nome, note o nazione")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        menuFiltri
                    }
                }
                .onChange(of: spots) { _, _ in
                    controllaFiltri()
                }
                .onAppear { gestorePosizione.avvia() }
                .onDisappear { gestorePosizione.ferma() }
                .alert(titoloAlert, isPresented: mostraAlert, presenting: spotDaEliminare) { spot in
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
                        vistaVuota
                    }
                }
        }
    }

    // MARK: - Pezzi della vista (separati per aiutare il compilatore)

    private var listaSpot: some View {
        List {
            // I chip stanno dentro la List: così il titolo grande non sparisce su iOS 26
            if !spots.isEmpty {
                barraFiltri
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            ForEach(sezioniPerNazione, id: \.nazione) { sezione in
                Section {
                    ForEach(sezione.spots) { spot in
                        rigaConLink(spot)
                    }
                } header: {
                    Text("\(sezione.nazione.uppercased()) · \(sezione.spots.count)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rigaConLink(_ spot: FavoritePlaces) -> some View {
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

    private var titoloAlert: String {
        if let spot = spotDaEliminare {
            return "Eliminare \"\(spot.name)\"?"
        }
        return "Eliminare spot?"
    }

    private var mostraAlert: Binding<Bool> {
        Binding(
            get: { spotDaEliminare != nil },
            set: { if !$0 { spotDaEliminare = nil } }
        )
    }

    private var barraFiltri: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipFiltroSpot(
                    titolo: "Tutte (\(spots.count))",
                    icona: "tray.full.fill",
                    attivo: filtroCategoria == "Tutte"
                ) {
                    withAnimation(.snappy) { filtroCategoria = "Tutte" }
                }
                
                ForEach(categorieDisponibili, id: \.nome) { cat in
                    ChipFiltroSpot(
                        titolo: "\(cat.nome) (\(cat.count))",
                        icona: cat.icona,
                        attivo: filtroCategoria.localizedCaseInsensitiveCompare(cat.nome) == .orderedSame
                    ) {
                        withAnimation(.snappy) {
                            if filtroCategoria.localizedCaseInsensitiveCompare(cat.nome) == .orderedSame {
                                filtroCategoria = "Tutte"
                            } else {
                                filtroCategoria = cat.nome
                            }
                        }
                    }
                }
                
                Divider()
                    .frame(height: 20)
                
                ChipFiltroSpot(
                    titolo: "Con foto",
                    icona: "photo.fill",
                    attivo: soloConFoto
                ) {
                    withAnimation(.snappy) { soloConFoto.toggle() }
                }
                
                ChipFiltroSpot(
                    titolo: votoMinimo > 0 ? "\(votoMinimo)+ ★" : "4+ ★",
                    icona: "star.fill",
                    attivo: votoMinimo > 0
                ) {
                    withAnimation(.snappy) {
                        votoMinimo = (votoMinimo > 0) ? 0 : 4
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var menuFiltri: some View {
        Menu {
            Section("Ordina per") {
                Picker("Ordina per", selection: $ordinamento) {
                    ForEach(OrdineSpot.allCases) { ordine in
                        Label(ordine.rawValue, systemImage: ordine.icona)
                            .tag(ordine)
                    }
                }
            }
            
            Section("Filtra per Tipologia") {
                Picker("Tipologia", selection: $filtroCategoria) {
                    Text("Tutte (\(spots.count))").tag("Tutte")
                    ForEach(categorieDisponibili, id: \.nome) { cat in
                        Label("\(cat.nome) (\(cat.count))", systemImage: cat.icona)
                            .tag(cat.nome)
                    }
                }
            }
            
            if nazioniDisponibili.count > 1 {
                Section("Filtra per Nazione") {
                    Picker("Nazione", selection: $filtroNazione) {
                        Text("Tutte le nazioni").tag("Tutte")
                        ForEach(nazioniDisponibili, id: \.self) { nazione in
                            Text(nazione).tag(nazione)
                        }
                    }
                }
            }
            
            Section("Altri Filtri") {
                Picker("Valutazione minima", selection: $votoMinimo) {
                    Text("Qualsiasi voto").tag(0)
                    Text("★★★ o superiore").tag(3)
                    Text("★★★★ o superiore").tag(4)
                    Text("★★★★★ (Solo 5 stelle)").tag(5)
                }
                
                Toggle(isOn: $soloConFoto) {
                    Label("Solo spot con foto", systemImage: "photo")
                }
            }
            
            if haFiltriAttivi || ordinamento != .piuRecenti {
                Section {
                    Button(role: .destructive) {
                        withAnimation {
                            reimpostaFiltri()
                        }
                    } label: {
                        Label("Reimposta filtri e ordine", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } label: {
            Image(systemName: haFiltriAttivi ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.title3)
        }
    }

    private var vistaVuota: some View {
        ContentUnavailableView {
            Label(
                spots.isEmpty ? "Nessuno spot salvato" : "Nessuno spot trovato",
                systemImage: "mappin.slash"
            )
        } description: {
            Text(
                spots.isEmpty
                ? "Aggiungi il tuo primo posto dalla scheda Creazione Spot."
                : "Non ci sono spot corrispondenti ai filtri selezionati."
            )
        } actions: {
            if haFiltriAttivi || !testoRicerca.isEmpty {
                Button("Mostra tutti gli spot") {
                    withAnimation {
                        reimpostaFiltri()
                        testoRicerca = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func controllaFiltri() {
        let categoriaEsiste = categorieDisponibili.contains { $0.nome.localizedCaseInsensitiveCompare(filtroCategoria) == .orderedSame }
        if filtroCategoria != "Tutte" && !categoriaEsiste {
            filtroCategoria = "Tutte"
        }
        if filtroNazione != "Tutte" && !nazioniDisponibili.contains(filtroNazione) {
            filtroNazione = "Tutte"
        }
    }

    private func reimpostaFiltri() {
        filtroCategoria = "Tutte"
        filtroNazione = "Tutte"
        votoMinimo = 0
        soloConFoto = false
        ordinamento = .piuRecenti
    }
    
    private func eliminaSpot(_ spot: FavoritePlaces) {
        withAnimation {
            modelContext.delete(spot)
            try? modelContext.save()
            NotificationCenter.default.post(name: .spotDidUpdate, object: nil)
        }
        spotDaEliminare = nil
    }
}

struct ChipFiltroSpot: View {
    let titolo: String
    let icona: String
    let attivo: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icona)
                    .font(.caption2)
                Text(titolo)
                    .font(.caption)
                    .fontWeight(attivo ? .semibold : .medium)
            }
            .foregroundStyle(attivo ? Color(.systemBackground) : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(attivo ? AnyShapeStyle(Color.primary) : AnyShapeStyle(Color(.secondarySystemFill)))
            )
        }
        .buttonStyle(.plain)
    }
}

struct RigaSpot: View {
    let spot: FavoritePlaces
    var posizioneUtente: CLLocation?
    @State private var mostraFotoFullScreen = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let firstPhotoData = spot.fotoData.first,
               let uiImage = UIImage(data: firstPhotoData) {
                Button {
                    mostraFotoFullScreen = true
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .fullScreenCover(isPresented: $mostraFotoFullScreen) {
                    VisualizzatoreFotoFullScreen(
                        immagini: spot.fotoData.compactMap { UIImage(data: $0) },
                        indiceIniziale: 0
                    )
                }
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
                
                HStack(spacing: 6) {
                    Text(spot.categoria)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(spot.swiftUIColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(spot.swiftUIColor)
                    
                    if spot.valutazione > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("\(spot.valutazione)")
                                .fontWeight(.medium)
                        }
                        .font(.caption2)
                    }
                }
                
                if !spot.descrizione.isEmpty {
                    Text(spot.descrizione)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MieiSpot()
        .modelContainer(for: FavoritePlaces.self, inMemory: true)
}
