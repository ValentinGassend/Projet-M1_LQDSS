import SwiftUI
import Foundation

struct SpheroRotationDetectorView: View {
    enum Classes: Hashable {
        case turn
        case bin
        // Autres cas

        func hash(into hasher: inout Hasher) {
            switch self {
            case .turn:
                hasher.combine(0)
            case .bin:
                hasher.combine(1)
            }
        }
    }
    @Binding var isSpheroConnected: Bool
    
    // Configuration des critères
    private let rotationThreshold: Double = 5.0 // Seuil de vitesse angulaire (en rad/s)
    private let detectionDuration: Double = 2.0 // Durée minimum de rotation (en secondes)
    
    // État d'enregistrement
    @State private var isRecording = false
    @State private var gyroData: [GyroData] = [] // Utilisation de la struct GyroData
    @State private var isRotationDetected = false
    @State private var rotationDirection: String = "None" // Sens de rotation
    @State private var detectionStartTime: TimeInterval?
    @State private var accumulatedRotation: Double = 0.0 // Rotation accumulée en radians
    @State private var clockwiseTurns: Int = 0 // Nombre de tours horaires
    @State private var consecutiveSamples: Int = 0 // Nombre d'échantillons consécutifs dépassant le seuil
    @State private var predictionResult: String = "None"

    // Dossiers de sauvegarde
    private let turnFolderName = "one_turn"
    private let trashFolderName = "trash"
    
    // Struct pour encapsuler les données du gyroscope
    struct GyroData: Codable {
        let time: TimeInterval
        let zRotation: Double
    }
    
    // Réseau de neurones
    @State var neuralNet: FFNN? = nil
    @State private var movementData: [Classes: [[Double]]] = [
        .turn: [],
        .bin: []
    ] // Initialisation de movementData avec des tableaux vides

    @State private var showSaveChoiceAlert = false // Show the alert for save choice
    @State private var isTurnChosen = false // Track if "turn" is chosen

    // Exemple de méthode qui nécessite la conversion des types
    private func addTurnData(data: [Float], isTurn: Bool) {
        // Convertir [Float] en [Double]
        let doubleData = data.map { Double($0) }
        
        // Ajouter les données dans le dictionnaire
        let key: Classes = isTurn ? .turn : .bin
        if movementData[key] == nil {
            movementData[key] = []
        }
        movementData[key]?
            .append(
                doubleData
            )  // Ajouter les données converties dans le tableau approprié
    }

    init(isSpheroConnected: Binding<Bool>) {
        self._isSpheroConnected = isSpheroConnected
        neuralNet = FFNN(
            inputs: 1800,
            hidden: 20,
            outputs: 2,
            learningRate: 0.3,
            momentum: 0.2,
            weights: nil,
            activationFunction: .Sigmoid,
            errorFunction: .crossEntropy(average: false)
        )
    }
    
    // Méthode de lecture des données gyroscopiques
    private func startRecording() {
        guard isSpheroConnected else {
            print("Sphero not connected!")
            return
        }
            
        gyroData.removeAll()
        detectionStartTime = nil
        isRotationDetected = false
        rotationDirection = "None"
        accumulatedRotation = 0.0
        clockwiseTurns = 0
        consecutiveSamples = 0 // Réinitialisation du compteur
            
        SharedToyBox.instance.bolt?.sensorControl
            .enable(sensors: [.gyro]) // Activation des capteurs
        SharedToyBox.instance.bolt?.sensorControl.interval = 100 // Intervalle d'échantillonnage (ms)
            
        SharedToyBox.instance.bolt?.sensorControl.onDataReady = { data in
            DispatchQueue.main.async {
                if let gyro = data.gyro?.rotationRate {
                    let currentTime = Date().timeIntervalSince1970
                    let zRotation = Double(
                        gyro.z ?? 0
                    ) // Lecture de la rotation Z
                    let timeDifference = currentTime - (
                        self.gyroData.last?.time ?? currentTime
                    )
                    let deltaAngle = zRotation * timeDifference // Calculer l'angle tourné (en radians)

                    // Ajout des données
                    if self.isRecording {
                        self.gyroData
                            .append(
                                GyroData(
                                    time: currentTime,
                                    zRotation: zRotation
                                )
                            )
                        self.updateRotationCount(
                            zRotation: zRotation,
                            deltaAngle: deltaAngle
                        )
                        self.rotationDirection = zRotation > 0 ? "Clockwise" : (
                            zRotation < 0 ? "Counter-Clockwise" : "None"
                        )
                    }

                    self.checkRotationDetection(
                        zRotation: zRotation,
                        currentTime: currentTime
                    )
                        
                    // Logs des données
                    print(
                        "Time: \(currentTime), Z-Rotation: \(zRotation), Accumulated Rotation: \(self.accumulatedRotation), Clockwise Turns: \(self.clockwiseTurns)"
                    )
                }
            }
        }
    }
    
    // Arrêt de l'enregistrement
    private func stopRecording() {
        isRecording = false
        SharedToyBox.instance.bolt?.sensorControl.onDataReady = nil
        SharedToyBox.instance.bolt?.sensorControl
            .disable() // Désactivation des capteurs
        neuralNet = FFNN(
            inputs: gyroData.count,
            hidden: 20,
            outputs: 2,
            learningRate: 0.3,
            momentum: 0.2,
            weights: nil,
            activationFunction: .Sigmoid,
            errorFunction: .crossEntropy(average: false)
        )
        // Demander à l'utilisateur où enregistrer le fichier
        classifyRotationData()
        showSaveChoiceAlert = true
    }
    
    // Mise à jour de la rotation accumulée et des tours horaires
    private func updateRotationCount(zRotation: Double, deltaAngle: Double) {
        accumulatedRotation += deltaAngle

        while accumulatedRotation >= 2 * .pi {
            clockwiseTurns += 1
            accumulatedRotation -= 2 * .pi
        }
        while accumulatedRotation <= -2 * .pi {
            clockwiseTurns -= 1
            accumulatedRotation += 2 * .pi
        }
    }
    
    // Sauvegarder les données dans le dossier approprié
    private func saveGyroDataToFile(isTurn: Bool) {
        guard !gyroData.isEmpty else { return }
        
        // Choisir le dossier basé sur la classification
        let folderName = isTurn ? turnFolderName : trashFolderName
        let folderURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(
            folderName
        )

        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default
                    .createDirectory(
                        at: folderURL,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
            } catch {
                print("Error creating directory: \(error)")
                return
            }
        }

        let filename = "gyro_data_\(Date().timeIntervalSince1970).json"
        let fileURL = folderURL.appendingPathComponent(filename)

        do {
            let jsonData = try JSONEncoder().encode(gyroData)
            try jsonData.write(to: fileURL)
            print("Gyro data saved to: \(fileURL)")
        } catch {
            print("Error saving gyro data: \(error)")
        }
    }

    
    // Vérifier si les critères de rotation sont remplis
    private func checkRotationDetection(
        zRotation: Double,
        currentTime: TimeInterval
    ) {
        if abs(zRotation) > 0.0 {  // Si la rotation Z n'est pas nulle
            if !isRecording {  // Démarre l'enregistrement immédiatement
                startRecording()
            }

            consecutiveSamples += 1 // Incrémenter le compteur si la rotation dépasse le seuil
            detectionStartTime = currentTime // Reset du temps de détection
        } else {
            consecutiveSamples = 0 // Réinitialiser le compteur si la rotation est en dessous du seuil
            if isRecording && (currentTime - (detectionStartTime ?? currentTime)) > detectionDuration {
                stopRecording()  // Arrêter l'enregistrement si la rotation est en-dessous du seuil pendant un certain temps
            }
        }
    }

    
    // Fonction pour classifier les données et les enregistrer
    private func classifyRotationData() {
        guard !gyroData.isEmpty else { return }
        
        // Récupérer les données de rotation
        let rotationData = gyroData.map { Double($0.zRotation) }
        let normalizedData = normalize(rotationData)

        // Prediction via le réseau de neurones
        do {
            let prediction = try neuralNet?.update(inputs: normalizedData)
            
            // Si le réseau de neurones prédit que c'est un "turn"
            let isTurn = prediction?[0] ?? 0.0 > 0.5 // Si la probabilité de "turn" est > 0.5
            predictionResult = isTurn ? "Turn" : "Trash"

            
            print("prediction value: \(prediction?[0] ?? 0.0)")
            // Ajouter les données au bon dossier
            addTurnData(data: normalizedData, isTurn: isTurn)
            
            print("Data classified as: \(isTurn ? "Turn" : "Trash")")
        } catch {
            print("Error predicting rotation data: \(error)")
            predictionResult = "Error in Prediction"

        }
    }
    private func handleGyroData(zRotation: Double) {
        if !isRecording {
            // Si l'enregistrement n'est pas encore démarré, le démarrer dès qu'un mouvement est détecté
            isRecording = true
            gyroData.removeAll()  // Réinitialisation des données
            detectionStartTime = Date().timeIntervalSince1970
        }

        // Si l'enregistrement est en cours, ajoute les données
        if isRecording {
            let currentTime = Date().timeIntervalSince1970
            gyroData.append(GyroData(time: currentTime, zRotation: zRotation))
            print(
                "Data recorded: Time: \(currentTime), Z-Rotation: \(zRotation)"
            )
        }
    }


    // Normalisation des données d'entrée
    private func normalize(_ data: [Double]) -> [Float] {
        let min = data.min() ?? 0.0
        let max = data.max() ?? 1.0
        return data.map { Float(($0 - min) / (max - min)) }
    }
    
    // Vue principale
    var body: some View {
        VStack {
            Text("Prediction: \(predictionResult)")
                .font(.headline)
                .foregroundColor(.orange)
                .padding()

            Text(
                isSpheroConnected ? "Sphero Connected" : "Sphero Not Connected"
            )
            .foregroundColor(isSpheroConnected ? .green : .red)                    
            .padding()

            
            HStack {
                
                Button("Start Recording") {
                    isRecording = true
                    startRecording()
                }
                .disabled(isRecording || !isSpheroConnected)
                .padding()
                .background(isRecording ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Stop Recording") {
                    stopRecording()
                }
                .disabled(!isRecording)
                .padding()
                .background(!isRecording ? Color.gray : Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            if isRotationDetected {
                Text("Rotation Detected!")
                    .font(.headline)
                    .foregroundColor(.green)                    .padding()

            } else {
                Text("No Rotation Detected")
                    .font(.headline)
                    .foregroundColor(.red)                    .padding()

            }
            
            Text("Rotation Direction: \(rotationDirection)")
                .font(.headline)
                .foregroundColor(.blue)
                .padding()
            
            Text("Clockwise Turns: \(clockwiseTurns)")
                .font(.headline)
                .foregroundColor(.purple)
                .padding()
            
            Text("Recorded Samples: \(gyroData.count)")
                .padding()
        }
        .padding()
        .onAppear {
            if isSpheroConnected {
                SharedToyBox.instance.bolt?.setStabilization(state: .off)
                // Commence à surveiller les mouvements gyroscopiques
                SharedToyBox.instance.bolt?.sensorControl
                    .enable(sensors: [.gyro])
                SharedToyBox.instance.bolt?.sensorControl.interval = 100  // Intervalle d'échantillonnage (ms)
                
                // On configure la callback pour détecter les mouvements
                SharedToyBox.instance.bolt?.sensorControl.onDataReady = { data in
                    // Vérifie s'il y a des données du gyroscope
                    if let gyro = data.gyro?.rotationRate {
                        let zRotation = Double(gyro.z ?? 0)
                        
                        // Si c'est la première donnée détectée, commence l'enregistrement
                        if !self.isRecording && abs(zRotation) > 0.0 {
                            self.startRecording()
                        }
                        
                        // Continue à surveiller et enregistrer les données dès que l'enregistrement est lancé
                        if self.isRecording {
                            self.handleGyroData(zRotation: zRotation)
                        }
                    }
                }
            }
        }

        .actionSheet(isPresented: $showSaveChoiceAlert) {
            ActionSheet(
                title: Text("Save Gyro Data"),
                message: Text("Choose how to save the data:"),
                buttons: [
                    .default(Text("Save as Turn")) {
                        isTurnChosen = true
                        saveGyroDataToFile(isTurn: true)
                    },
                    .default(Text("Save as Trash")) {
                        isTurnChosen = false
                        saveGyroDataToFile(isTurn: false)
                    },
                    .cancel(Text("Don't Save")) {
                        print("User chose not to save the data.")
                    }
                ]
            )
        }

    }
}
