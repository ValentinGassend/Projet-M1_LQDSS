import SwiftUI

// Vue pour gérer la connexion aux Sphero
struct SpheroConnectionSheetView: View {
    @Binding var isSpheroConnected: Bool // Binding pour indiquer l'état de la connexion
    @Binding var isDefaultSpheroConnected: Bool
    @Binding var isTyphoonSpheroConnected: Bool
    @Binding var connectionStatus: String // Binding pour afficher le statut de connexion
    @Binding var connectedSpheroNames: [String] // Binding pour stocker le nom de la Sphero connectée

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

            // Button to connect to Default Sphero
            Button("Connect to Default Sphero") {
                connectSphero(named: "SB-8630", spheroId: "default")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            // Button to connect to Bottled Sphero
            Button("Connect to Bottled Sphero") {
                connectSphero(named: "SB-313C", spheroId: "bottled")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
            // Disconnect Button
                Button("Disconnect") {
                    disconnectSphero()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)

            Spacer()
        }
        .padding()
    }

    // Fonction pour se connecter à une Sphero spécifique
    private func connectSphero(named name: String, spheroId: String? = nil) {
        connectionStatus = "Connecting to \(name)..."
        DispatchQueue.main.async {
            SharedToyBox.instance.searchForBoltsNamed([name]) { err in
                if err == nil {
                    print("Connected to \(name)")
                    isSpheroConnected = true
                    isDefaultSpheroConnected = true
                    connectionStatus = "Connected to \(name)"
                    if let surname = spheroId {
                        connectedSpheroNames.append(surname)
                    }
                } else {
                    print("Failed to connect to \(name)")
                    isSpheroConnected = false
                    isTyphoonSpheroConnected = true
                    connectionStatus = "Failed to connect to \(name)"

                }
            }
        }
    }

    // Fonction pour se déconnecter de la Sphero
    private func disconnectSphero() {
            connectionStatus = "Disconnecting..."
            DispatchQueue.main.async {
                SharedToyBox.instance.disconnectAllToys() // Call the new method to disconnect all toys
                isSpheroConnected = false
                isDefaultSpheroConnected = false
                isTyphoonSpheroConnected = false
                connectionStatus = "Disconnected"
                connectedSpheroNames.removeAll()
            }
        }
}
