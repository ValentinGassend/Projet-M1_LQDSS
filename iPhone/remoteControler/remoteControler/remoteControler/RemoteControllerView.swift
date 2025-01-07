import SwiftUI
import Foundation

class SpheroPresetManager {
    static let shared = SpheroPresetManager()

    private let lightningPreset = [
        [false, false, false, false, false, false, false, false],
        [false, false, false, false, true,  true,  true,  false],
        [false, false, false, true,  true,  true,  false, false],
        [false, false, true,  true,  true,  false, false, false],
        [false, true,  true,  true,  true,  true,  false, false],
        [false, false, false, true,  true,  false, false, false],
        [false, false, true,  true,  false, false, false, false],
        [false, true,  false, false, false, false, false, false],
    ]

    func sendLightningPreset(to sphero: BoltToy) {
//        print("Envoi du preset Lightning au Sphero \(sphero.name ?? "Inconnu")")

        // Efface la matrice
        for x in 0..<8 {
            for y in 0..<8 {
                sphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .black)
            }
        }

        // Applique le preset
        for x in 0..<8 {
            for y in 0..<8 where lightningPreset[x][y] {
                sphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .yellow)
            }
        }

//        print("Preset Lightning envoyé au Sphero \(sphero.name ?? "Inconnu")")
    }
}

// Vue principale
struct RemoteControllerView: View {
    @State private var selectedSpheroName: String?
    @ObservedObject var wsClient = WebSocketClient.instance
    @StateObject private var roleManager = SpheroRoleManager()
    @State private var showConnectSheet = false
    @State private var isSpheroConnected = false
    @State private var isDefaultSpheroConnected = false
    @State private var isTyphoonSpheroConnected = false
    @State private var connectedSpheroNames: [String] = []
    @State private var connectionStatus: String = ""
    @State private var showMazeIcon: Bool = false
    @State private var spheroMazeInfo: [String: BoltToy] = [:]


    var body: some View {
        NavigationStack {
            ScrollView {
                Spacer()
                if !connectedSpheroNames.isEmpty {
                                    VStack {
                                        Text("Connected Spheros")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .padding(.bottom)
                                        
                                        ForEach(SpheroRole.allCases.filter { $0 != .unassigned }, id: \.self) { role in
                                            if let assignment = roleManager.getRoleAssignment(for: role) {
                                                HStack {
                                                    Text(role.rawValue)
                                                        .fontWeight(.medium)
                                                    Spacer()
                                                    Text(assignment.spheroName)
                                                        .foregroundColor(.blue)
                                                    
                                                Spacer()
                                                    Button("Envoyer l'Éclair") {
                                                        if let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == assignment.spheroName }) {
                                                            SpheroPresetManager.shared.sendLightningPreset(to: toy)
                                                        } else {
                                                            print("Aucun Sphero sélectionné ou introuvable.")
                                                        }
                                                    }
                                                    Button("stabiliser") {
                                                        if let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == assignment.spheroName }) {
                                                            toy.setStabilization(state: .on)
                                                        } else {
                                                            print("Aucun Sphero sélectionné ou introuvable.")
                                                        }
                                                    }
                                                    Button("destabiliser") {
                                                        if let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == assignment.spheroName }) {
                                                            toy.setStabilization(state: .off)
                                                        } else {
                                                            print("Aucun Sphero sélectionné ou introuvable.")
                                                        }
                                                    }
                                                }
                                                .padding()
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(8)
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                    .padding(.bottom)
                                }
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
                        spheroMazeInfo: $spheroMazeInfo,
                        roleManager: roleManager // Passage du roleManager
                    )
                }
        .onAppear() {
            wsClient.connectForIdentification(route: IdentificationRoute.typhoonIphoneConnect)
            wsClient.connectForIdentification(route: IdentificationRoute.mazeIphoneConnect)
        }
        
        .onDisappear() {
            wsClient.disconnect(route: "mazeIphoneConnect")
            wsClient.disconnect(route: "typhoonIphoneConnect")
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
            // Messages du Volcan (volcano_esp1)
            "volcano_esp1=>[volcano_esp1,volcano_esp2]=>rfid#volcano",
            "volcano_esp1=>[volcano_esp1,volcano_esp2 crystal_esp2,crystal_esp1]=>rfid#first",
            "volcano_esp1=>[volcano_esp2]=>relay1#true",
            "volcano_esp1=>[volcano_esp2]=>relay1#false",
            "volcano_esp1=>[volcano_esp2]=>relay2#true",
            "volcano_esp1=>[volcano_esp2]=>relay2#false",
            "volcano_esp1=>[volcano_esp2]=>relay1#true",
            
            // Messages du Volcan (volcano_esp2)
            "volcano_esp2=>[volcano_esp1]=>rfid#second",
            "volcano_esp2=>[volcano_esp1]=>rfid#third",
            
            // Messages du Typhon (typhon_esp)
            "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>rfid#typhoon",
            "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay1#true",
            "typhon_esp=>[typhoon_iphone]=>relay1#false",
            "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay2#true",
            "typhon_esp=>[typhoon_iphone]=>relay2#false",
            "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay3#true",
            "typhon_esp=>[typhoon_iphone]=>relay3#false",
            "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay4#true",
            "typhon_esp=>[typhoon_iphone]=>relay4#false",
            "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>rfid#typhoon",
            "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>rfid#typhoon",
            
            // Messages de l'iPhone Typhon (typhoon_iphone)
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
            
            // Messages de la Tornade (tornado_esp)
            "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>rfid#tornado",
            "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic1#true",
            "tornado_esp=>[tornado_rpi]=>mic1#false",
            "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic2#true",
            "tornado_esp=>[tornado_rpi]=>mic2#false",
            "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic3#true",
            "tornado_esp=>[tornado_rpi]=>mic3#false",
            "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic4#true",
            "tornado_esp=>[tornado_rpi]=>mic4#false",
            "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>rfid#tornado",
            "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>rfid#tornado",
            
            // Messages du RPI Tornade (tornado_rpi)
            "tornado_rpi=>[tornado_esp]=>rvr#first",
            "tornado_rpi=>[tornado_esp]=>rvr#second",
            "tornado_rpi=>[tornado_esp]=>rvr#third",
            "tornado_rpi=>[tornado_esp]=>rvr#fourth",
            
            // Messages du Labyrinthe (maze_esp)
            "maze_esp=>[maze_esp,maze_iphone,ambianceManager_rpi]=>rfid#maze",
            "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn1#true",
            "maze_esp=>[maze_iphone]=>btn1#false",
            "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn2#true",
            "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn3#true",
            "maze_esp=>[maze_iphone,ambianceManager_rpi]=>rfid#maze",
            "maze_esp=>[maze_iphone,ambianceManager_rpi]=>rfid#maze",
            "maze_esp=>[maze_iphone,ambianceManager_rpi]=>rfid#maze",
            
            // Messages du Crystal (crystal_esp1)
            "crystal_esp1=>[crystal_esp2,crystal_esp1,ambianceManager_rpi]=>rfid#volcano",
            "crystal_esp1=>[crystal_esp2,crystal_esp1,ambianceManager_rpi]=>rfid#maze",
            
            // Messages du Crystal (crystal_esp2)
            "crystal_esp2=>[crystal_esp2,crystal_esp1,AmbianceManager_rpi]=>crystal_start_animation",
            "crystal_esp2=>[crystal_esp2,crystal_esp1,ambianceManager_rpi]=>rfid#tornado",
            "crystal_esp2=>[crystal_esp2,crystal_esp1,ambianceManager_rpi]=>rfid#typhoon"
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
