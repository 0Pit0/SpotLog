import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import UIKit

// Identificatore per aprire la galleria a tutto schermo sull'immagine toccata
struct FotoSelezionata: Identifiable {
    let id = UUID()
    let indiceIniziale: Int
}

struct Dettaglio: View {
    @Bindable var place: FavoritePlaces
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mostraModifica = false
    @State private var mostraConfermaEliminazione = false
    @State private var fotoSelezionata: FotoSelezionata? = nil
    
    // Ogni volta che aumenta, la mappa viene ricreata e torna alla initialPosition (lo spot)
    @State private var contatoreCentra = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: place.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )) {
                        UserAnnotation()

                        Marker(place.name, systemImage: place.icon, coordinate: place.coordinate)
                            .tint(place.swiftUIColor)
                    }
                    // Forza il ridisegno del Marker dopo la modifica
                    // e ricentra sullo spot quando premo il pulsante
                    .id("\(place.markerID)-\(contatoreCentra)")
                    // Pulsante in alto a destra che riporta la mappa sullo spot
                    .overlay(alignment: .topTrailing) {
                        Button {
                            contatoreCentra += 1
                        } label: {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    ).mapStyle(.imagery)
                    
                    Text(place.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("\(place.nazione) · \(place.dataCreazione.formatted(date: .abbreviated, time: .omitted)) · \(place.categoria)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        kmDaTe(place: place)
                        
                        if place.valutazione > 0 {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= place.valutazione ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundStyle(star <= place.valutazione ? .yellow : .secondary.opacity(0.4))
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Button {
                            apriIndicazioni(lat: place.latitude, lon: place.longitude, nome: place.name)
                        } label: {
                            HStack {
                                Text("Indicazioni").bold().foregroundStyle(.white)
                                Image(systemName: "location.fill").foregroundStyle(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.blue, in: Capsule())
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                
                        ShareLink(
                            item: "\(place.name) (\(place.categoria)) - https://maps.apple.com/?ll=\(place.latitude),\(place.longitude)"
                        ) {
                            HStack {
                                Text("Condividi").bold()
                                Image(systemName: "square.and.arrow.up")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    if !place.fotoData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(place.fotoData.indices, id: \.self) { idx in
                                    if let uiImage = UIImage(data: place.fotoData[idx]) {
                                        Button {
                                            fotoSelezionata = FotoSelezionata(indiceIniziale: idx)
                                        } label: {
                                            Image(uiImage: uiImage)
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
                            .font(.body)
                    }
                }

                Section("Opzioni") {
                    Button(role: .destructive) {
                        mostraConfermaEliminazione = true
                    } label: {
                        Label("Elimina spot", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(place.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Modifica") {
                        mostraModifica = true
                    }
                }
            }
            .sheet(isPresented: $mostraModifica) {
                ModificaSpot(place: place)
            }
            .fullScreenCover(item: $fotoSelezionata) { selezione in
                VisualizzatoreFotoFullScreen(
                    immagini: place.fotoData.compactMap { UIImage(data: $0) },
                    indiceIniziale: selezione.indiceIniziale
                )
            }
            .alert("Eliminare \"\(place.name)\"?", isPresented: $mostraConfermaEliminazione) {
                Button("Annulla", role: .cancel) { }
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

// MARK: - Visualizzatore Foto a Schermo Intero (Swipe + Zoom + Chiusura)
struct VisualizzatoreFotoFullScreen: View {
    let immagini: [UIImage]
    @State private var indiceCorrente: Int
    @Environment(\.dismiss) private var dismiss

    init(immagini: [UIImage], indiceIniziale: Int) {
        self.immagini = immagini
        _indiceCorrente = State(initialValue: indiceIniziale)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $indiceCorrente) {
                ForEach(immagini.indices, id: \.self) { index in
                    ImmagineZoomabile(image: immagini[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: immagini.count > 1 ? .always : .never))
            .ignoresSafeArea()

            // Barra superiore con contatore e pulsante di chiusura
            HStack {
                if immagini.count > 1 {
                    Text("\(indiceCorrente + 1) / \(immagini.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .white.opacity(0.25))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
}

// MARK: - Singola Immagine con supporto Pinch-to-Zoom e Doppio Tap
struct ImmagineZoomabile: View {
    let image: UIImage
    @State private var scala: CGFloat = 1.0
    @State private var ultimaScala: CGFloat = 1.0

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scala)
            .gesture(
                MagnificationGesture()
                    .onChanged { valore in
                        let delta = valore / ultimaScala
                        ultimaScala = valore
                        scala = min(max(scala * delta, 1.0), 4.0)
                    }
                    .onEnded { _ in
                        ultimaScala = 1.0
                        if scala < 1.05 {
                            withAnimation(.spring()) {
                                scala = 1.0
                            }
                        }
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring()) {
                    scala = (scala > 1.0) ? 1.0 : 2.5
                }
            }
    }
}

func apriIndicazioni(lat: Double, lon: Double, nome: String) {
    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    mapItem.name = nome
    mapItem.openInMaps(launchOptions: [
        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
    ])
}

struct kmDaTe: View {
    var place: FavoritePlaces
    @StateObject private var gestore = GestorePosizione()

    var body: some View {
        HStack {
            Image(systemName: "location.circle.fill")
                .foregroundStyle(.blue)
            testoDistanza
                .font(.caption)
            Spacer()
        }
        .onAppear { gestore.avvia() }
        .onDisappear { gestore.ferma() }
    }

    @ViewBuilder
    private var testoDistanza: some View {
        switch gestore.autorizzazione {
        case .denied, .restricted:
            Text("Posizione non disponibile")
                .foregroundStyle(.secondary)
        default:
            if let posizione = gestore.posizione {
                Text("\(place.distanzaFormattata(da: posizione)) da te")
            } else {
                Text("Calcolo distanza…")
                    .foregroundStyle(.secondary)
            }
        }
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
