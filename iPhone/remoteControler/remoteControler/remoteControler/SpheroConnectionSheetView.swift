import SwiftUI

// Vue pour gérer la connexion aux Sphero
struct SpheroConnectionSheetView: View {
    @Binding var isSpheroConnected: Bool
    @Binding var connectionStatus: String
    @Binding var connectedSpheroNames: [String]
    @Binding var spheroMazeInfo: [String: BoltToy]  // Binding pour remonter l'info de la Sphero Maze


    var spheroNamesToConnect: [String] = ["SB-313C"]

    var body: some View {
        VStack {
            Text("Connect to Sphero")
                .font(.title)
                .padding()

            // Affichage du message de connexion
            if !connectionStatus.isEmpty {
                Text(connectionStatus)
                    .font(.headline)
                    .foregroundColor(isSpheroConnected ? .green : .red)
                    .padding()
            }

            // Bouton pour connecter toutes les Sphero
            Button("Connect to All Sphero") {
                connectToAllSphero()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            // Afficher les Sphero connectées
            Text("Connected Sphero:")
                .font(.headline)
                .padding(.top)
            ForEach(connectedSpheroNames, id: \.self) { name in
                Text(name)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
            }

            
            if let mazeSphero = spheroMazeInfo["SB-313C"] {
                            Text("Sphero Maze Info:")
                                .font(.headline)
                                .padding(.top)
                            Text("Name: \(mazeSphero.peripheral?.name ?? "Unknown")")
                                .padding()
                                .background(Color.yellow.opacity(0.2))
                                .cornerRadius(8)
                        }

            // Bouton de déconnexion
            Button("Disconnect All") {
                disconnectAllSphero()
            }
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)

            Spacer()
        }
        .padding()
    }

    // Fonction pour connecter toutes les Sphero
    private func connectToAllSphero() {
        connectionStatus = "Connecting to all Sphero..."
        SharedToyBox.instance.searchForBoltsNamed(spheroNamesToConnect) { error in
            if error == nil {
                isSpheroConnected = true
                connectionStatus = "Connected to all Sphero"
                connectedSpheroNames = SharedToyBox.instance.bolts.map { $0.peripheral?.name ?? "Unknown Sphero" }
                
                // Identifier et stocker la Sphero Maze dans le dictionnaire
                                if let mazeSphero = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == "SB-313C" }) {
                                    spheroMazeInfo["SB-313C"] = mazeSphero
                                } else {
                                    spheroMazeInfo["SB-313C"] = nil
                                }
            } else {
                isSpheroConnected = false
                connectionStatus = "Failed to connect to all Sphero"
            }
        }
    }

    private func disconnectAllSphero() {
        connectionStatus = "Disconnecting all Sphero..."
        SharedToyBox.instance.disconnectAllToys()
        isSpheroConnected = false
        connectionStatus = "All Sphero disconnected"
        connectedSpheroNames.removeAll()
        spheroMazeInfo.removeAll()  // Reset du dictionnaire de la Sphero Maze

    }
}
