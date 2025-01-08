import SwiftUI

extension ToyBox {
    // Ajout d'une méthode pour rechercher et se connecter aux Bolts
    func searchForBoltsNamed(_ names: [String], completion: @escaping (Error?) -> Void) {
        // Démarrer la recherche
        startScan()
        
        // Timer pour arrêter la recherche après un délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.stopScan()
            completion(nil)  // Appeler le completion handler une fois la recherche terminée
        }
    }
}
struct SpheroDirectionView: View {
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var spheroStates: [String: SpheroBoltState] = [:]
    @State private var showCollisionMessage: Bool = false
    
    private let spheroIds = ["SB-5D1C", "SB-8630"]
    
    private func connectToSpheros() {
            // Rechercher et se connecter aux Bolts
            SharedToyBox.instance.searchForBoltsNamed(spheroIds) { error in
                if error == nil {
                    // Une fois connecté, configurer chaque Bolt
//                    configureBolts()
                }
            }
        }
        
        private func configureBolts() {
            for bolt in SharedToyBox.instance.bolts {
                if let name = bolt.peripheral?.name, spheroIds.contains(name) {
                    setupSphero(sphero: bolt, id: name)
                    spheroStates[name] = SpheroBoltState()
                    connectedSpheros[name] = bolt
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
            
            sphero.sensorControl.enable(sensors: SensorMask(arrayLiteral: .accelerometer, .gyro))
            sphero.sensorControl.interval = 1
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
            if showCollisionMessage {
                Text("Collision détectée!")
                    .foregroundColor(.red)
                    .font(.headline)
            }
            Button {
                configureBolts()
            } label: {
                Text("config")
            }

            // Individual controls for each Sphero
            ForEach(spheroIds, id: \.self) { spheroId in
                VStack {
                    HStack {
                        Text(spheroId)
                        Text(connectedSpheros[spheroId] != nil ? "Connected" : "Not Connected")
                            .foregroundColor(connectedSpheros[spheroId] != nil ? .green : .red)
                    }
                    
                    if let state = spheroStates[spheroId] {
                        SpheroBoltControlView(
                            state: Binding(
                                get: { state },
                                set: { spheroStates[spheroId] = $0 }
                            ),
                            onMove: { heading, speed, reverse in
                                moveSphero(id: spheroId, heading: heading, speed: speed, reverse: reverse)
                            },
                            onStop: {
                                stopSphero(id: spheroId)
                            }
                        )
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

// State structure for each Sphero
struct SpheroBoltState {
    var speed: Double = 0
    var heading: Double = 0
}

// Individual control view for each Sphero
struct SpheroBoltControlView: View {
    @Binding var state: SpheroBoltState
    let onMove: (Double, Double, Bool) -> Void
    let onStop: () -> Void
    
    var body: some View {
        VStack {
            Text("Speed: \(Int(state.speed))")
            Slider(value: $state.speed, in: 0...255)
                .padding(.horizontal)
            
            Text("Heading: \(Int(state.heading))°")
            Slider(value: $state.heading, in: 0...360)
                .padding(.horizontal)
            
            // Direction controls
            VStack {
                Button("Forward") {
                    onMove(state.heading, state.speed, false)
                }
                
                HStack {
                    Button("Left") {
                        state.heading = (state.heading + 30).truncatingRemainder(dividingBy: 360)
                        onMove(state.heading, state.speed, false)
                    }
                    
                    Button("Stop") {
                        onStop()
                    }
                    .padding(.horizontal)
                    
                    Button("Right") {
                        state.heading = (state.heading - 30 + 360).truncatingRemainder(dividingBy: 360)
                        onMove(state.heading, state.speed, false)
                    }
                }
                .padding(.vertical, 5)
                
                Button("Backward") {
                    onMove(state.heading, state.speed, true)
                }
            }
        }
        .padding(.vertical)
    }
}
