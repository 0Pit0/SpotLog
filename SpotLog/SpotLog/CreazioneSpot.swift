import SwiftUI

struct CreazioneSpot: View {
    // Stati della view
    @State private var tipologia: Int
    @State private var nomeSpot: String
    @State private var noteViaggio: String
    @State private var nuovaTipologia: String
    @State private var iconColor: Color

    // Init per inizializzare gli @State
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
        Form {
            Section("Icona") {

                // A) Soluzione: mostra solo l’icona selezionata e apri un menu (Picker in stile .menu)
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
                .pickerStyle(.menu) // Mostra solo la selezione corrente come pulsante
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

// MARK: - Varianti alternative

// B) Mostrare solo l’icona selezionata e aprire un .sheet con Picker a ruota
private struct IconaSelezionataConSheet: View {
    @Binding var tipologia: Int
    @Binding var iconColor: Color
    @State private var showingPicker = false

    var body: some View {
        HStack {
            Text("Icona")
            Spacer()
            Image(systemName: iconName(for: tipologia))
                .foregroundStyle(iconColor)
                .font(.title2)
                .onTapGesture { showingPicker = true }
        }
        .sheet(isPresented: $showingPicker) {
            VStack {
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
                .pickerStyle(.wheel)
                .labelsHidden() // qui nasconde solo il titolo "Icona" dentro il foglio

                Button("Fatto") { showingPicker = false }
                    .padding(.top)
            }
            .padding()
        }
    }
}

// C) Menu personalizzato che mostra solo l’icona selezionata come label
private struct IconaSelezionataConMenu: View {
    @Binding var tipologia: Int
    @Binding var iconColor: Color

    var body: some View {
        HStack {
            Text("Icona")
            Spacer()
            Menu {
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
            } label: {
                Image(systemName: iconName(for: tipologia))
                    .foregroundStyle(iconColor)
                    .font(.title2)
            }
        }
    }
}

// MARK: - Utilità

private func iconName(for value: Int) -> String {
    switch value {
    case 0: return "mountain.2"
    case 1: return "building.columns"
    case 2: return "tree"
    case 3: return "fork.knife"
    case 4: return "book"
    case 5: return "water.waves"
    case 6: return "party.popper"
    case 7: return "cart"
    case 8: return "star"
    default: return "questionmark"
    }
}
