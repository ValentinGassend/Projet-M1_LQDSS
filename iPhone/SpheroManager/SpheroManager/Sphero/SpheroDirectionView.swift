import SwiftUI
import AVFoundation
import simd


struct SpheroDirectionView: View {
    @State private var showConnectionSheet = false
    @State private var isSpheroConnected: Bool = false
    @State private var connectedSpheroNames: [String] = []
    @State private var connectionStatus: String = ""
    @State private var spheroMazeInfo: [String: BoltToy] = [:]
    @ObservedObject var wsClient = WebSocketClient.instance
    @ObservedObject var roleManager = SpheroRoleManager.instance
    @State private var handle1Sphero: BoltToy?
    
    @State private var currentGyroData = [Double]()
    @State private var totalRotations: Double = 0.0
    @State private var isTrackingRotation: Bool = false
    @State private var lastGyroZ: Double = 0.0
    @State private var currentRotationSpeed: Double = 0.0
    private let rotationThreshold: Double = 20.0
    
    private func handleSensorData(data: SensorData) {
        DispatchQueue.main.async {
            // Gyroscope processing
            if let gyro = data.gyro?.rotationRate {
                // Ensure gyro.z is treated as an Int
                let gyroZ = abs(Int(gyro.z ?? 0)) // Convert Double to Int and apply abs()
                currentRotationSpeed = Double(gyroZ) // Store as Double if needed for calculations
                
                if isTrackingRotation {
                    // Définir un intervalle de temps basé sur la fréquence des données du gyroscope (60Hz par défaut)
                    let timeInterval = 1.0 / 180.0
                    
                    // Convertir le gyroscope en degrés par seconde et calculer le changement angulaire
                    let rotationChange = Double(gyroZ) * timeInterval * 180.0 / .pi // Conversion radians -> degrés
                    
                    // Convertir en tours complets et accumuler
                    totalRotations += rotationChange / 360.0
                    
                    
                }
                
            }
            
            
        }
    }
    
    
    
    private func updateHandle1Sphero() {
        if let assignment = roleManager.getRoleAssignment(for: .handle1) {
            handle1Sphero = assignment.toy
            print("Handle1 Sphero updated to: \(assignment.spheroName)")
            setupSensors()
        } else {
            handle1Sphero = nil
            print("No Handle1 Sphero assigned")
        }
    }
    
    private func startRotationTracking() {
        
        if let handle1 = handle1Sphero {
            handle1.setStabilization(state: .off)
            
            totalRotations = 0.0
            isTrackingRotation = true
            
        }
    }
    
    // Function to stop tracking rotations
    private func stopRotationTracking() {
        isTrackingRotation = false
        if let handle1 = handle1Sphero {
            handle1.setStabilization(state: .on)
            
        }
    }
    
    
    
    
    // View body for SwiftUI
    var body: some View {
        VStack {
            // Connection Status and Button
            HStack {
                if let handle1 = handle1Sphero {
                    Text("Handle1 Sphero Connected")
                        .foregroundColor(.green)
                } else {
                    Text("Handle1 Sphero Not Assigned")
                        .foregroundColor(.red)
                }
                
                Button(action: {
                    showConnectionSheet.toggle()
                }) {
                    Image(systemName: isSpheroConnected ? "link.circle.fill" : "link.circle")
                        .font(.title)
                        .foregroundColor(isSpheroConnected ? .green : .blue)
                }
            }
            .padding()
            
            
            ScrollView {
                VStack {
                    Text("Rotation Tracking")
                        .font(.headline)
                        .padding()
                    
                    Text("Total Rotations: \(String(format: "%.2f", totalRotations))")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Current Speed: \(String(format: "%.2f", currentRotationSpeed))°/s")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            if isTrackingRotation {
                                stopRotationTracking()
                            } else {
                                startRotationTracking()
                            }
                        }) {
                            Text(isTrackingRotation ? "Stop Tracking" : "Start Tracking")
                                .padding()
                                .background(isTrackingRotation ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            totalRotations = 0.0
                        }) {
                            Text("Reset Counter")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    
                    VStack{
                        ForEach(connectedSpheroNames, id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                Picker("Role", selection: Binding(
                                    get: { roleManager.getRole(for: name) },
                                    set: { newRole in
                                        let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == name })
                                        roleManager.assignRole(to: name, role: newRole, toy: toy)
                                        
                                        if newRole == .maze {
                                            spheroMazeInfo.removeAll()
                                            if let mazeToy = toy {
                                                spheroMazeInfo[name] = mazeToy
                                            }
                                        }
                                    }
                                )) {
                                    ForEach(SpheroRole.allCases, id: \.self) { role in
                                        Text(role.rawValue).tag(role)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                            .padding()
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                    }
            }
        }
        }
        .sheet(isPresented: $showConnectionSheet) {
            SpheroConnectionSheetView(
                isSpheroConnected: $isSpheroConnected,
                wsClient: wsClient,
                connectionStatus: $connectionStatus,
                connectedSpheroNames: $connectedSpheroNames,
                spheroMazeInfo: $spheroMazeInfo
            )
        }
        .onAppear {
            updateHandle1Sphero()
        }
        .onChange(of: showConnectionSheet) { status in
            updateHandle1Sphero()
        }
        .onDisappear {
            SharedToyBox.instance.bolt?.sensorControl.disable()
        }
    }
    
    private func setupSensors() {
        guard let handle1 = handle1Sphero else {
            print("No Handle1 Sphero available for sensor setup")
            return
        }
        
        print("Setting up sensors for Handle1 Sphero")
        handle1.sensorControl.enable(
            sensors: SensorMask(arrayLiteral: .accelerometer, .gyro)
        )
        handle1.sensorControl.interval = 1
        handle1.setStabilization(state: .off)
        handle1.setCollisionDetection(configuration: .enabled)
        handle1.sensorControl.onDataReady = { data in
            handleSensorData(data: data)
        }
    }
    
}

