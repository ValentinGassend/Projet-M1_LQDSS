import SwiftUI


struct ContentView: View {
    @ObservedObject private var connectionManager = SpheroConnectionController.shared
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var spheroStates: [String: SpheroBoltState] = [:]
    @StateObject private var wsClient = WebSocketClient.instance
    @StateObject private var rotationManager = SpheroRotationManager.instance
    @State private var showConnectSheet = false
    @State private var isSpheroConnected = false
    @State private var connectedSpheroNames: [String] = []
    @State private var connectionStatus: String = ""
    @State private var spheroMazeInfo: [String: BoltToy] = [:]
    @StateObject private var roleManager = SpheroRoleManager.instance
    @State private var rotationData: [String: SpheroRotationData] = [:]
    
    
    
    
    private var spheroIds: [String] {
        return getHandleAssignments()
            .compactMap { $0.spheroName }
    }
    
    private func getHandleNumber(for spheroId: String) -> String? {
        for role in [SpheroRole.handle1, .handle2, .handle3, .handle4] {
            if let assignment = roleManager.getRoleAssignment(for: role),
               assignment.spheroName == spheroId {
                return role.rawValue.replacingOccurrences(of: "Handle ", with: "")
            }
        }
        return nil
    }
    
    private func getHandleAssignments() -> [SpheroRoleAssignment] {
        return [.handle1, .handle2, .handle3, .handle4].compactMap { role in
            roleManager.getRoleAssignment(for: role)
        }
    }
    
    private func configureBolts() {
        for bolt in SharedToyBox.instance.bolts {
            if let name = bolt.peripheral?.name, spheroIds.contains(name) {
                rotationManager.configureBolt(sphero: bolt, id: name)
                spheroStates[name] = SpheroBoltState()
                connectedSpheros[name] = bolt
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SpheroConnectionStatusView()
                    MazeSpheroControlView()
                    if !connectionStatus.isEmpty {
                        Text(connectionStatus)
                            .font(.headline)
                            .foregroundColor(isSpheroConnected ? .green : .red)
                    }
                    
                    Button(action: { showConnectSheet.toggle() }) {
                        Text("Connect Spheros")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    Button("Config") {
                        
                        configureBolts()
                    }
                    //                    if isSpheroConnected {
                    VStack(spacing: 16) {
                        ForEach(spheroIds, id: \.self) { spheroId in
                            VStack {
                                HStack {
                                    Text(spheroId)
                                    Text(connectedSpheros[spheroId] != nil ? "Connected" : "Not Connected")
                                        .foregroundColor(connectedSpheros[spheroId] != nil ? .green : .red)
                                }
                                
                                if connectedSpheros[spheroId] != nil {
                                    HStack {
                                        Button(rotationManager.isSpheroCaptureActive(spheroId) ? "Stop Capture" : "Start Capture") {
                                            if rotationManager.isSpheroCaptureActive(spheroId) {
                                                rotationManager.stopDataCapture(for: spheroId)
                                            } else {
                                                if let handleNumber = getHandleNumber(for: spheroId) {
                                                    rotationManager.startDataCapture(for: spheroId, handleNumber: handleNumber)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(rotationManager.isSpheroCaptureActive(spheroId) ? Color.red : Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    
                                    if let rotationInfo = rotationManager.getRotationData(for: spheroId) {
                                        VStack {
                                            Text("Total Rotations: \(String(format: "%.2f", rotationInfo.totalRotations))")
                                            Text("Current Speed: \(String(format: "%.2f", rotationInfo.currentRotationSpeed))")
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1))
                            .padding(.horizontal)
                        }
                    }
                    //                    }
                    
                    Spacer()
                    
                    NavigationLink(destination: DashboardView()) {
                        Text("Go to Dashboard")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    NavigationLink(destination: RemoteControllerView()) {
                        Text("Go to Remote controller view")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showConnectSheet) {
            SimpleSpheroConnectionView()
        }
//        .sheet(isPresented: $showConnectSheet) {
//            SpheroConnectionSheetView(
//                isSpheroConnected: $isSpheroConnected,
//                wsClient: wsClient,
//                connectionStatus: $connectionStatus,
//                connectedSpheroNames: $connectedSpheroNames,
//                spheroMazeInfo: $spheroMazeInfo,
//                roleManager: roleManager
//            )
//        }
        .onAppear {
            //            connectToSpheros()
//            wsClient.connectForIdentification(route: .remote)
            wsClient.connectForIdentification(route: .remoteController_iphone1Connect)
//            wsClient.connectForIdentification(route: .typhoonIphoneConnect)
        }
        .onDisappear {
//            for (_, sphero) in connectedSpheros {
//                sphero.sensorControl.disable()
//            }
            
            wsClient.disconnect(route: "remoteController_iphone1Connect")
//            wsClient.disconnect(route: "remoteControllerConnect")
//            wsClient.disconnect(route: "mazeIphoneConnect")
//            wsClient.disconnect(route: "typhoonIphoneConnect")
        }
    }
}

// Modèle pour les données de rotation d'un Sphero
//struct SpheroRotationData {
//    var totalRotations: Double = 0.0
//    var currentRotationSpeed: Double = 0.0
//    var lastGyroZ: Double = 0.0
//    var isCapturing: Bool = false
//}
//
