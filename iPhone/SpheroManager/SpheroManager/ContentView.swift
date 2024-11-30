import SwiftUI

// Vue principale
struct ContentView: View {
    @State private var showConnectSheet = false // Contrôle l'affichage de la feuille
    @State private var isSpheroConnected = false // Indique si une Sphero est connectée
    @State private var connectedSpheroNames: [String] = [] 
    @State private var connectionStatus: String = "" // Statut de la connexion

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                NavigationLink(destination: SpheroToWsServerView()) {
                    Text("Go to SpheroToWsServerView")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()

                NavigationLink(destination: SpheroSensorControlView()) {
                    Text("Go to SpheroSensorControlViewController")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()
                NavigationLink(destination: MatrixLedView(isSpheroConnected: $isSpheroConnected)) {
                    Text("Go to Matrix led view")
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()
                NavigationLink(destination: SpheroDirectionView(isSpheroConnected: $isSpheroConnected, connectedSpheroNames:$connectedSpheroNames)) {
                    Text("Go to Direction view")
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                }

                Spacer()

                // Bouton pour ouvrir la feuille de connexion
                Button(action: {
                    showConnectSheet = true
                }) {
                    Text(isSpheroConnected ? "Reconnect to Sphero" : "Connect to Sphero")
                        .padding()
                        .background(isSpheroConnected ? Color.orange : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()
            }
            .navigationTitle("Sphero Manager")
        }
        .sheet(isPresented: $showConnectSheet) {
            SpheroConnectionSheetView(
                isSpheroConnected: $isSpheroConnected,
                connectionStatus: $connectionStatus,
                connectedSpheroNames: $connectedSpheroNames
            )
        }
    }
}
