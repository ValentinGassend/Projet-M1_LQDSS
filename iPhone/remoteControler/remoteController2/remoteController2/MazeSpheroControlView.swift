import SwiftUI

struct MazeSpheroControlView: View {
    @ObservedObject private var connectionManager = SpheroConnectionController.shared
    @ObservedObject private var roleManager = SpheroRoleManager.instance
    
    // État pour stocker la référence à la Sphero maze
    @State private var mazeSphero: BoltToy? = nil
    
    private var mazeSpheroName: String? {
        roleManager.roleAssignments
            .first(where: { $0.role == .maze })?
            .spheroName
    }
    
    private var isConnected: Bool {
        mazeSpheroName != nil && connectionManager.connectedSpheroNames.contains(mazeSpheroName!)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Status de connexion
            HStack {
                Image(systemName: isConnected ? "checkmark.circle.fill" : "x.circle.fill")
                    .foregroundColor(isConnected ? .green : .red)
                Text(isConnected ? "Sphero Maze Connected" : "Sphero Maze Disconnected")
                    .font(.headline)
            }
            
            if let spheroName = mazeSpheroName {
                // Bouton de déconnexion si connecté
                if isConnected {
                    Button(action: {
                        connectionManager.disconnectSphero(spheroName)
                    }) {
                        HStack {
                            Image(systemName: "disconnect.circle.fill")
                            Text("Disconnect Maze Sphero")
                        }
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    // Bouton pour envoyer le motif d'éclair
                    Button(action: {
                        if let sphero = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == spheroName }) {
                            sphero.setFrontLed(color: UIColor(red: 55/255, green: 30/255, blue: 0/255, alpha: 1.0))
                            sphero.setBackLed(color: UIColor(red: 55/255, green: 30/255, blue: 0/255, alpha: 1.0))
                            SpheroPresetManager.shared.sendLightningPreset(to: sphero)
                            sphero.setFrontLed(color: UIColor(red: 110/255, green: 60/255, blue: 0/255, alpha: 1.0))
                            sphero.setBackLed(color: UIColor(red: 110/255, green: 60/255, blue: 0/255, alpha: 1.0))
                        }
                    }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Send Lightning Pattern")
                        }
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    }
                    
                } else {
                    // Bouton de reconnexion si déconnecté
                    Button(action: {
                        connectionManager.reconnectSphero(spheroName)
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("Reconnect Maze Sphero")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            } else {
                // Message si aucune Sphero n'est assignée au rôle maze
                Text("No Sphero assigned to maze role")
                    .foregroundColor(.gray)
                    .italic()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.1)))
        .padding()
    }
}
