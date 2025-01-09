//
//  TyphoonRotationView.swift
//  remoteControler
//
//  Created by Valentin Gassant on 09/01/2025.
//

import SwiftUI

import SwiftUI

struct TyphoonRotationView: View {
    @StateObject private var wsClient = WebSocketClient.instance
    @StateObject private var roleManager = SpheroRoleManager.instance
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var rotationData: [String: SpheroRotationData] = [:]
    
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
    
    private func startDataCapture(for spheroId: String) {
        guard let sphero = connectedSpheros[spheroId] else { return }
        
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
                    spheroData.totalRotations += rotationChange / 360.0
                    updatedRotationData[spheroId] = spheroData
                    
                    if wasRotating != isNowRotating {
                        sendRotationMessage(handleNumber: handleNumber, isRotating: isNowRotating)
                    }
                    
                    if spheroData.totalRotations >= TOTAL_ROTATIONS_TARGET {
                        sendCompletionMessage(handleNumber: handleNumber)
                        stopDataCapture(for: spheroId)
                    }
                    rotationData = updatedRotationData
                }
            }
        }
    }
    
    private func configureBolts() {
        for bolt in SharedToyBox.instance.bolts {
            if let name = bolt.peripheral?.name, spheroIds.contains(name) {
                bolt.setStabilization(state: .on)
                connectedSpheros[name] = bolt
                rotationData[name] = SpheroRotationData()
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Configure Bolts") {
                configureBolts()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            
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
                }
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            wsClient.connectForIdentification(route: .typhoonIphoneConnect)
        }
        .onDisappear {
            for (_, sphero) in connectedSpheros {
                sphero.sensorControl.disable()
            }
            wsClient.disconnect(route: "typhoonIphoneConnect")
        }
    }
}

