import SwiftUI

struct CreazioneSpot: View {
    @State private var tipologia: Int
    @State private var nomeSpot: String
    @State private var noteViaggio: String
    @State private var nuovaTipologia: String
    @State private var iconColor: Color
    private var elencoTipologie: [String] = {"Monumento", "Natura","Ristoro"}
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
        VStack{
            Text("Creazione Spot").font(Font.largeTitle)
                    
            //mettere mappa
                    
            Form {
                Section("Stile Spot") {
                    
                    Picker("Icona", selection: $tipologia) {
                        HStack{
                            Image(systemName: "mountain.2")
                            Text("Montagna")
                        }.tag(0)
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
                    if tipologia == 8 {
                        TextField("Nuova tipologia", text: $nuovaTipologia)
                    }
                    ColorPicker("Colore", selection: $iconColor)
                }
                Section("Dettagli") {
                    TextField("Nome spot", text: $nomeSpot)
                    TextField("Note viaggio", text: $noteViaggio, axis: .vertical)
                }
            }
        }
    }
}

struct CustomPick: View {
    let imageName: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: imageName)
            Text(text)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
    }
}

#Preview {
    CreazioneSpot(tipologia: 0, nomeSpot: "", noteViaggio: "", nuovaTipologia: "", iconColor: .blue)
}
