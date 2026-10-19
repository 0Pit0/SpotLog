import SwiftUI

struct CreazioneSpot: View {
    @State private var tipologia: Int = 0
    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var nuovaTipologia: String = ""
    @State private var iconColor = Color.blue
    var body: some View {
        VStack{
            HStack{
                Text("Tipologia:")
                Picker("Tipologia", selection: $tipologia) {
                    Text("Panorama").tag(0)
                    Text("Monumento").tag(1)
                    Text("Natura").tag(2)
                    Text("Ristoro").tag(3)
                    Text("Cultura").tag(4)
                    Text("Spiaggia").tag(5)
                    Text("Divertimento").tag(6)
                    Text("Shopping").tag(7)
                    Text("Nuova Tipologia").tag(8)
                }
                
            }
            if(tipologia == 8){
                TextField("Nome della tipologia", text: $nuovaTipologia).textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }
            TextField("Nome Dello Spot", text: $nomeSpot)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            TextField("Note sul viaggio", text: $noteViaggio)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            Section("Segnalino"){
                Picker("Icona", selection: $tipologia) {
                    Image(systemName: "mountain.2").tag(0)
                    Image(systemName: "fork.knife").tag(3)
                    Image(systemName: "building.columns").tag(1)
                    Image(systemName: "tree").tag(2)
                    Image(systemName: "book").tag(4)
                    Image(systemName: "water.waves").tag(5)
                    Image(systemName: "party.popper").tag(6)
                    Image(systemName: "cart").tag(7)
                    Image(systemName: "star").tag(8)
                }.pickerStyle(SegmentedPickerStyle()).padding(10)
                Picker("Colore", selection: $iconColor){
                    Image(systemName: "circle.fill")
                        .tag(Color.blue)
                }.pickerStyle(SegmentedPickerStyle()).padding(10)
            }
        }
    }
}

#Preview {
    CreazioneSpot()
}
