import SwiftUI

// Vue pour gérer la connexion aux Sphero
struct SpheroConnectionSheetView: View {
    @Binding var isSpheroConnected: Bool // Binding pour indiquer l'état de la connexion
    @Binding var connectionStatus: String // Binding pour afficher le statut de connexion

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
                connectSphero(named: "SB-8630")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)

            // Button to connect to Bottled Sphero
            Button("Connect to Bottled Sphero") {
                connectSphero(named: "SB-313C")
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
    private func connectSphero(named name: String) {
        connectionStatus = "Connecting to \(name)..."
        DispatchQueue.main.async {
            SharedToyBox.instance.searchForBoltsNamed([name]) { err in
                if err == nil {
                    print("Connected to \(name)")
                    isSpheroConnected = true
                    connectionStatus = "Connected to \(name)"
                } else {
                    print("Failed to connect to \(name)")
                    isSpheroConnected = false
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
                connectionStatus = "Disconnected"
            }
        }
}
