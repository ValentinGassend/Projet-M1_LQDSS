import SwiftUI
import Foundation

class SpheroPresetManager {
    static let shared = SpheroPresetManager()
    
    private let lightningPreset = [
        [false, false, false, false, false, false, false, false],
        [false, false, false, false, true,  true,  true,  false],
        [false, false, false, true,  true,  true,  false, false],
        [false, false, true,  true,  true,  false, false, false],
        [false, true,  true,  true,  true,  true,  false, false],
        [false, false, false, true,  true,  false, false, false],
        [false, false, true,  true,  false, false, false, false],
        [false, true,  false, false, false, false, false, false],
    ]
    
    func sendLightningPreset(to sphero: BoltToy) {
        for x in 0..<8 {
            for y in 0..<8 {
                sphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .black)
            }
        }
        
        // Applique le preset
        for x in 0..<8 {
            for y in 0..<8 where lightningPreset[x][y] {
                sphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .yellow)
            }
        }
        
        //        print("Preset Lightning envoyé au Sphero \(sphero.name ?? "Inconnu")")
    }
}

// Vue principale
struct RemoteControllerView: View {
    @ObservedObject var wsClient = WebSocketClient.instance
    
    var body: some View {
        TabView {
            VolcanoView(wsClient: wsClient)
                .tabItem {
                    Label("Volcano", systemImage: "flame")
                }
            MazeView(wsClient: wsClient)
                .tabItem {
                    Label("Maze", systemImage: "bolt")
                }
            TyphoonView()
                .tabItem {
                    Label("Typhoon", systemImage: "tornado")
                }
            TornadoView(wsClient: wsClient)
                .tabItem {
                    Label("Tornado", systemImage: "wind")
                }
            CrystalView(wsClient: wsClient)
                .tabItem {
                    Label("Crystal", systemImage: "sparkles")
                }
        }
    }
}
// vent / electricité / eau / feu
//    let spheroNames = ["SB-92B2", "SB-0994", "SB-808F", "SB-313C"]
struct VolcanoView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        
        "crystal_esp1=>[crystal_esp2,crystal_esp1,volcano_esp1,volcano_esp2,ambianceManager_rpi]=>rfid#volcano",
        "volcano_esp1=>[volcano_esp1,volcano_esp2]=>rfid#volcano",
//        "crystal_esp1=>[ambianceManager]=>set_zone_color#true",
        "crystal_esp1=>[volcano_esp1,ambianceManager]=>crystal_to_volcano#true",
        
        "crystal_esp1=>[volcano_esp1,ambianceManager]=>volcano_finished#true",
        "crystal_esp1=>[volcano_esp1,ambianceManager]=>volcano_to_crystal#true",
        
        "volcano_esp1=>[volcano_esp1,volcano_esp2 crystal_esp2,crystal_esp1]=>rfid#first",
//        "volcano_esp1=>[volcano_esp1,volcano_esp2 crystal_esp2,crystal_esp1]=>rfid#second",
//        "volcano_esp1=>[volcano_esp1,volcano_esp2 crystal_esp2,crystal_esp1]=>rfid#third",
//        "volcano_esp1=>[volcano_esp1]=>relay1#true",
//        "volcano_esp1=>[volcano_esp1]=>relay1#false",
//        "volcano_esp1=>[volcano_esp1]=>relay2#true",
//        "volcano_esp1=>[volcano_esp1]=>relay2#false",
        "volcano_esp2=>[volcano_esp1,volcano_esp2 crystal_esp2,crystal_esp1]=>rfid#second",     "volcano_esp2=>[volcano_esp1,volcano_esp2 crystal_esp2,crystal_esp1]=>rfid#third",

    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct MazeView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        "crystal_esp1=>[crystal_esp2,crystal_esp1,maze_esp,ambianceManager_rpi]=>rfid#maze",
        
        
        "maze_esp=>[maze_esp,ambianceManager]=>crystal_to_maze#true",
        
        "maze_esp=>[maze_esp,ambianceManager]=>maze_finished#true",
        "maze_esp=>[maze_esp,ambianceManager]=>maze_to_crystal#true",
        "crystal_esp1=>[ambianceManager]=>stelle_to_maze#true",
        "crystal_esp1=>[ambianceManager]=>maze_finished#true",
        "maze_esp=>[maze_esp,maze_iphone,ambianceManager_rpi]=>rfid#maze",
        "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn1#true",
        "maze_esp=>[maze_iphone]=>btn1#false",
        "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn2#true",
        "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn3#true",
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

import SwiftUI

struct SpheroRotationData {
    var totalRotations: Double = 0.0
    var currentRotationSpeed: Double = 0.0
    var lastGyroZ: Double = 0.0
    var isCapturing: Bool = false
    var hasReachedTarget: Bool = false
}

struct TyphoonView: View {
    @StateObject private var wsClient = WebSocketClient.instance
    @StateObject private var roleManager = SpheroRoleManager.instance
    @State private var rotationData: [String: SpheroRotationData] = [:]
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var spheroStates: [String: SpheroBoltState] = [:]
    
    private let ROTATION_SPEED_THRESHOLD: Double = 10.0
    private let TOTAL_ROTATIONS_TARGET: Double = 5.0
    
    private var spheroIds: [String] {
        return getHandleAssignments()
            .compactMap { $0.spheroName }
    }
    
    private func getHandleAssignments() -> [SpheroRoleAssignment] {
        return [.handle1, .handle2, .handle3, .handle4].compactMap { role in
            roleManager.getRoleAssignment(for: role)
        }
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
    
    private func startDataCapture(for spheroId: String) {
        guard let sphero = connectedSpheros[spheroId] else { return }
        
        if var rotationInfo = rotationData[spheroId] {
            rotationInfo.totalRotations = 0.0
            rotationInfo.currentRotationSpeed = 0.0
            rotationInfo.hasReachedTarget = false
            rotationInfo.lastGyroZ = 0.0
            rotationData[spheroId] = rotationInfo
        } else {
            rotationData[spheroId] = SpheroRotationData()
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
        
        rotationData[spheroId]?.isCapturing = false
    }
    
    private func sendRotationMessage(handleNumber: String, isRotating: Bool) {
        let routeOrigin = "typhoon_iphone"
        let routeTarget = ["typhoon_esp"]
        let component = "sphero\(handleNumber)"
        let data = "\(isRotating)"
        wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
    }
    
    private func sendCompletionMessage(handleNumber: String) {
        let routeOrigin = "typhoon_iphone"
        let routeTarget = ["typhoon_esp"]
        let component = "sphero\(handleNumber)"
        let data = "completed"
        wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
    }
    
    private func handleSensorData(data: SensorData, spheroId: String) {
        DispatchQueue.main.async {
            guard rotationData[spheroId]?.isCapturing == true,
                  let handleNumber = getHandleNumber(for: spheroId) else { return }
            
            if let gyro = data.gyro?.rotationRate {
                let gyroZ = abs(Int(gyro.z ?? 0))
                let currentSpeed = Double(gyroZ)
                let wasRotating = rotationData[spheroId]?.currentRotationSpeed ?? 0 > ROTATION_SPEED_THRESHOLD
                let isNowRotating = currentSpeed > ROTATION_SPEED_THRESHOLD
                
                var updatedRotationData = rotationData
                updatedRotationData[spheroId]?.currentRotationSpeed = currentSpeed
                
                let timeInterval = 1.0 / 180.0
                let rotationChange = Double(gyroZ) * timeInterval * 180.0 / .pi
                
                if var spheroData = updatedRotationData[spheroId] {
                    // Vérifiez si la cible est atteinte
                    if !spheroData.hasReachedTarget {
                        spheroData.totalRotations += rotationChange / 360.0
                        updatedRotationData[spheroId] = spheroData
                        
                        if wasRotating != isNowRotating {
                            sendRotationMessage(handleNumber: handleNumber, isRotating: isNowRotating)
                        }
                        
                        // Condition pour atteindre l'objectif
                        if spheroData.totalRotations >= TOTAL_ROTATIONS_TARGET {
                            spheroData.hasReachedTarget = true
                            updatedRotationData[spheroId] = spheroData
                            
                            // Envoyez le message "completed" une seule fois
                            sendCompletionMessage(handleNumber: handleNumber)
                            stopDataCapture(for: spheroId)
                        }
                        
                        rotationData = updatedRotationData
                    }
                }
            }
        }
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
    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                VStack {
                    Button("Config") {
                        
                        configureBolts()
                    }
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
                Divider()
                CommandListView(commands: commands, wsClient: wsClient).frame(height: 400)
            }
            .padding()
            
            
        }
        .onDisappear {
            for (spheroId, _) in connectedSpheros {
                if rotationData[spheroId]?.isCapturing == true {
                    stopDataCapture(for: spheroId)
                }
            }
        }
        .onChange(of: wsClient.isRFIDDetectedForTyphoon) { newValue in
            if newValue {
                print("RFID Detected - Starting auto configuration")
                configureBolts()
                
                // Démarrer la capture pour tous les Spheros après un court délai
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    for spheroId in spheroIds {
                        if rotationData[spheroId]?.isCapturing != true {
                            startDataCapture(for: spheroId)
                        }
                    }
                }
            }
        }
    }
    
    private let commands = [
        "crystal_esp2=>[crystal_esp2,crystal_esp1,typhoon_esp,ambianceManager_rpi]=>rfid#typhoon",
        "typhon_esp=>[typhoon_iphone,typhoon_esp,ambianceManager_rpi]=>rfid#typhoon",
        
        "crystal_esp2=>[ambianceManager]=>stelle_to_typhoon#true",
        "crystal_esp2=>[ambianceManager]=>typhoon_finished#true",
//        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay1#true",
//        "typhon_esp=>[typhoon_iphone]=>relay1#false",
//        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay2#true",
//        "typhon_esp=>[typhoon_iphone]=>relay2#false",
//        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay3#true",
//        "typhon_esp=>[typhoon_iphone]=>relay3#false",
//        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay4#true",
//        "typhon_esp=>[typhoon_iphone]=>relay4#false",
        "typhoon_iphone=>[typhoon_esp,ambianceManager_rpi]=>sphero1#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero1#false",
        "typhoon_iphone=>[typhoon_esp,ambianceManager_rpi]=>sphero2#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero2#false",
        "typhoon_iphone=>[typhoon_esp,ambianceManager_rpi]=>sphero3#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero3#false",
        "typhoon_iphone=>[typhoon_esp,ambianceManager_rpi]=>sphero4#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero4#false"
    ]
}

struct TornadoView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        "tornado_esp=>[tornado_esp]=>crystal_to_tornado#true",
        "crystal_esp2=>[crystal_esp2,crystal_esp1,tornado_esp,ambianceManager_rpi]=>rfid#tornado",
        "tornado_esp=>[tornado_esp,tornado_rpi,ambianceManager_rpi]=>rfid#tornado",
        "tornado_esp=>[tornado_esp]=>tornado_finished#true",
        "tornado_esp=>[tornado_esp]=>tornado_to_crystal#true",
        "tornado_esp=>[tornado_esp]=>led_tornado#off",
        "tornado_esp=>[tornado_esp]=>led_tornado#on",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic1#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic1#false",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic2#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic2#false",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic3#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic3#false",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic4#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic4#false",
//        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#first",
//        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#second",
//        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#third",
//        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#fourth"
        
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct CrystalView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        "crystal_esp1=>[ambianceManager]=>stelle_start#true",
        "crystal_esp1=>[ambianceManager]=>stelle_finished#true",
        "crystal_esp1=>[crystal_esp2,crystal_esp1,volcano_esp1,volcano_esp2,ambianceManager_rpi]=>rfid#volcano",
        "crystal_esp1=>[crystal_esp2,crystal_esp1,maze_esp,ambianceManager_rpi]=>rfid#maze",
        
        //        "crystal_esp2=>[crystal_esp2,crystal_esp1,AmbianceManager_rpi]=>crystal_start_animation",
        "crystal_esp2=>[crystal_esp2,crystal_esp1,tornado_esp,ambianceManager_rpi]=>rfid#tornado",
        "crystal_esp2=>[crystal_esp2,crystal_esp1,typhoon_esp,ambianceManager_rpi]=>rfid#typhoon"
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct CommandListView: View {
    let commands: [String]
    let wsClient: WebSocketClient
    
    var body: some View {
        List(commands, id: \ .self) { command in
            Button(action: {
                if let messageParsed = wsClient.parseSendedMessage(command) {
                    wsClient.sendMessage(from: messageParsed.routeOrigin, to: messageParsed.routeTargets, component: messageParsed.component, data: messageParsed.data)
                }
            }) {
                Text(command)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct SpheroBoltState {
    var speed: Double = 0
    var heading: Double = 0
}
