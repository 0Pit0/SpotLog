# 📍 SpotLog

Applicazione nativa **iOS** per salvare, organizzare e ritrovare su mappa i propri luoghi del cuore ("spot"): panorami, monumenti, ristoranti, spiagge e qualsiasi posto valga la pena ricordare, con foto, note e valutazione.

Progetto di gruppo per il corso di Progettazione e Sviluppo iOS (Secondo Anno - Software Architect) presso l'ITS Angelo Rizzoli.

| | |
|---|---|
| **Team** | Andrea Biscaldi, Lorenzo Cenderelli, Federico Chiappa, Pietro Gallo, Thomas Palomba |
| **Piattaforma** | iOS / iPadOS 18+ · Swift · SwiftUI |
| **Lingue** | Italiano (lingua base) · Inglese |

---

## 1. Visione del progetto

L'obiettivo è offrire un diario di viaggio personale basato sulla posizione: l'utente salva un punto sulla mappa (dove si trova o dove tocca), gli assegna una tipologia, un colore, delle foto, delle note e un voto, e può poi ritrovarlo, filtrarlo e raggiungerlo in qualsiasi momento.

L'app **non necessita di un backend proprietario** e funziona **interamente in locale**:

- tutti gli spot, foto comprese, sono salvati sul dispositivo con **SwiftData**, quindi restano consultabili anche offline;
- usa **MapKit** per la mappa interattiva e **CoreLocation** per la posizione dell'utente e il calcolo delle distanze;
- ricava automaticamente la nazione dello spot tramite reverse geocoding (`CLGeocoder`).

---

## 2. Funzionalità principali

1. 🗺️ **Mappa degli spot**: tutti i luoghi salvati come marker colorati con l'icona della loro tipologia, centrata sulla posizione dell'utente. Include ricerca testuale (nome, note, nazione), filtri rapidi per tipologia e scelta dello stile mappa (Standard, Ibrida, Satellite), che viene ricordata tra un avvio e l'altro.
2. ➕ **Creazione spot**: il segnalino parte dalla posizione attuale e si sposta toccando la mappa (gli altri spot restano visibili in grigio come riferimento). Per ogni spot si impostano:
   - nome e note di viaggio;
   - tipologia predefinita (Panorama, Monumento, Natura, Ristoro, Cultura, Spiaggia, Divertimento, Shopping) oppure una **tipologia personalizzata**, riutilizzabile negli spot successivi;
   - colore del marker;
   - foto dalla libreria (`PhotosPicker`);
   - valutazione da 1 a 5 stelle.
3. 📖 **Scheda dettaglio**: mini-mappa satellitare, nazione, data di creazione, tipologia, voto, **distanza da te** in tempo reale, galleria foto a schermo intero con zoom, pulsante **Indicazioni** (apre Apple Mappe in modalità navigazione) e **Condividi** (link Apple Maps tramite `ShareLink`).
4. ✏️ **Modifica ed eliminazione**: ogni spot può essere modificato (posizione compresa) o eliminato, con richiesta di conferma.
5. 📋 **I Miei Spot**: elenco raggruppato per nazione, con ricerca, filtri (tipologia, nazione, voto minimo, solo con foto), ordinamento (più recenti, più vicini a te, voto più alto, A-Z) ed eliminazione con swipe.
6. 🌐 **Localizzazione**: interfaccia disponibile in italiano e inglese tramite String Catalog (`.xcstrings`).

---

## 3. Architettura e tech stack

- **Linguaggio**: Swift 5
- **UI framework**: SwiftUI (`TabView` con `Tab`, `NavigationStack`, `List`, `Form`, `Map`, `.searchable`, `.sheet`, `.fullScreenCover`, `ContentUnavailableView`)
- **Persistenza locale**: SwiftData (`@Model`, `@Query`, `ModelContainer`, `modelContext`); le foto sono salvate con `@Attribute(.externalStorage)`
- **Mappe e GPS**: MapKit (`Map`, `Marker`, `UserAnnotation`, `MapReader`, `MKMapItem`), CoreLocation (`CLLocationManager`, `CLGeocoder`)
- **Media**: PhotosUI (`PhotosPicker`)
- **Preferenze**: `@AppStorage` per lo stile della mappa
- **Localizzazione**: String Catalog (`Localizable.xcstrings`, `InfoPlist.xcstrings`)
- **Test**: Swift Testing (unit test) e XCTest (UI test)
- **IDE**: Xcode

L'architettura segue l'approccio nativo di SwiftUI + SwiftData: le view leggono i dati direttamente con `@Query` e scrivono tramite il `modelContext`, mentre la logica condivisa è separata in componenti riutilizzabili:

- `FavoritePlaces`: modello SwiftData dello spot;
- `DatiSpot`: struttura che contiene lo stato del form, condivisa tra creazione e modifica;
- `CampiSpot` e `SelettorePosizioneSpot`: sezioni del form e mappa di selezione riutilizzate in entrambe le schermate;
- `LocationManager` / `GestorePosizione`: classi `ObservableObject` che incapsulano CoreLocation.

---

## 4. Copertura del programma di corso

Il progetto copre i moduli didattici previsti dal programma d'esame (escluso il modulo 15 su AR).

| Modulo | Argomento | Implementazione nel progetto |
|---|---|---|
| 1-3 | Fondamenti e Swift | `struct`, `class`, `enum` con `rawValue`, optional, extension, closure, concorrenza (`async/await`, `Task`, `@MainActor`) |
| 4 | Protocolli | `Identifiable`, `CaseIterable`, `Hashable`, `ObservableObject`, `CLLocationManagerDelegate`, `View` |
| 5 | Framework | Foundation, SwiftUI, SwiftData, MapKit, CoreLocation, PhotosUI |
| 6-9 | SwiftUI e navigazione | `TabView`, `NavigationStack`, `List`, `Form`, `Menu`, `Picker`, `@State`, `@Binding`, `@StateObject`, `@FocusState`, `@AppStorage` |
| 7 | Ciclo di vita | Avvio e arresto degli aggiornamenti GPS con `onAppear` / `onDisappear`, gestione dei cambi di autorizzazione |
| 10 | Persistenza dati | Modello SwiftData `FavoritePlaces` per salvataggio, modifica ed eliminazione offline |
| 11-13 | WebService e servizi di rete | Reverse geocoding asincrono con `CLGeocoder` per ricavare la nazione dello spot |
| 14 | Mappe e localizzazione | Mappa interattiva con MapKit, selezione del punto al tocco, posizione utente e distanze con CoreLocation, indicazioni stradali con Apple Mappe |
| 16 | Release e pubblicazione | Permesso `NSLocationWhenInUseUsageDescription` localizzato, localizzazione IT/EN, archivio Xcode |

---

## 5. Struttura del progetto

```
SpotLog/
├── Localizable.xcstrings          # Stringhe dell'interfaccia (IT/EN)
├── SpotLog.xcodeproj
├── SpotLog/
│   ├── SpotLogApp.swift           # Entry point e ModelContainer SwiftData
│   ├── HomePage.swift             # TabView, mappa principale, modello FavoritePlaces, LocationManager, extension di utilità
│   ├── CreazioneSpot.swift        # Schermata di creazione, tipologie, form condiviso e selettore di posizione
│   ├── ModificaSpot.swift         # Schermata di modifica di uno spot
│   ├── Dettaglio.swift            # Scheda dettaglio, mini-mappa, distanza e visualizzatore foto
│   ├── MieiSpot.swift             # Elenco spot con ricerca, filtri e ordinamento
│   ├── GestorePosizione.swift     # Gestione della posizione per distanze e ordinamento
│   ├── InfoPlist.xcstrings        # Testo localizzato del permesso di posizione
│   └── Assets.xcassets
├── SpotLogTests/                  # Unit test (Swift Testing)
└── SpotLogUITests/                # UI test (XCTest)
```

Ogni schermata vive in un file separato, per ridurre al minimo i conflitti Git.

---

## 6. Installazione e requisiti

### Requisiti

- macOS con **Xcode 16** o superiore
- Simulatore o dispositivo con **iOS 18.0+**

### Setup

1. Clona il repository:
   ```bash
   git clone https://github.com/0Pit0/SpotLog.git
   ```
2. Apri il file `SpotLog/SpotLog.xcodeproj` in Xcode.
3. Seleziona un simulatore iOS (es. iPhone 16) e premi **Cmd + R** per avviare l'applicazione.
4. Al primo avvio concedi l'accesso alla posizione. Sul simulatore puoi impostarne una da **Features → Location**.

> L'app non usa API esterne né chiavi di accesso: tutti i dati restano sul dispositivo.

### Note sul versionamento Git

> ⚠️ **Gestione dei file di sistema**: il repository **non accetta file `.DS_Store`**, già esclusi dal `.gitignore` insieme a `xcuserdata/`, `DerivedData/` e `build/`. Controlla di non includerli prima di effettuare commit o push.

---

## 7. Piano di lavoro incrementale

Il progetto segue una strategia di sviluppo incrementale a **Milestone**, sincronizzata con il programma delle lezioni in aula.

| Milestone | Contenuto |
|---|---|
| **1 · UI e navigazione** | Struttura a schede (`TabView`), mappa principale, form di creazione ed elenco spot |
| **2 · Persistenza** | Modello SwiftData `FavoritePlaces`, salvataggio, modifica ed eliminazione degli spot, foto |
| **3 · MapKit e GPS** | Posizione utente, selezione del punto sulla mappa, distanze, indicazioni e reverse geocoding |
| **4 · Rifinitura** | Ricerca, filtri e ordinamenti, tipologie personalizzate, condivisione, localizzazione IT/EN |

---

## 8. Credits

|  |
|---|
| [Andrea Biscaldi](https://www.linkedin.com/in/andreabiscaldi/) |
| [Lorenzo Cenderelli](https://www.linkedin.com/in/lorenzo-cende/) |
| [Federico Chiappa](https://www.linkedin.com/in/federico-chiappa/) |
| [Pietro Gallo](https://www.linkedin.com/in/pietro-gallo-pit) |
| [Thomas Palomba](https://www.linkedin.com/in/thomas-palomba/) |
