import SwiftUI

struct CreazioneSpot: View {
    @State private var tipologia: Int
    @State private var nomeSpot: String
    @State private var noteViaggio: String
    @State private var nuovaTipologia: String
    @State private var iconColor: Color

    init(tipologia: Int = 0,
         nomeSpot: String = "",
         noteViaggio: String = "",
         nuovaTipologia: String = "",
         iconColor: Color = .blue) {
        _tipologia = State(initialValue: tipologia)
        _nomeSpot = State(initialValue: nomeSpot)
        _noteViaggio = State(initialValue: noteViaggio)
        _nuovaTipologia = State(initialValue: nuovaTipologia)
        _iconColor = State(initialValue: iconColor)
    }

    var body: some View {
        Text("Creazione Spot").font(Font.largeTitle)
        //mettere mappa
        
        Form {
            Section("Icona") {
                Picker("Icona", selection: $tipologia) {
                    Image(systemName: "mountain.2").tag(0)
                    Image(systemName: "building.columns").tag(1)
                    Image(systemName: "tree").tag(2)
                    Image(systemName: "fork.knife").tag(3)
                    Image(systemName: "book").tag(4)
                    Image(systemName: "water.waves").tag(5)
                    Image(systemName: "party.popper").tag(6)
                    Image(systemName: "cart").tag(7)
                    Image(systemName: "star").tag(8)
                }
                .pickerStyle(.menu)
                .tint(iconColor)
            }

            Section("Dettagli") {
                TextField("Nome spot", text: $nomeSpot)
                TextField("Note viaggio", text: $noteViaggio, axis: .vertical)
                TextField("Nuova tipologia", text: $nuovaTipologia)
                ColorPicker("Colore icona", selection: $iconColor)
            }
        }
        .navigationTitle("Crea Spot")
    }
}
