import SwiftUI

extension ToyBox {
    func searchForBoltsNamed(_ names: [String], completion: @escaping (Error?) -> Void) {
        startScan()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.stopScan()
            completion(nil)
        }
    }
}

struct SpheroDirectionView: View {
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var spheroStates: [String: SpheroBoltState] = [:]
    @State private var showCollisionMessage: Bool = false
    
    // États pour la détection de rotation par Sphero
    @State private var rotationData: [String: SpheroRotationData] = [:]
    private let rotationThreshold: Double = 20.0
    
    private let spheroIds = ["SB-5D1C", "SB-8630"]
    
    private func connectToSpheros() {
        SharedToyBox.instance.searchForBoltsNamed(spheroIds) { error in
            if error == nil {
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
        sphero.setCollisionDetection(configuration: .enabled)
        
        sphero.onCollisionDetected = { _ in
            DispatchQueue.main.async {
                showCollisionMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCollisionMessage = false
                }
            }
        }
    }
    
    private func startDataCapture(for spheroId: String) {
        guard let sphero = connectedSpheros[spheroId] else { return }
        
        // Réinitialiser les valeurs des rotations avant de recommencer
        if var rotationInfo = rotationData[spheroId] {
            rotationInfo.totalRotations = 0.0
            rotationInfo.currentRotationSpeed = 0.0
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
            guard let rotationInfo = rotationData[spheroId], rotationInfo.isCapturing else { return }

            if let gyro = data.gyro?.rotationRate {
                let gyroZ = abs(Int(gyro.z ?? 0)) // Convertir en Int et appliquer abs()
                rotationData[spheroId]?.currentRotationSpeed = Double(gyroZ)
                
                // Définir un intervalle de temps basé sur la fréquence des données (par exemple, 60Hz)
                let timeInterval = 1.0 / 180.0
                
                // Calculer le changement angulaire en degrés
                let rotationChange = Double(gyroZ) * timeInterval * 180.0 / .pi
                
                // Ajouter aux tours complets accumulés
                rotationData[spheroId]?.totalRotations += rotationChange / 360.0
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
        VStack {
            Button("config") {
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
                            Button(rotationData[spheroId]?.isCapturing == true ? "Arrêter Capture" : "Commencer Capture") {
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
                        
                        // Affichage des données de rotation spécifiques à ce Sphero
                        if let rotationInfo = rotationData[spheroId] {
                            VStack {
                                Text("Rotations totales: \(String(format: "%.2f", rotationInfo.totalRotations))")
                                Text("Vitesse de rotation: \(String(format: "%.2f", rotationInfo.currentRotationSpeed))")
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
        .onAppear {
            connectToSpheros()
        }
        .onDisappear {
            for (_, sphero) in connectedSpheros {
                sphero.sensorControl.disable()
            }
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
