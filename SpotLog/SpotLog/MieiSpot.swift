import SwiftUI
import SwiftData
import CoreLocation

enum OrdineSpot: String, CaseIterable, Identifiable {
    case piuRecenti = "Più recenti"
    case piuVicini = "Più vicini a te"
    case votoMigliore = "Voto più alto"
    case alfabetico = "Nome (A-Z)"

    var id: String { rawValue }

    var icona: String {
        switch self {
        case .piuRecenti: "calendar"
        case .piuVicini: "location"
        case .votoMigliore: "star.fill"
        case .alfabetico: "textformat.abc"
        }
    }
}

struct MieiSpot: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoritePlaces.dataCreazione, order: .reverse) private var spots: [FavoritePlaces]
    @StateObject private var gestorePosizione = GestorePosizione()

    @State private var testoRicerca = ""
    @State private var filtroCategoria = "Tutte"
    @State private var filtroNazione = "Tutte"
    @State private var votoMinimo = 0
    @State private var soloConFoto = false
    @State private var ordinamento: OrdineSpot = .piuRecenti
    @State private var spotDaEliminare: FavoritePlaces?

    private var categorieDisponibili: [(nome: String, icona: String, count: Int)] {
        Dictionary(grouping: spots.filter { !$0.categoria.trimmed.isEmpty }) { $0.categoria.trimmed.lowercased() }.values
            .map { (nome: $0[0].categoria.trimmed, icona: $0[0].icon, count: $0.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.nome < $1.nome }
    }

    private var nazioniDisponibili: [String] {
        Set(spots.map(\.nazione).filter { !$0.isEmpty }).sorted()
    }

    private var haFiltriAttivi: Bool {
        filtroCategoria != "Tutte" || filtroNazione != "Tutte" || votoMinimo > 0 || soloConFoto
    }

    private var spotsFiltrati: [FavoritePlaces] {
        let query = testoRicerca.trimmed
        let filtrati = spots.filter { spot in
            (query.isEmpty || [spot.name, spot.descrizione, spot.nazione, spot.categoria].contains { $0.localizedCaseInsensitiveContains(query) })
                && (filtroCategoria == "Tutte" || spot.categoria.uguale(filtroCategoria))
                && (filtroNazione == "Tutte" || spot.nazione.uguale(filtroNazione))
                && spot.valutazione >= votoMinimo
                && (!soloConFoto || !spot.fotoData.isEmpty)
        }
        switch (ordinamento, gestorePosizione.posizione) {
        case (.piuVicini, let pos?):
            return filtrati
                .map { (pos.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)), $0) }
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        case (.votoMigliore, _):
            return filtrati.sorted { ($0.valutazione, $0.dataCreazione) > ($1.valutazione, $1.dataCreazione) }
        case (.alfabetico, _):
            return filtrati.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        default:
            return filtrati
        }
    }

    var body: some View {
        NavigationStack {
            listaSpot
                .listStyle(.plain)
                .navigationTitle("I Miei Spot")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $testoRicerca, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca nome, note o nazione")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { menuFiltri } }
                .onChange(of: spots) { controllaFiltri() }
                .onAppear { gestorePosizione.avvia() }
                .onDisappear { gestorePosizione.ferma() }
                .alert(
                    spotDaEliminare.map { "Eliminare \"\($0.name)\"?" } ?? "Eliminare spot?",
                    isPresented: Binding(get: { spotDaEliminare != nil }, set: { if !$0 { spotDaEliminare = nil } }),
                    presenting: spotDaEliminare
                ) { spot in
                    Button("Annulla", role: .cancel) {}
                    Button("Elimina", role: .destructive) { eliminaSpot(spot) }
                } message: { _ in
                    Text("Foto e note verranno rimosse dal dispositivo. L'azione non è reversibile.")
                }
                .overlay { if spotsFiltrati.isEmpty { vistaVuota } }
        }
    }

    private var listaSpot: some View {
        List {
            if !spots.isEmpty {
                barraFiltri
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }
            ForEach(Dictionary(grouping: spotsFiltrati, by: \.nazione).sorted { $0.key < $1.key }, id: \.key) { nazione, lista in
                Section {
                    ForEach(lista) { spot in
                        RigaSpot(spot: spot, posizioneUtente: gestorePosizione.posizione)
                            .background(NavigationLink("", destination: Dettaglio(place: spot)).opacity(0))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Elimina", systemImage: "trash") { spotDaEliminare = spot }
                                    .tint(.red)
                            }
                    }
                } header: {
                    Text("\(nazione.uppercased()) · \(lista.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var barraFiltri: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChipFiltroSpot(titolo: "Tutte (\(spots.count))", icona: "tray.full.fill", attivo: filtroCategoria == "Tutte") {
                    filtroCategoria = "Tutte"
                }
                ForEach(categorieDisponibili, id: \.nome) { cat in
                    let attivo = filtroCategoria.uguale(cat.nome)
                    ChipFiltroSpot(titolo: "\(cat.nome) (\(cat.count))", icona: cat.icona, attivo: attivo) {
                        filtroCategoria = attivo ? "Tutte" : cat.nome
                    }
                }
                Divider().frame(height: 20)
                ChipFiltroSpot(titolo: "Con foto", icona: "photo.fill", attivo: soloConFoto) {
                    soloConFoto.toggle()
                }
                ChipFiltroSpot(titolo: "\(votoMinimo > 0 ? votoMinimo : 4)+ ★", icona: "star.fill", attivo: votoMinimo > 0) {
                    votoMinimo = votoMinimo > 0 ? 0 : 4
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
                    ForEach(OrdineSpot.allCases) { Label($0.rawValue, systemImage: $0.icona).tag($0) }
                }
            }
            Section("Filtra per Tipologia") {
                Picker("Tipologia", selection: $filtroCategoria) {
                    Text("Tutte (\(spots.count))").tag("Tutte")
                    ForEach(categorieDisponibili, id: \.nome) { Label("\($0.nome) (\($0.count))", systemImage: $0.icona).tag($0.nome) }
                }
            }
            if nazioniDisponibili.count > 1 {
                Section("Filtra per Nazione") {
                    Picker("Nazione", selection: $filtroNazione) {
                        Text("Tutte le nazioni").tag("Tutte")
                        ForEach(nazioniDisponibili, id: \.self) { Text($0).tag($0) }
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
                Toggle("Solo spot con foto", systemImage: "photo", isOn: $soloConFoto)
            }
            if haFiltriAttivi || ordinamento != .piuRecenti {
                Section {
                    Button("Reimposta filtri e ordine", systemImage: "arrow.counterclockwise", role: .destructive) {
                        withAnimation { reimpostaFiltri() }
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
            Label(spots.isEmpty ? "Nessuno spot salvato" : "Nessuno spot trovato", systemImage: "mappin.slash")
        } description: {
            Text(spots.isEmpty ? "Aggiungi il tuo primo posto dalla scheda Creazione Spot." : "Non ci sono spot corrispondenti ai filtri selezionati.")
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
        if !categorieDisponibili.contains(where: { $0.nome.uguale(filtroCategoria) }) { filtroCategoria = "Tutte" }
        if !nazioniDisponibili.contains(filtroNazione) { filtroNazione = "Tutte" }
    }

    private func reimpostaFiltri() {
        (filtroCategoria, filtroNazione, votoMinimo, soloConFoto, ordinamento) = ("Tutte", "Tutte", 0, false, .piuRecenti)
    }

    private func eliminaSpot(_ spot: FavoritePlaces) {
        withAnimation {
            modelContext.delete(spot)
            try? modelContext.save()
            NotificationCenter.default.post(name: .spotDidUpdate, object: nil)
        }
    }
}

struct ChipFiltroSpot: View {
    let titolo: String
    let icona: String
    let attivo: Bool
    let action: () -> Void

    var body: some View {
        Button { withAnimation(.snappy, action) } label: {
            HStack(spacing: 5) {
                Image(systemName: icona).font(.caption2)
                Text(titolo).font(.caption).fontWeight(attivo ? .semibold : .medium)
            }
            .foregroundStyle(attivo ? Color(.systemBackground) : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(attivo ? Color.primary : Color(.secondarySystemFill), in: Capsule())
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
            if let foto = spot.fotoData.first.flatMap(UIImage.init(data:)) {
                Button { mostraFotoFullScreen = true } label: {
                    Image(uiImage: foto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .fullScreenCover(isPresented: $mostraFotoFullScreen) {
                    VisualizzatoreFotoFullScreen(immagini: spot.fotoData.compactMap(UIImage.init(data:)), indiceIniziale: 0)
                }
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(spot.swiftUIColor.opacity(0.18))
                    .frame(width: 56, height: 56)
                    .overlay { Image(systemName: spot.icon).font(.title3).foregroundStyle(spot.swiftUIColor) }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(spot.name).font(.headline).lineLimit(1)
                    Spacer(minLength: 4)
                    if let posizioneUtente {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill").font(.caption2)
                            Text(spot.distanzaFormattata(da: posizioneUtente)).font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 6) {
                    Text(spot.categoria)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(spot.swiftUIColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(spot.swiftUIColor)
                    if spot.valutazione > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                            Text("\(spot.valutazione)").fontWeight(.medium)
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
