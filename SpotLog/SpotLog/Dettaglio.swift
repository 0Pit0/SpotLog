import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import UIKit

struct Dettaglio: View {
    let place: FavoritePlaces
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mostraModifica = false
    @State private var mostraConfermaEliminazione = false

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
                        Marker(place.name, systemImage: place.icon, coordinate: place.coordinate)
                            .tint(place.swiftUIColor)
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    
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
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 95)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
