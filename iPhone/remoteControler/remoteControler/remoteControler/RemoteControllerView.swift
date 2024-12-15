import SwiftUI

// Vue principale
struct RemoteControllerView: View {
    @ObservedObject var wsClient = WebSocketClient.instance
    @State private var showConnectSheet = false // Contrôle l'affichage de la feuille
    @State private var isSpheroConnected = false // Indique si une Sphero est connectée
    @State private var isDefaultSpheroConnected = false
    @State private var isTyphoonSpheroConnected = false
    @State private var connectedSpheroNames: [String] = []
    @State private var connectionStatus: String = "" // Statut de la connexion
    @State private var showMazeIcon: Bool = false // Add state variable to bind to MatrixLedView
    @State private var spheroMazeInfo: [String: BoltToy] = [:] // Dictionnaire pour les informations de la Sphero Maze


    var body: some View {
        NavigationStack {
            ScrollView {
                Spacer()
                
                // title air
                //
                Text("Input")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
                NavigationLink(
                    destination: SpheroRotationDetectorView(
                        isSpheroConnected: $isSpheroConnected
                    )
                )  {
                    Text("Sphero callback")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Text("Output")
                
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
                NavigationLink(
                    destination: MatrixLedView(
                        showMazeIcon: $showMazeIcon,
                        spheroMazeInfo: $spheroMazeInfo
                    )
                )  {
                    Text("matrix led")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Button(action: {
                    showConnectSheet = true
                }) {
                    Text(
                        isSpheroConnected ? "Reconnect to Sphero" : "Connect to Sphero"
                    )
                    .padding()
                    .background(isSpheroConnected ? Color.orange : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                ForEach(generateCommands(), id: \.self) { command in
                                    Button(action: {
                                        sendMessage(command: command)
                                    }) {
                                        Text(command)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(8)
                                            .padding(.bottom, 5)
                                    }
                                }
                
                
                
                
            }
            .navigationTitle("Remote Controller")
        }
        .sheet(isPresented: $showConnectSheet) {
            SpheroConnectionSheetView(
                isSpheroConnected: $isSpheroConnected,
                connectionStatus: $connectionStatus,
                connectedSpheroNames: $connectedSpheroNames,
                spheroMazeInfo: $spheroMazeInfo // Passer spheroMazeInfo ici

            )
        }
        .onAppear() {
            wsClient.connectForIdentification(route: IdentificationRoute.typhoonIphoneConnect)
            wsClient.connectForIdentification(route: IdentificationRoute.mazeIphoneConnect)
        }
        .onChange(of: wsClient.isRFIDDetectedForMaze) { newValue in
            showMazeIcon = newValue
            
            // Si le RFID est détecté à true, envoyer automatiquement le symbole lightning
            if newValue {
                // Récupérer la vue MatrixLed et appeler sa méthode pour charger et envoyer le preset lightning
                loadLightningPresetAndSend()
            }
        }
    }
    // Nouvelle méthode privée pour charger et envoyer le preset lightning
    private func loadLightningPresetAndSend() {
        guard !spheroMazeInfo.isEmpty else {
            print("Pas de Sphero Maze connectée")
            return
        }
        
        // Charger le preset lightning
        let lightningPreset = [
            [false, false, false, false, false, false, false, false],
            [false, false, false, false, true,  true,  true,  false],
            [false, false, false, true,  true,  true,  false, false],
            [false, false, true,  true,  true,  false, false, false],
            [false, true,  true,  true,  true,  true,  false, false],
            [false, false, false, true,  true,  false, false, false],
            [false, false, true,  true,  false, false, false, false],
            [false, true,  false, false, false, false, false, false],
        ]
        
        // Trouver la Sphero Maze et lui envoyer la matrice
        if let mazeSphero = spheroMazeInfo["SB-313C"] {
            mazeSphero.setStabilization(state: .on)
            print("Envoi du preset lightning à la Sphero Maze")
            // Effacer d'abord la matrice
            for x in 0..<8 {
                for y in 0..<8 {
                    mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .black)
                }
            }
            
            // Dessiner le preset lightning
            for x in 0..<8 {
                for y in 0..<8 where lightningPreset[x][y] {
                    mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .yellow)
                }
            }
            
            print("Preset lightning envoyé à la Sphero Maze")
        }
    }
    // Fonction pour générer les commandes de test
    private func generateCommands() -> [String] {
        return [
            // Commandes existantes
            "typhoon_esp=>[typhoon_iphone]=>rfid#true",
            "typhoon_esp=>[typhoon_iphone]=>relay1#true",
            "typhoon_esp=>[typhoon_iphone]=>relay2#true",
            "typhoon_esp=>[typhoon_iphone]=>relay3#true",
            "typhoon_esp=>[typhoon_iphone]=>relay4#true",
            "typhoon_iphone=>[typhoon_iphone]=>sphero1#true",
            "typhoon_iphone=>[typhoon_esp]=>sphero1#true",
            "typhoon_iphone=>[typhoon_esp]=>sphero1#false",
            "typhoon_iphone=>[typhoon_esp]=>sphero1#completed",
            "typhoon_iphone=>[typhoon_esp]=>sphero2#true",
            "typhoon_iphone=>[typhoon_esp]=>sphero2#false",
            "typhoon_iphone=>[typhoon_esp]=>sphero2#completed",
            "typhoon_iphone=>[typhoon_esp]=>sphero3#true",
            "typhoon_iphone=>[typhoon_esp]=>sphero3#false",
            "typhoon_iphone=>[typhoon_esp]=>sphero3#completed",
            "typhoon_iphone=>[typhoon_esp]=>sphero4#true",
            "typhoon_iphone=>[typhoon_esp]=>sphero4#false",
            "typhoon_iphone=>[typhoon_esp]=>sphero4#completed",

            // Commandes supplémentaires
            "tornado_esp=>[tornado_rpi]=>rfid#true",
            "tornado_esp=>[tornado_rpi]=>mic1#true",
            "tornado_esp=>[tornado_rpi]=>mic1#false",
            "tornado_esp=>[tornado_rpi]=>mic2#true",
            "tornado_esp=>[tornado_rpi]=>mic2#false",
            "tornado_esp=>[tornado_rpi]=>mic3#true",
            "tornado_esp=>[tornado_rpi]=>mic3#false",
            "tornado_esp=>[tornado_rpi]=>mic4#true",
            "tornado_esp=>[tornado_rpi]=>mic4#false",
            "tornado_rpi=>[tornado_esp]=>rvr#first",
            "tornado_rpi=>[tornado_esp]=>rvr#second",
            "tornado_rpi=>[tornado_esp]=>rvr#third",
            "tornado_rpi=>[tornado_esp]=>rvr#fourth",

            "volcano_esp=>[volcano_esp2]=>rfid#fire",
            "volcano_esp=>[volcano_esp2]=>rfid#first",
            "volcano_esp2=>[volcano_esp2]=>rfid#second",
            "volcano_esp2=>[volcano_esp2]=>rfid#third",
            "volcano_esp2=>[volcano_esp2]=>relay1#true",
            "volcano_esp2=>[volcano_esp2]=>relay1#true",
            "volcano_esp2=>[volcano_esp2]=>relay2#true",
            "volcano_esp2=>[volcano_esp2]=>relay2#true",

            "maze_iphone=>[maze_iphone]=>rfid#true",
            "maze_esp=>[maze_iphone]=>rfid#true",
            "maze_esp=>[maze_iphone]=>btn1#true",
            "maze_esp=>[maze_iphone]=>btn1#false",
            "maze_esp=>[maze_iphone]=>btn2#true",
            "maze_esp=>[maze_iphone]=>btn3#true",

            "crystal_esp1=>[crystal_esp2, crystal_esp]=>rfid#first",
            "crystal_esp1=>[crystal_esp2, crystal_esp]=>rfid#second",
            "crystal_esp2=>[crystal_esp2, crystal_esp]=>rfid#third",
            "crystal_esp2=>[crystal_esp2, crystal_esp]=>rfid#fourth"
        ]
    }

        
        // Fonction pour envoyer le message via WebSocket
        private func sendMessage(command: String) {
           if let messageParsed = wsClient.parseMessage(command)
            {
               wsClient.sendMessage(from: messageParsed.routeOrigin, to: messageParsed.routeTargets, component: messageParsed.component, data: messageParsed.data)
           }
        }
}
