import SwiftUI

struct SpheroConnectionStatusView: View {
    @ObservedObject private var connectionManager = SpheroConnectionController.shared
    @ObservedObject private var roleManager = SpheroRoleManager.instance
    private let targetSpheros = ["SB-5D1C","SB-92B2","SB-F682"]
    
    var body: some View {
        VStack(spacing: 16) {
            if !connectionManager.connectedSpheroNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Spheros connectés:")
                        .font(.headline)
                    
                    ForEach(connectionManager.connectedSpheroNames, id: \.self) { name in
                        HStack {
                            Text(name)
                            Spacer()
                            Text(roleManager.getRole(for: name).rawValue)
                                                            .foregroundColor(.blue)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 4)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 4)
                                                                    .fill(Color.blue.opacity(0.2))
                                                            )
                                                        
                            Button(action: { connectionManager.disconnectSphero(name) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
            
            if let disconnectedName = connectionManager.disconnectedSphero {
                Button(action: { connectionManager.reconnectSphero(disconnectedName) }) {
                    HStack {
                        Image(systemName: "arrow.clockwise.circle.fill")
                        Text("Reconnecter \(disconnectedName)")
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            if !connectionManager.connectionStatus.isEmpty {
                Text(connectionManager.connectionStatus)
                    .foregroundColor(connectionManager.connectionStatus == "Connecté" ? .green : .red)
            }
        }
        .padding()
    }
}
