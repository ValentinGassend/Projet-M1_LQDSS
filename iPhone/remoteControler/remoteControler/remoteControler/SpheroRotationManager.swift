//
//  SpheroRotationManager.swift
//  remoteController2
//
//  Created by Valentin Gassant on 17/01/2025.
//

import Foundation

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

class SpheroRotationManager: ObservableObject {
    static let instance = SpheroRotationManager()
    
    @Published private var rotationData: [String: SpheroRotationData] = [:]
    private var connectedSpheros: [String: BoltToy] = [:]
    
    private let ROTATION_SPEED_THRESHOLD: Double = 50.0
    private let TOTAL_ROTATIONS_TARGET: Double = 10.0
    
    private let wsClient = WebSocketClient.instance
    
    private init() {}
    
    // MARK: - Public Methods
    
    func configureBolt(sphero: BoltToy, id: String) {
        sphero.setStabilization(state: .on)
        connectedSpheros[id] = sphero
        rotationData[id] = SpheroRotationData()
    }
    
    func startDataCapture(for spheroId: String, handleNumber: String) {
        guard let sphero = connectedSpheros[spheroId] else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Reset data
            self.rotationData[spheroId] = SpheroRotationData(
                totalRotations: 0.0,
                currentRotationSpeed: 0.0,
                lastGyroZ: 0.0,
                isCapturing: true,
                hasReachedTarget: false,
                isFirstReading: true,
                wasRotating: false
            )
            
            // Configure sensors
            sphero.sensorControl.enable(sensors: SensorMask(arrayLiteral: .gyro))
            sphero.setStabilization(state: .off)
            
            // Set data handler
            sphero.sensorControl.onDataReady = { [weak self] data in
                self?.handleSensorData(data: data, spheroId: spheroId, handleNumber: handleNumber)
            }
        }
    }
    
    func stopDataCapture(for spheroId: String) {
        guard let sphero = connectedSpheros[spheroId] else { return }
        
        rotationData[spheroId]?.isCapturing = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sphero.setStabilization(state: .on)
            
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
    
    func getRotationData(for spheroId: String) -> SpheroRotationData? {
        return rotationData[spheroId]
    }
    
    func isSpheroCaptureActive(_ spheroId: String) -> Bool {
        return rotationData[spheroId]?.isCapturing == true
    }
    
    // MARK: - Private Methods
    
    private func handleSensorData(data: SensorData, spheroId: String, handleNumber: String) {
        guard let rotationInfo = rotationData[spheroId],
              rotationInfo.isCapturing else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  var spheroData = self.rotationData[spheroId],
                  spheroData.isCapturing else { return }
            
            if spheroData.totalRotations >= TOTAL_ROTATIONS_TARGET {
                self.sendCompletionMessage(handleNumber: handleNumber)
                self.stopDataCapture(for: spheroId)
                return
            }
            
            if let gyro = data.gyro?.rotationRate {
                let gyroZ = Double(gyro.z ?? 0)
                
                if spheroData.isFirstReading {
                    spheroData.isFirstReading = false
                    spheroData.lastGyroZ = gyroZ
                    self.rotationData[spheroId] = spheroData
                    return
                }
                
                let currentSpeed = abs(gyroZ)
                spheroData.currentRotationSpeed = currentSpeed
                
                let isNowRotating = currentSpeed > self.ROTATION_SPEED_THRESHOLD
                
                if spheroData.wasRotating != isNowRotating {
                    self.sendRotationMessage(handleNumber: handleNumber, isRotating: isNowRotating)
                }
                
                spheroData.wasRotating = isNowRotating
                
                let timeInterval = 1.0 / 180.0
                let rotationChange = gyroZ * timeInterval * (180.0 / .pi)
                
                if isNowRotating {
                    spheroData.totalRotations += abs(rotationChange / 360.0)
                }
                
                if spheroData.totalRotations >= self.TOTAL_ROTATIONS_TARGET {
                    self.sendCompletionMessage(handleNumber: handleNumber)
                    self.stopDataCapture(for: spheroId)
                    return
                }
                
                spheroData.lastGyroZ = gyroZ
                self.rotationData[spheroId] = spheroData
            }
        }
    }
    
    private func sendCompletionMessage(handleNumber: String) {
        wsClient.sendMessage(
            from: "typhoon_iphone",
            to: ["typhoon_esp"],
            component: "sphero\(handleNumber)",
            data: "completed"
        )
    }
    
    private func sendRotationMessage(handleNumber: String, isRotating: Bool) {
        wsClient.sendMessage(
            from: "typhoon_iphone",
            to: ["typhoon_esp"],
            component: "sphero\(handleNumber)",
            data: "\(isRotating)"
        )
    }
}
