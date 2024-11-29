import SwiftUI
import simd
import Charts

struct PositionDataPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let timestamp: Date
}

struct SpheroSensorControlView: View {
    @State private var isRecording = false
    @State private var acceleroData: [double3] = []
    @State private var positionData: [PositionDataPoint] = []
    @State private var velocity: double3 = [0, 0, 0] // Vitesse initiale
    @State private var position: double3 = [0, 0, 0] // Position initiale
    @State private var showConnectSheet = false // Etat pour afficher la feuille de connexion
    @State private var isSpheroConnected = false // Etat pour suivre la connexion Sphero
    
    private var chartData: [PositionDataPoint] {
        return positionData.suffix(50) // Limite les données affichées
    }

    var body: some View {
        VStack {
            Text("Sphero Position Tracker")
                .font(.largeTitle)
                .padding()

            Button(action: startRecording) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .padding()
                    .background(isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()

            VStack {
                Text("Position of the Ball (Top View):")
                    .font(.headline)
                    .padding(.top)

                // Affichage du graphique représentant la vue de la pièce
                Chart(chartData) { dataPoint in
                    PointMark(
                        x: .value("X", dataPoint.x),
                        y: .value("Y", dataPoint.y)
                    )
//                    // Optionnel: Cible à atteindre représentée par un cercle
//                    if dataPoint.id == positionData.last?.id {
//                        CircleMark(
//                            x: .value("X", 5.0), // Position de la cible
//                            y: .value("Y", 5.0), // Position de la cible
//                            size: .constant(20)  // Taille de la cible
//                        )
//                        .foregroundStyle(Color.red)
//                    }
                }
                .frame(height: 300)
                .chartXScale(domain: -10...10) // Plage personnalisée pour l'axe X
                .chartYScale(domain: -10...10) // Plage personnalisée pour l'axe Y
                .chartXAxis {
                    AxisMarks(position: .bottom, values: .automatic(desiredCount: 5))
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5))
                }
            }
            .padding()

            // Bouton pour afficher la feuille de connexion
            Button("Connect to Sphero") {
                showConnectSheet = true
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(8)
            .sheet(isPresented: $showConnectSheet) {
                VStack {
                    Text("Connect to Sphero")
                        .font(.title)
                        .padding()
                    
                    Button("Connect to Default Sphero") {
                        connectDefaultSphero() // Connexion au Sphero par défaut
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)

                    Button("Connect to Bottled Sphero") {
                        connectBottledSphero() // Connexion au Sphero spécifique
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .onAppear(perform: setupSensors)
        .onDisappear(perform: disableSensors)
    }

    private func startRecording() {
        isRecording.toggle()
        if isRecording {
            // Clear existing data
            acceleroData.removeAll()
            positionData.removeAll()
            velocity = [0, 0, 0]
            position = [0, 0, 0]
        }
    }

    private func setupSensors() {
        // Configuration des capteurs Sphero
        SharedToyBox.instance.bolt?.sensorControl.enable(sensors: SensorMask.init(arrayLiteral: .accelerometer))
        SharedToyBox.instance.bolt?.sensorControl.interval = 1
        
        SharedToyBox.instance.bolt?.setStabilization(state: SetStabilization.State.off)

        SharedToyBox.instance.bolt?.sensorControl.onDataReady = { data in
            DispatchQueue.main.async {
                if let acceleration = data.accelerometer?.filteredAcceleration {
                    let accData: double3 = [acceleration.x!, acceleration.y!, acceleration.z!]
                    acceleroData.append(accData)
                    updatePosition(with: accData)
                }
            }
        }
    }

    private func updatePosition(with acceleration: double3) {
        let deltaTime: Double = 0.1 // Intervalle de temps entre les mesures (ajustez si nécessaire)

        // Mise à jour de la vitesse
        velocity += acceleration * deltaTime

        // Mise à jour de la position (nous ignorons ici l'axe Z)
        position += velocity * deltaTime

        // Ajout des données à la liste des positions
        let newPoint = PositionDataPoint(x: position.x, y: position.y, timestamp: Date())
        positionData.append(newPoint)

        // Limiter la taille des données pour éviter des ralentissements
        if positionData.count > 500 {
            positionData.removeFirst()
        }
    }

    private func disableSensors() {
        SharedToyBox.instance.bolt?.sensorControl.disable()
    }

    private func connectDefaultSphero() {
        DispatchQueue.main.async {
            print("Searching for Default Sphero")
            SharedToyBox.instance.searchForBoltsNamed(["SB-8630"]) { err in
                if err == nil {
                    print("Connected")
                    isSpheroConnected = true
                    showConnectSheet = false
                    setupSensors()
                } else {
                    print("Failed to connect to Default Sphero")
                }
            }
        }
    }

    private func connectBottledSphero() {
        DispatchQueue.main.async {
            print("Searching for Bottled Sphero")
            SharedToyBox.instance.searchForBoltsNamed(["SB-313C"]) { err in
                if err == nil {
                    print("Connected")
                    isSpheroConnected = true
                    showConnectSheet = false
                    setupSensors()
                } else {
                    print("Failed to connect to Bottled Sphero")
                }
            }
        }
    }
}

struct SpheroSensorControlView_Previews: PreviewProvider {
    static var previews: some View {
        SpheroSensorControlView()
    }
}
