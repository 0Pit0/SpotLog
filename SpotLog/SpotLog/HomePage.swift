import SwiftUI

struct Pagina: View {
    @State private var searchText: String = ""

    var body: some View {
        
        VStack {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("cerca nei tuoi posti", text: $searchText)
                Button(action: {
                    print("Hamburger")
                }) {
                    Image(systemName: "line.3.horizontal")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
            }
            .padding(5)
            .background(.white)
            .cornerRadius(10)
            .padding(5)
            
            HStack{
                Button("Explore"){
                    
                }
            }
        }.background(Color.gray)
    }
}

#Preview {
    HomePage()
}

struct HomePage: View {
    var body: some View {
        TabView {
            Pagina()
                .tabItem { Label("Home", systemImage: "person.fill") }
            CreazioneSpot()
                .tabItem {
                    Image(systemName: "plus")
                }
            Preferiti()
                .tabItem { Label("Preferiti", systemImage: "star.fill") }
        }
    }
}

