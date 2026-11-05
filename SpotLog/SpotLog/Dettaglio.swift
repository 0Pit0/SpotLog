import SwiftUI
import MapKit
import CoreLocation

struct Dettaglio: View {
    let place: FavoritePlaces
    @Environment(\.dismiss) private var dismiss

    // Stato per controllare la visibilità del foglio modale di modifica
    @State private var mostraModifica = false

    var body: some View {
        NavigationStack {
            List {
                Section() {
                    Map(initialPosition: .region(
                        MKCoordinateRegion(
                            center: place.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )) {
                        Marker(place.name, coordinate: place.coordinate)
                    }
                    .frame(height: 200)
                    .border(Color.gray, width: 1)
                    .cornerRadius(12)
                    
                    Text(place.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Italia - 12 Aug 2021 - Monumento")
                        .font(.caption)
                    
                    kmDaTe(place: place)
                    
                    HStack {
                        Button {
                            apriIndicazioni(lat: place.latitude, lon: place.longitude, nome: place.name)
                        } label: {
                            HStack {
                                Text("Indicazioni").bold().foregroundStyle(.white)
                                Image(systemName: "location.fill").foregroundStyle(.white)
                            }.padding(10)
                                .background(Color.blue, in: Capsule())
                                .cornerRadius(25)
                        }.buttonStyle(.borderless)
                        
                        Spacer()
                
                        Button {
                            print("Condividi")
                        } label: {
                            HStack {
                                Text("Condividi").bold()
                                Image(systemName: "square.and.arrow.up")
                            }.padding(10)
                                .background(Color.gray.opacity(0.3), in: Capsule())
                                .cornerRadius(25)
                        }.buttonStyle(.borderless)
                    }
                    Text(place.descrizione)
                    
                }

                Section("Opzioni") {
                    Button("Elimina") {
                        print("ELIMINARE")
                    }.foregroundStyle(.red)
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
    Dettaglio(place: FavoritePlaces(name: "Colosseo", icon: "home.fill", descrizione: "Bel posto molto antico e pieno di cose fantastiche", latitude: 41.8902, longitude: 12.4922))
}
