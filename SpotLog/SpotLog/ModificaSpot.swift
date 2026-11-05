import SwiftUI
import MapKit
import PhotosUI

struct ModificaSpot: View {
    let place: FavoritePlaces
    @Environment(\.dismiss) private var dismiss

    @State private var tipologia: TipologiaSpot = .panorama
    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var nuovaTipologia: String = ""
    @State private var iconColor: Color = .blue
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var valutazione: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
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
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Stile Spot") {
                    LabeledContent("Icona") {
                        Menu {
                            Picker("", selection: $tipologia) {
                                ForEach(TipologiaSpot.allCases) { tipo in
                                    Label(tipo.titolo, systemImage: tipo.icona)
                                        .tag(tipo)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(tipologia.titolo)
                                Image(systemName: tipologia.icona)
                            }
                        }
                    }
                    .tint(iconColor)

                    if tipologia == .nuovaTipologia {
                        TextField("Nuova tipologia", text: $nuovaTipologia)
                    }

                    ColorPicker("Colore", selection: $iconColor)
                }

                Section("Dettagli") {
                    TextField("Nome spot", text: $nomeSpot)
                    TextField("Note viaggio", text: $noteViaggio, axis: .vertical)
                }

                Section("Foto Spot") {
                    if !loadedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0..<loadedImages.count, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: loadedImages[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Button {
                                            loadedImages.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .red)
                                        }
                                        .offset(x: 4, y: -4)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    PhotosPicker(
                        selection: $selectedItems,
                        matching: .images
                    ) {
                        Label("Aggiungi Foto", systemImage: "photo.badge.plus")
                    }
                }

                Section("Valutazione") {
                    LabeledContent("Voto") {
                        StarRatingView(rating: $valutazione)
                    }
                }
            }
            .navigationTitle("Modifica Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        // Logica di salvataggio delle modifiche
                        dismiss()
                    }
                }
            }
            .onAppear {
                nomeSpot = place.name
                noteViaggio = place.descrizione
            }
        }
    }
}

#Preview {
    ModificaSpot(place: FavoritePlaces(name: "Colosseo", icon: "home.fill", descrizione: "Bel posto molto antico e pieno di cose fantastiche", latitude: 41.8902, longitude: 12.4922))
}
