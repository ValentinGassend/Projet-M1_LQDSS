import SwiftUI

struct SpheroConnectionStatusView: View {
    @ObservedObject private var connectionManager = SpheroConnectionController.shared
    private let targetSpheros = ["SB-8630", "SB-5D1C"]
    
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
