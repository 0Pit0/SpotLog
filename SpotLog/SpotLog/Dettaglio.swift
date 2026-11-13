import SwiftUI
import SwiftData
import MapKit

struct FotoSelezionata: Identifiable {
    let id = UUID()
    let indiceIniziale: Int
}

struct Dettaglio: View {
    let place: FavoritePlaces
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var mostraModifica = false
    @State private var mostraConfermaEliminazione = false
    @State private var fotoSelezionata: FotoSelezionata?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MiniMappaSpot(titolo: place.name, icona: place.icon, colore: place.swiftUIColor, coordinate: place.coordinate)

                    Text(place.name).font(.title.bold())

                    Text("\(place.nazione) · \(place.dataCreazione.formatted(date: .abbreviated, time: .omitted)) · \(TipologiaSpot.nomeVisualizzato(categoria: place.categoria))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        DistanzaDaTe(place: place)
                        Spacer()
                        if place.valutazione > 0 {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { n in
                                    Image(systemName: n <= place.valutazione ? "star.fill" : "star")
                                        .foregroundStyle(n <= place.valutazione ? .yellow : .secondary.opacity(0.4))
                                }
                            }
                            .font(.caption)
                        }
                    }

                    HStack {
                        Button {
                            let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
                            item.name = place.name
                            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                        } label: {
                            HStack {
                                Text("Indicazioni").bold()
                                Image(systemName: "location.fill")
                            }
                            .foregroundStyle(.white)
                            .capsula(Color.blue)
                        }
                        Spacer()
                        ShareLink(item: "\(place.name) (\(TipologiaSpot.nomeVisualizzato(categoria: place.categoria))) - https://maps.apple.com/?ll=\(place.latitude),\(place.longitude)") {
                            HStack {
                                Text("Condividi").bold()
                                Image(systemName: "square.and.arrow.up")
                            }
                            .capsula(Color.secondary.opacity(0.2))
                        }
                    }
                    .buttonStyle(.borderless)

                    if !place.fotoData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(place.fotoData.indices, id: \.self) { idx in
                                    if let foto = UIImage(data: place.fotoData[idx]) {
                                        Button { fotoSelezionata = FotoSelezionata(indiceIniziale: idx) } label: {
                                            Image(uiImage: foto)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 95)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !place.descrizione.isEmpty {
                        Text(place.descrizione)
                    }
                }

                Section("Opzioni") {
                    Button("Elimina spot", systemImage: "trash", role: .destructive) { mostraConfermaEliminazione = true }
                }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Modifica") { mostraModifica = true }
                }
            }
            .sheet(isPresented: $mostraModifica) { ModificaSpot(place: place) }
            .fullScreenCover(item: $fotoSelezionata) {
                VisualizzatoreFotoFullScreen(immagini: place.fotoData.compactMap(UIImage.init(data:)), indiceIniziale: $0.indiceIniziale)
            }
            .alert("Eliminare \"\(place.name)\"?", isPresented: $mostraConfermaEliminazione) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina", role: .destructive) {
                    modelContext.delete(place)
                    try? modelContext.save()
                    dismiss()
                }
            } message: {
                Text("Foto e note verranno rimosse dal dispositivo. L'azione non è reversibile.")
            }
        }
    }
}

struct MiniMappaSpot: View {
    let titolo: String
    let icona: String
    let colore: Color
    let coordinate: CLLocationCoordinate2D
    @State private var contatoreCentra = 0

    var body: some View {
        Map(initialPosition: .region(.init(center: coordinate, span: .init(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
            UserAnnotation()
            Marker(titolo, systemImage: icona, coordinate: coordinate).tint(colore)
        }
        .mapStyle(.imagery)
        .id("\(titolo)-\(icona)-\(colore.toHex())-\(coordinate.latitude)-\(coordinate.longitude)-\(contatoreCentra)")
        .overlay(alignment: .topTrailing) {
            Button { contatoreCentra += 1 } label: {
                Image(systemName: "mappin")
                    .font(.title2)
                    .foregroundStyle(Color.primary)
                    .padding(8)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
    }
}

private struct DistanzaDaTe: View {
    let place: FavoritePlaces
    @StateObject private var gestore = GestorePosizione()

    var body: some View {
        let negata = [CLAuthorizationStatus.denied, .restricted].contains(gestore.autorizzazione)
        let distanza = negata ? nil : gestore.posizione.map { String(localized: "\(place.distanzaFormattata(da: $0)) da te") }
        HStack {
            Image(systemName: "location.circle.fill").foregroundStyle(.blue)
            Text(distanza ?? (negata ? String(localized: "Posizione non disponibile") : String(localized: "Calcolo distanza…")))
                .font(.caption)
                .foregroundStyle(distanza == nil ? .secondary : .primary)
        }
        .onAppear { gestore.avvia() }
        .onDisappear { gestore.ferma() }
    }
}

struct VisualizzatoreFotoFullScreen: View {
    let immagini: [UIImage]
    @State private var indiceCorrente: Int
    @Environment(\.dismiss) private var dismiss

    init(immagini: [UIImage], indiceIniziale: Int) {
        self.immagini = immagini
        _indiceCorrente = State(initialValue: indiceIniziale)
    }

    var body: some View {
        TabView(selection: $indiceCorrente) {
            ForEach(immagini.indices, id: \.self) { ImmagineZoomabile(image: immagini[$0]).tag($0) }
        }
        .tabViewStyle(.page(indexDisplayMode: immagini.count > 1 ? .always : .never))
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HStack {
                if immagini.count > 1 {
                    Text("\(indiceCorrente + 1) / \(immagini.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white, .white.opacity(0.25))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
}

private struct ImmagineZoomabile: View {
    let image: UIImage
    @State private var scala: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    private func limita(_ s: CGFloat) -> CGFloat { min(max(s, 1), 4) }

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(limita(scala * pinch))
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { valore, stato, _ in stato = valore.magnification }
                    .onEnded { valore in
                        let nuova = limita(scala * valore.magnification)
                        withAnimation(.spring) { scala = nuova < 1.05 ? 1 : nuova }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring) { scala = scala > 1 ? 1 : 2.5 }
            }
    }
}

private extension View {
    func capsula(_ sfondo: some ShapeStyle) -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(sfondo, in: Capsule())
    }
}

#Preview {
    Dettaglio(
        place: FavoritePlaces(
            name: "Colosseo",
            icon: "building.columns",
            descrizione: "Anfiteatro Flavio nel cuore di Roma.",
            categoria: "Monumento",
            colorHex: "#FF9500",
            latitude: 41.8902,
            longitude: 12.4922
        )
    )
    .modelContainer(for: FavoritePlaces.self, inMemory: true)
}
