import SwiftUI

struct RotationData {
    var totalRotations: Double = 0.0
    var currentRotationSpeed: Double = 0.0
    var isCapturing: Bool = false
}

struct HandleView: View {
    let handleRole: SpheroRole
    let spheroAssignment: SpheroRoleAssignment?
    @State private var rotationData: [String: SpheroRotationData] = [:]
    let onStartCapture: (BoltToy) -> Void
    let onStopCapture: (BoltToy) -> Void
    
    private var isCapturing: Bool {
        guard let spheroName = spheroAssignment?.spheroName else { return false }
        return rotationData[spheroName]?.isCapturing ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(handleRole.rawValue)")
                .font(.headline)
            
            if let assignment = spheroAssignment {
                if let toy = assignment.toy {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connected: \(assignment.spheroName)")
                            .foregroundColor(.green)
                        
                        Button(action: {
                            if isCapturing {
                                onStopCapture(toy)
                            } else {
                                onStartCapture(toy)
                            }
                        }) {
                            Text(isCapturing ? "Stop Detection" : "Start Detection")
                                .padding()
                                .background(isCapturing ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        if let data = rotationData[assignment.spheroName] {
                            Text("Total Rotations: \(String(format: "%.2f", data.totalRotations))")
                            Text("Current Speed: \(String(format: "%.2f", data.currentRotationSpeed))")
                        }
                    }
                }
            } else {
                Text("No Sphero assigned")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ContentView: View {
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var spheroStates: [String: SpheroBoltState] = [:]
    @StateObject private var wsClient = WebSocketClient.instance
    @State private var showConnectSheet = false
    @State private var isSpheroConnected = false
    @State private var connectedSpheroNames: [String] = []
    @State private var connectionStatus: String = ""
    @State private var spheroMazeInfo: [String: BoltToy] = [:]
    @StateObject private var roleManager = SpheroRoleManager.instance
    @State private var rotationData: [String: SpheroRotationData] = [:]
    
    
    private let ROTATION_SPEED_THRESHOLD: Double = 10.0 // Adjust this threshold as needed
    private let TOTAL_ROTATIONS_TARGET: Double = 2.0
    //    private let spheroIds = ["SB-8630", "SB-5D1C"]
    private var spheroIds: [String] {
        return getHandleAssignments()
            .compactMap { $0.spheroName }
    }
    
    // Helper function to get handle number from spheroId
    private func getHandleNumber(for spheroId: String) -> String? {
            for role in [SpheroRole.handle1, .handle2, .handle3, .handle4] {
                if let assignment = roleManager.getRoleAssignment(for: role),
                   assignment.spheroName == spheroId {
                    // Extract number from handle role (e.g., "handle1" -> 1)
                    return role.rawValue.replacingOccurrences(of: "Handle ", with: "")
                }
            }
            return nil
        }
        
    private func sendRotationMessage(handleNumber: String, isRotating: Bool) {
//            let message = "typhoon_iphone=>[typhoon_esp]=>sphero\(handleNumber)#\(isRotating)"
            
                    let routeOrigin = "typhoon_iphone"
                    let routeTarget = ["typhoon_esp"]
                    let component = "sphero\(handleNumber)"
                    let data = "\(isRotating)"
            wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
        }
        
    private func sendCompletionMessage(handleNumber: String) {
//            let message = "typhoon_iphone=>[typhoon_esp]=>sphero\(handleNumber)#completed"
                    let routeOrigin = "typhoon_iphone"
                    let routeTarget = ["typhoon_esp"]
                    let component = "sphero\(handleNumber)"
                    let data = "completed"
            wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
        }
    private func getHandleAssignments() -> [SpheroRoleAssignment] {
        return [.handle1, .handle2, .handle3, .handle4].compactMap { role in
            roleManager.getRoleAssignment(for: role)
        }
    }
    private func connectToSpheros() {
        //        SharedToyBox.instance.searchForBoltsNamed(spheroIds) { error in
        //            if error == nil {
        //                //                configureBolts()
        //            }
        //        }
    }
    
    private func configureBolts() {
        for bolt in SharedToyBox.instance.bolts {
            if let name = bolt.peripheral?.name, spheroIds.contains(name) {
                setupSphero(sphero: bolt, id: name)
                spheroStates[name] = SpheroBoltState()
                connectedSpheros[name] = bolt
                rotationData[name] = SpheroRotationData()
            }
        }
    }
    
    private func setupSphero(sphero: BoltToy, id: String) {
        sphero.setStabilization(state: .on)
    }
    
    private func startDataCapture(for spheroId: String) {
        guard let sphero = connectedSpheros[spheroId] else { return }
        
        // Reset rotation values before starting
        if var rotationInfo = rotationData[spheroId] {
            rotationInfo.totalRotations = 0.0
            rotationInfo.currentRotationSpeed = 0.0
            rotationInfo.lastGyroZ = 0.0
            rotationData[spheroId] = rotationInfo
        }
        
        sphero.sensorControl.enable(sensors: SensorMask(arrayLiteral: .accelerometer, .gyro))
        sphero.sensorControl.interval = 1
        sphero.setStabilization(state: .off)
        
        sphero.sensorControl.onDataReady = { data in
            handleSensorData(data: data, spheroId: spheroId)
        }
        
        rotationData[spheroId]?.isCapturing = true
    }
    
    private func stopDataCapture(for spheroId: String) {
        guard let sphero = connectedSpheros[spheroId] else { return }
        
        sphero.setStabilization(state: .on)
        sphero.sensorControl.disable()
        
        rotationData[spheroId]?.isCapturing = false
    }
    
    private func handleSensorData(data: SensorData, spheroId: String) {
        let spherole = roleManager.getRole(for: spheroId)
        DispatchQueue.main.async { [self] in
            guard rotationData[spheroId]?.isCapturing == true,
                  let handleNumber = getHandleNumber(for: spheroId) else { return }
            
            if let gyro = data.gyro?.rotationRate {
                let gyroZ = abs(Int(gyro.z ?? 0))
                let currentSpeed = Double(gyroZ)
                let wasRotating = rotationData[spheroId]?.currentRotationSpeed ?? 0 > ROTATION_SPEED_THRESHOLD
                let isNowRotating = currentSpeed > ROTATION_SPEED_THRESHOLD
                
                // Create a new copy of the rotation data
                var updatedRotationData = rotationData
                
                // Update current speed
                updatedRotationData[spheroId]?.currentRotationSpeed = currentSpeed
                
                // Calculate time interval based on sensor data frequency (180Hz)
                let timeInterval = 1.0 / 180.0
                
                // Calculate angular change in degrees
                let rotationChange = Double(gyroZ) * timeInterval * 180.0 / .pi
                
                // Add to accumulated complete rotations
                if var spheroData = updatedRotationData[spheroId] {
                    spheroData.totalRotations += rotationChange / 360.0
                    updatedRotationData[spheroId] = spheroData
                    
                    // Check rotation state change
                    if wasRotating != isNowRotating {
                        sendRotationMessage(handleNumber: handleNumber, isRotating: isNowRotating)
                    }
                    
                    // Check for completion (2 full rotations)
                    if spheroData.totalRotations >= TOTAL_ROTATIONS_TARGET {
                        sendCompletionMessage(handleNumber: handleNumber)
                        stopDataCapture(for: spheroId)
                    }
                    rotationData[spheroId]? = spheroData
                }
                
                // Update the state with the new values
//                rotationData[spheroId]? = updatedRotationData
            }
        }
    }
    
    private func moveSphero(id: String, heading: Double, speed: Double, reverse: Bool = false) {
        guard let sphero = connectedSpheros[id] else { return }
        if reverse {
            sphero.roll(heading: heading, speed: speed, rollType: .roll)
        } else {
            sphero.roll(heading: heading, speed: speed)
        }
    }
    
    private func stopSphero(id: String) {
        guard let sphero = connectedSpheros[id],
              let state = spheroStates[id] else { return }
        sphero.stopRoll(heading: state.heading)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
                                
                                if let _ = connectedSpheros[spheroId] {
                                    HStack {
                                        Button(rotationData[spheroId]?.isCapturing == true ? "Stop Capture" : "Start Capture") {
                                            if rotationData[spheroId]?.isCapturing == true {
                                                stopDataCapture(for: spheroId)
                                            } else {
                                                startDataCapture(for: spheroId)
                                            }
                                        }
                                        .padding()
                                        .background(rotationData[spheroId]?.isCapturing == true ? Color.red : Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    
                                    if let rotationInfo = rotationData[spheroId] {
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
            SpheroConnectionSheetView(
                isSpheroConnected: $isSpheroConnected,
                wsClient: wsClient,
                connectionStatus: $connectionStatus,
                connectedSpheroNames: $connectedSpheroNames,
                spheroMazeInfo: $spheroMazeInfo,
                roleManager: roleManager
            )
        }
        .onAppear {
            //            connectToSpheros()
            wsClient.connectForIdentification(route: .remoteControllerConnect)
            wsClient.connectForIdentification(route: .mazeIphoneConnect)
            wsClient.connectForIdentification(route: .typhoonIphoneConnect)
        }
        .onDisappear {
            for (_, sphero) in connectedSpheros {
                sphero.sensorControl.disable()
            }
            wsClient.disconnect(route: "remoteControllerConnect")
            wsClient.disconnect(route: "mazeIphoneConnect")
            wsClient.disconnect(route: "typhoonIphoneConnect")
        }
    }
}

// Modèle pour les données de rotation d'un Sphero
struct SpheroRotationData {
    var totalRotations: Double = 0.0
    var currentRotationSpeed: Double = 0.0
    var lastGyroZ: Double = 0.0
    var isCapturing: Bool = false
}

struct SpheroBoltState {
    var speed: Double = 0
    var heading: Double = 0
    
}
