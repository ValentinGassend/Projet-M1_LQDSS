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
    }
}
