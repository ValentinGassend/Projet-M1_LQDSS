import SwiftUI

// Vue principale
struct ContentView: View {
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
                Text("Air")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                Button(action: {
//                    start/increase speed rotation on rvr
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "increase speed rotation on rvr")
                }, label: {
                    Text("start/increase speed rotation on rvr")
                })
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                
                
                
                Button(action: {
                    // ws send start RPI laser
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "start laser detection on Air")
                }, label: {
                    Text("start laser detection")
                })
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                
                
                
                // title electicity
                Spacer()

                Text("Electicity")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
                if isDefaultSpheroConnected {
                    
                Button(action: {
                    // ws send turn on lightning
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "turn on lightning")
                }, label: {
                    Text("set lightning matrix")
                })
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                
                Button(action: {
                    // ws send start RPI laser
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "start RPI laser electricity")
                }, label: {
                    Text("start laser detection")
                })
                        .padding()
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                
                //
                // title fire
                    
                } else {
                    VStack {
                        Text("Need to connected to default Sphero")
                    }
                }
                Spacer()
                Text("Fire")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                
                Button(action: {
                    // ws turn on drone motors
                    
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "turn on drone motors")
                }, label: {
                    Text("turn on drone motors")
                })
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                
                Button(action: {
                    // ws send start RPI laser
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "start RPI laser Fire")
                }, label: {
                    Text("start recolt detection")
                })
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                
                
                // title water
                Spacer()
                

                Text("Water")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom)
//                NavigationLink(
//                    destination: SpheroDirectionView(
//                        isSpheroConnected: $isSpheroConnected,
//                        connectedSpheroNames:$connectedSpheroNames
//                    )
//                ) {
//                    Text("Go to Direction view")
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(8)
//                }
                
                Button(action: {
                    // ws turn on sphero typhoon
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "turn on sphero typhoon")
                }, label: {
                    Text("turn on mix detection")
                })
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                
                
                Button(action: {
//                    start/increase motor speed on rpi
                    
                    wsClient.sentToRoute(route: .remoteControllerConnect, msg: "turn on lightning")
                }, label: {
                    Text("start/increase motor speed")
                })
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                
                
                
                Spacer()

                
                
                // Bouton pour ouvrir la feuille de connexion
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
                Button {
                    wsClient.connectForIdentification(route: .remoteControllerConnect)
                } label: {
                    Text("ConnectToRemoteController")
                }
                NavigationLink(destination: DashboardView()) {
                    Text("Go to Dashboard")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("Remote Controller")
        }
        .sheet(isPresented: $showConnectSheet) {
            SpheroConnectionSheetView(
                isSpheroConnected: $isSpheroConnected,
                isDefaultSpheroConnected: $isDefaultSpheroConnected,
                isTyphoonSpheroConnected: $isTyphoonSpheroConnected,
                connectionStatus: $connectionStatus,
                connectedSpheroNames: $connectedSpheroNames
            )
        }
    }
}
