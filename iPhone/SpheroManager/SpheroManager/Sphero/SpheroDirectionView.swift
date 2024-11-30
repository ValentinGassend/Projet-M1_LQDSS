import SwiftUI
import AVFoundation
import simd

struct SpheroDirectionView: View {
    @Binding var isSpheroConnected: Bool
    @Binding var connectedSpheroNames: [String]
    
    enum Classes: Int {
        case Carre, Triangle, Rond
        
        func neuralNetResponse() -> [Double] {
            switch self {
            case .Carre: return [1.0, 0.0, 0.0]
            case .Triangle: return [0.0, 1.0, 0.0]
            case .Rond: return [0.0, 0.0, 1.0]
            }
        }
    }
    
    
    @State private var inputQuantity: Double = 1800
    @State private var currentSpeed: Double = 0
    @State private var currentHeading: Double = 0
    @State private var detectedShape: Classes?
    @State private var neuralNet: FFNN? = nil
    // .default(average: true))
    //
    @State private var isStopped: Bool = false
    @State private var movementData = [Classes: [[Double]]]()
    @State private var selectedClass: Classes = .Carre
    @State private var isRecording = false
    @State private var isPredicting = false
    @State private var isCollisionDetected = false
    @State private var currentAccData = [Double]()
    @State private var currentGyroData = [Double]()
    @State private var isMovingInPattern = false

    // Assuming GraphView is a UIKit component, we can use a UIViewRepresentable for SwiftUI
    
    // This will handle the sensor data callback
    private func handleSensorData(data: SensorData) {
        DispatchQueue.main.async {
            if (isRecording) {
                if (!isStopped) {
                    if let acceleration = data.accelerometer?.filteredAcceleration {
                        currentAccData
                            .append(
                                contentsOf: [
                                    acceleration.x!,
                                    acceleration.y!,
                                    acceleration.z!
                                ]
                            )
                        //                    print(currentAccData)
                        
                    }
                }
            }
            
        }
    }
    //    TODO: add lunching startRecording (on collision detected for defaultSphero)
    func onCollisionDetected(_ toy: BoltToy) {
        print(self.isCollisionDetected)
        
        // Vérifier si une collision a déjà été détectée et si l'enregistrement est en cours
        toy.onCollisionDetected = { collisionData in
            if !self.isCollisionDetected && !self.isRecording {

                print("Collision detected!")
                
                self.isCollisionDetected = true
                
                if connectedSpheroNames.contains("default") {
                    print(
                        "Collision trouvé pour defaultSphero, lancement de l'enregistrement... "
                    )
                    self.startRecording()
                }
                if connectedSpheroNames.contains("bottled") {
                    print(
                        "Collision trouvé pour bottledSphero, lancement de l'enregistrement... "
                    )
                    // Si vous souhaitez ajouter un comportement spécifique pour bottledSphero, faites-le ici.
                }
            }
            else if self.isRecording {
                // Si l'enregistrement est déjà en cours, ne pas relancer la détection de collision
                print(
                    "Collision déjà détectée, enregistrement en cours, pas de relance."
                )
            } else {
                // Si une collision a déjà été détectée mais l'enregistrement est terminé
                print(
                    "Collision déjà détectée, mais l'enregistrement est terminé."
                )
            }
        }
        
    }

    
    // Débuter l'enregistrement
    func startRecording() {
        isRecording = true
        isPredicting = false
        isStopped = false
        currentAccData.removeAll() // Réinitialisation
        print("Recording started...")
    }

    // Fin de l'enregistrement
    func stopRecording() {
        isRecording = false
        isStopped = true
            
        guard !currentAccData.isEmpty else {
            print("No data recorded.")
            return
        }
            
        let minAcc = currentAccData.min()!
        let maxAcc = currentAccData.max()!
        let normalizedAcc = currentAccData.map {
            ($0 - minAcc) / (maxAcc - minAcc)
        }
        inputQuantity = Double(currentAccData.count)
        //            movementData[selectedClass, default: []].append(normalizedAcc)
        print("Recording stopped.")
        //            currentAccData.removeAll()
    }

    // Prédiction
    func predictShape() {
        isRecording = false
        isPredicting = true
        isCollisionDetected = false
        guard !currentAccData.isEmpty else {
            print("No data available for prediction.")
            return
        }
            
        let minAcc = currentAccData.min()!
        let maxAcc = currentAccData.max()!
        let normalizedAcc = currentAccData.map {
            ($0 - minAcc) / (maxAcc - minAcc)
        }
        let normalizedAccFloat = normalizedAcc.map { Float($0) }
            
        do {
            if let prediction = try neuralNet?.update(
                inputs: normalizedAccFloat
            ),
               let maxIndex = prediction.firstIndex(of: prediction.max()!) {
                detectedShape = Classes(rawValue: maxIndex)
                print("Predicted shape: \(detectedShape!)")
            }
        } catch {
            print("Prediction error: \(error.localizedDescription)")
        }
        currentAccData.removeAll()
    }
    
    // Training button action
    private func trainNetwork() {
        // TRAINING LOGIC
        for _ in 0...20 {
            if let selectedClass = movementData.randomElement(),
               let input = selectedClass.value.randomElement() {
                let expectedResponse = selectedClass.key.neuralNetResponse()
                
                let floatInput = input.map { Float($0) }
                let floatRes = expectedResponse.map { Float($0) }
                
                try! neuralNet?.update(inputs: floatInput)
                try! neuralNet?.backpropagate(answer: floatRes)
            }
        }
        
        // VALIDATION LOGIC
        for k in movementData.keys {
            let values = movementData[k]!
            for v in values {
                let floatInput = v.map { Float($0) }
                let prediction = try! neuralNet?.update(inputs: floatInput)
                print("Prediction: \(prediction!)")
            }
        }
    }
    
    
    // MARK: - Movement Methods with Shape Detection
    func moveInCircle() {
        guard isSpheroConnected else {
            print("Sphero not connected!")
            return
        }
        isMovingInPattern = true
        currentSpeed = 50
        let totalSteps = 100
        let rotateBy = 360.0 / Double(totalSteps)
        var currentAngle = 0.0
    
        func moveToNextStep(step: Int) {
            if step >= totalSteps {
                SharedToyBox.instance.bolts
                    .forEach { $0.stopRoll(heading: Double(currentAngle)) }
                isMovingInPattern = false
                return
            }
    
            SharedToyBox.instance.bolts
                .forEach {
                    $0
                        .roll(
                            heading: Double(currentAngle),
                            speed: Double(currentSpeed)
                        )
                }
            currentAngle += rotateBy
    
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                moveToNextStep(step: step + 1)
            }
        }
        selectedClass = .Rond
        //startShapeDetection()
        moveToNextStep(step: 0)
    }
    func moveInSquare() {
        guard isSpheroConnected else {
            print("Sphero not connected!")
            return
        }
    
        isMovingInPattern = true
        currentSpeed = 50
    
        let totalSteps = 4
        let rotateBy = 90.0
        var currentAngle = 0.0
    
        func moveToNextStep(step: Int) {
            if step >= totalSteps {
                SharedToyBox.instance.bolts.forEach { bolt in
                    bolt.stopRoll(heading: Double(currentAngle))
                }
                isMovingInPattern = false
                return
            }
    
            SharedToyBox.instance.bolts.forEach { bolt in
                bolt
                    .roll(
                        heading: Double(currentAngle),
                        speed: Double(currentSpeed)
                    )
            }
    
            currentAngle += rotateBy
    
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                moveToNextStep(step: step + 1)
            }
        }
        selectedClass = .Carre
    
            
        isPredicting = true
        moveToNextStep(step: 0)
    }
    
    private func stopPredictAnyTime() {
        print("currentAccData = \(currentAccData.count)")
        neuralNet = FFNN(
            inputs: currentAccData.count,
            hidden: 20,
            outputs: 3,
            learningRate: 0.3,
            momentum: 0.2,
            weights: nil,
            activationFunction: .Sigmoid,
            errorFunction:.crossEntropy(average: false)
        )
        inputQuantity = Double(currentAccData.count)
        
        print("inputQuantity = \(inputQuantity)")
        isStopped = true;
    }
    func moveInTriangle() {
        guard isSpheroConnected else {
            print("Sphero not connected!")
            return
        }
    
        isMovingInPattern = true
        currentSpeed = 50
    
        let totalSteps = 3
        let rotateBy = 120.0
        var currentAngle = 0.0
    
        func moveToNextStep(step: Int) {
            if step >= totalSteps {
                SharedToyBox.instance.bolts.forEach { bolt in
                    bolt.stopRoll(heading: Double(currentAngle))
                }
                isMovingInPattern = false
                return
            }
    
            SharedToyBox.instance.bolts.forEach { bolt in
                bolt
                    .roll(
                        heading: Double(currentAngle),
                        speed: Double(currentSpeed)
                    )
            }
    
            currentAngle += rotateBy
    
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                moveToNextStep(step: step + 1)
            }
        }
        selectedClass = .Triangle
        //startShapeDetection()
        moveToNextStep(step: 0)
    }
    
    // View body for SwiftUI
    var body: some View {
        
        ScrollView {
            // Collision message
            //                    Button
            //                    Text(collisionLabelText)
            //                        .font(.title)
            //                        .foregroundColor(.red)
            //                        .padding()
        
            // Current Speed and Heading
            Text("Speed: \(currentSpeed, specifier: "%.2f")")
                .padding()
            Text("Input quantity: \(inputQuantity, specifier: "%.2f")")
                .padding()
            if let shape = detectedShape {
                
                Text("Detected Shape: \(shape)").font(.title)
                    .foregroundColor(.blue)
                    .padding()
                
            }
        
            // Start Circle Movement Button
            Button(action: {
                moveInCircle()
            }) {
                Text(isMovingInPattern ? "Moving in Circle..." : "Start Circle")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(isMovingInPattern ? Color.gray : Color.blue)
                    .cornerRadius(10)
                    .disabled(isMovingInPattern || !isSpheroConnected)
            }
            .padding()
        
            // Start Square Movement Button
            Button(action: {
                moveInSquare()
            }) {
                Text(isMovingInPattern ? "Moving in Square..." : "Start Square")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(isMovingInPattern ? Color.gray : Color.green)
                    .cornerRadius(10)
                    .disabled(isMovingInPattern || !isSpheroConnected)
            }
            .padding()
        
            // Start Triangle Movement Button
            Button(action: {
                moveInTriangle()
            }) {
                Text(
                    isMovingInPattern ? "Moving in Triangle..." : "Start Triangle"
                )
                .font(.title)
                .foregroundColor(.white)
                .padding()
                .background(isMovingInPattern ? Color.gray : Color.red)
                .cornerRadius(10)
                .disabled(isMovingInPattern || !isSpheroConnected)
            }
            .padding()
        
            // Display a message if not connected
            if !isSpheroConnected {
                Text("Please connect to a Sphero to start moving!")
                    .foregroundColor(.red)
                    .font(.headline)
                    .padding()
            }
        
            Spacer()
        
            // Speed slider
            Slider(value: $currentSpeed, in: 0...255, step: 1)
                .padding()
                .onChange(of: currentSpeed) { newValue in
                    SharedToyBox.instance.bolts.forEach {
                        $0
                            .roll(
                                heading: Double(currentHeading),
                                speed: Double(newValue)
                            )
                    }
                }
            Slider(value: $inputQuantity, in: 450...1800, step: 2)
                .padding()
                .onChange(of: inputQuantity) { newValue in
                    inputQuantity = newValue
                    neuralNet = FFNN(
                        inputs: Int(newValue),
                        hidden: 20,
                        outputs: 3,
                        learningRate: 0.3,
                        momentum: 0.2,
                        weights: nil,
                        activationFunction: .Sigmoid,
                        errorFunction:.crossEntropy(average: false)
                    )
                }
            // Heading slider
            //            Slider(value: $currentHeading, in: 0...360, step: 1)
            //                .padding()
            //                .onChange(of: currentHeading) { newValue in
            //                    SharedToyBox.instance.bolts.forEach {
            //                        $0.stopRoll(heading: Double(newValue))
            //                    }
            //                }
        
            Spacer()
        
        }
        .padding()
        .onAppear {
            if !isSpheroConnected {
                //                    connectToSphero()
            }
            // Initial setup for the SharedToyBox or other configurations can go ici
        }
        VStack {
            HStack {
                if (!isRecording) {

                    Button(action: { startRecording() }) {
                        Text("Start Recording")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                                
                if (isRecording) {
                    Button(action: { stopRecording() }) {
                        Text("Stop Recording")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                if (isStopped) {
                    Button(action: { predictShape() }) {
                        Text("Predict Shape")
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                
                Button("Train") {
                    trainNetwork()
                }
            }
            
            Picker("Select Class", selection: $selectedClass) {
                Text("Square").tag(Classes.Carre)
                Text("Circle").tag(Classes.Rond)
                Text("Triangle").tag(Classes.Triangle)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            
        }
        .onAppear {
            neuralNet = FFNN(
                inputs: Int(inputQuantity),
                hidden: 20,
                outputs: 3,
                learningRate: 0.3,
                momentum: 0.2,
                weights: nil,
                activationFunction: .Sigmoid,
                errorFunction:.crossEntropy(average: false)
            )// .default(average: true))
            //
            // Setup sensor control here
            SharedToyBox.instance.bolt?.sensorControl
                .enable(
                    sensors: SensorMask(arrayLiteral: .accelerometer, .gyro)
                )
            SharedToyBox.instance.bolt?.sensorControl.interval = 1
            SharedToyBox.instance.bolt?.setStabilization(state: .off)
            SharedToyBox.instance.bolt?
                .setCollisionDetection(configuration: .enabled)
            SharedToyBox.instance.bolt?.sensorControl.onDataReady = { data in
                handleSensorData(data: data)
            }
            if let boltToy = SharedToyBox.instance.bolt {
                onCollisionDetected(boltToy)

            }
        }
        .onDisappear {
            SharedToyBox.instance.bolt?.sensorControl.disable()
        }
    }
}

