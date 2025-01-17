//
//  ContentView.swift
//  remoteController2
//
//  Created by Valentin Gassant on 16/01/2025.
//

import SwiftUI

struct SpheroBoltState {
    var speed: Double = 0
    var heading: Double = 0
}
struct SpheroRotationData {
    var totalRotations: Double = 0.0
    var currentRotationSpeed: Double = 0.0
    var lastGyroZ: Double = 0.0
    var isCapturing: Bool = false
    var hasReachedTarget: Bool = false
    var isFirstReading: Bool = true
    var wasRotating: Bool = false  // Ajout de ce champ
}

struct ContentView: View {
    @StateObject private var wsClient = WebSocketClient.instance
    @State private var showConnectSheet = false
    @State private var spheroStates: [String: SpheroBoltState] = [:]
    @StateObject private var roleManager = SpheroRoleManager.instance
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var rotationData: [String: SpheroRotationData] = [:]
    
    private let ROTATION_SPEED_THRESHOLD: Double = 50.0
    private let TOTAL_ROTATIONS_TARGET: Double = 10.0
    
    
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
    
    private func startDataCapture(for spheroId: String) {
            guard let sphero = connectedSpheros[spheroId] else { return }
            
            // Désactiver d'abord les capteurs
//            sphero.sensorControl.disable()
            
            // Attendre un court instant pour s'assurer que les capteurs sont bien désactivés
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Reset complet des données
                rotationData[spheroId] = SpheroRotationData(
                    totalRotations: 0.0,
                    currentRotationSpeed: 0.0,
                    lastGyroZ: 0.0,
                    isCapturing: true,
                    hasReachedTarget: false,
                    isFirstReading: true
                )
                
                // Réactiver les capteurs avec les nouveaux paramètres
                sphero.sensorControl.enable(sensors: SensorMask(arrayLiteral: .gyro))
//                sphero.sensorControl.interval = 1
                sphero.setStabilization(state: .off)
                
                sphero.sensorControl.onDataReady = { data in
                    self.handleSensorData(data: data, spheroId: spheroId)
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
    private func stopDataCapture(for spheroId: String) {
            guard let sphero = connectedSpheros[spheroId] else { return }
            
            // Marquer l'arrêt de la capture
            rotationData[spheroId]?.isCapturing = false
            
            // Désactiver les capteurs
//            sphero.sensorControl.disable()
            
            // Attendre un court instant avant de réinitialiser
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Réactiver la stabilisation
                sphero.setStabilization(state: .on)
                
                // Reset complet des données
                self.rotationData[spheroId] = SpheroRotationData(
                    totalRotations: 0.0,
                    currentRotationSpeed: 0.0,
                    lastGyroZ: 0.0,
                    isCapturing: false,
                    hasReachedTarget: false,
                    isFirstReading: true,
                    wasRotating: false
                )
            }
        }
    
    private func handleSensorData(data: SensorData, spheroId: String) {
            // Vérifier immédiatement si la capture est encore active
            guard let rotationInfo = rotationData[spheroId], rotationInfo.isCapturing else { return }
            
            DispatchQueue.main.async { [self] in
                guard var spheroData = rotationData[spheroId],
                      spheroData.isCapturing,
                      let handleNumber = getHandleNumber(for: spheroId) else { return }
                
                // Si on a atteint la cible, on arrête immédiatement
                if spheroData.totalRotations >= TOTAL_ROTATIONS_TARGET {
                    sendCompletionMessage(handleNumber: handleNumber)
                    stopDataCapture(for: spheroId)
                    return
                }
                
                if let gyro = data.gyro?.rotationRate {
                    let gyroZ = Double(gyro.z ?? 0)
                    
                    // Ignorer la première lecture pour éviter les valeurs résiduelles
                    if spheroData.isFirstReading {
                        spheroData.isFirstReading = false
                        spheroData.lastGyroZ = gyroZ
                        rotationData[spheroId] = spheroData
                        return
                    }
                    
                    let currentSpeed = abs(gyroZ)
                    spheroData.currentRotationSpeed = currentSpeed
                    
                    // Vérifier l'état de rotation
//                    let wasRotating = spheroData.currentRotationSpeed > ROTATION_SPEED_THRESHOLD
                    let isNowRotating = currentSpeed > ROTATION_SPEED_THRESHOLD

                    // Si l'état a changé
                    if spheroData.wasRotating != isNowRotating {
                        sendRotationMessage(handleNumber: handleNumber, isRotating: isNowRotating)
                    }
                    // Mise à jour de l'état pour la prochaine fois
                    spheroData.wasRotating = isNowRotating
                    
                    // Calculer le changement de rotation
                    let timeInterval = 1.0 / 180.0
                    let rotationChange = gyroZ * timeInterval * (180.0 / .pi)
                    
                    if isNowRotating {
                        spheroData.totalRotations += abs(rotationChange / 360.0)
                    }
                    
                    // Vérifier si on a atteint l'objectif
                    if spheroData.totalRotations >= TOTAL_ROTATIONS_TARGET {
                        sendCompletionMessage(handleNumber: handleNumber)
                        stopDataCapture(for: spheroId)
                        return
                    }
                    
                    spheroData.lastGyroZ = gyroZ
                    rotationData[spheroId] = spheroData
                }
            }
        }
    
    private func sendCompletionMessage(handleNumber: String) {
//            let message = "typhoon_iphone=>[typhoon_esp]=>sphero\(handleNumber)#completed"
                    let routeOrigin = "typhoon_iphone"
                    let routeTarget = ["typhoon_esp"]
                    let component = "sphero\(handleNumber)"
                    let data = "completed"
            wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
        }
    
    private func sendRotationMessage(handleNumber: String, isRotating: Bool) {
        let routeOrigin = "typhoon_iphone"
        let routeTarget = ["typhoon_esp"]
        let component = "sphero\(handleNumber)"
        let data = "\(isRotating)"  // Envoie "true" ou "false"
        print("send rotation message \(data)")
        wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
    }
    
    var body: some View {
        
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SpheroConnectionStatusView()
                    MazeSpheroControlView()
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
                }
                
            }
        }
        .padding()
        .sheet(isPresented: $showConnectSheet) {
            SimpleSpheroConnectionView()
        }
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

#Preview {
    ContentView()
}
