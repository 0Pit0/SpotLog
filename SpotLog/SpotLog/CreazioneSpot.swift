import SwiftUI

struct CreazioneSpot: View {
    @State private var tipologia: Int = 0
    @State private var nomeSpot: String = ""
    @State private var noteViaggio: String = ""
    @State private var nuovaTipologia: String = ""
    @State private var icona: String = "montagna"
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
                Picker("Icona", selection: $icona) {
                    Image(systemName: "mountain.2").tag("montagna")
                    Image(systemName: "fork.knife").tag( "ristorante")
                    Image(systemName: "glass").tag("bar")
                }.pickerStyle(SegmentedPickerStyle())
            }
        }
    }
}

#Preview {
    CreazioneSpot()
}
