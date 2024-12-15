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
                        isSpheroConnected: $isSpheroConnected
                    )
                )  {
                    Text("matrix led")
                        .padding()
                        .background(Color.green)
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
            }
            .navigationTitle("Remote Controller")
        }
        .sheet(isPresented: $showConnectSheet) {
            SpheroConnectionSheetView(
                isSpheroConnected: $isSpheroConnected,
                connectionStatus: $connectionStatus,
                connectedSpheroNames: $connectedSpheroNames
            )
        }
        .onAppear() {
            wsClient.connectForIdentification(route: IdentificationRoute.typhoonIphoneConnect)
        }
    }
    // Fonction pour générer les commandes de test
        private func generateCommands() -> [String] {
            return [
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
                "typhoon_iphone=>[typhoon_esp]=>sphero4#completed"
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
