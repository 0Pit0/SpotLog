import SwiftUI
import MapKit
import CoreLocation

struct Dettaglio: View {
        let place: FavoritePlaces
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                List {
                    Section("Nome") {
                        Text(place.name)
                            .font(.headline)
                    }

                    Section("Posizione") {
                        Text("Latitudine: \(place.latitude)")
                        Text("Longitudine: \(place.longitude)")
                    }

                    Section("Mappa") {
                        Map(initialPosition: .region(
                            MKCoordinateRegion(
                                center: place.coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )) {
                            Marker(place.name, coordinate: place.coordinate)
                        }
                        .frame(height: 200)
                    }
                }
                .navigationTitle(place.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Chiudi") { dismiss() }
                    }
                }
            }
        }
    

}

#Preview {
    Dettaglio(place: FavoritePlaces(name: "Colosseo", icon: "home.fill", latitude: 41.8902, longitude: 12.4922))
}
