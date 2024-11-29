import SwiftUI
import AVFoundation
import simd

struct SpheroDirectionView: View {
        @Binding var isSpheroConnected: Bool

    
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
    @State private var movementData = [Classes: [[Double]]]()
    @State private var selectedClass: Classes = .Carre
    @State private var isRecording = false
    @State private var isPredicting = false
    @State private var currentAccData = [Double]()
    @State private var currentGyroData = [Double]()
    @State private var isMovingInPattern = false

    // Assuming GraphView is a UIKit component, we can use a UIViewRepresentable for SwiftUI
    
    // This will handle the sensor data callback
    private func handleSensorData(data: SensorData) {
        DispatchQueue.main.async {
            if isRecording || isPredicting {
                if let acceleration = data.accelerometer?.filteredAcceleration {
                    currentAccData.append(contentsOf: [acceleration.x!, acceleration.y!, acceleration.z!])
//                    print(currentAccData)
                    
                }
                
                if let gyro = data.gyro?.rotationRate {
                    currentGyroData.append(contentsOf: [Double(gyro.x!), Double(gyro.y!), Double(gyro.z!)])
                }
                print(currentAccData.count)
                if currentAccData.count >= Int(inputQuantity) {
                    if self.isRecording {
                        self.isRecording = false
                        
                        // Normalisation
                        let minAcc = currentAccData.min()!
                        let maxAcc = currentAccData.max()!
                        let normalizedAcc = currentAccData.map { ($0 - minAcc) / (maxAcc - minAcc) }
                        
                        let minGyr = currentGyroData.min()!
                        let maxGyr = currentGyroData.max()!
                        let normalizedGyr = currentGyroData.map { ($0 - minGyr) / (maxGyr - minGyr) }
                        
                        self.movementData[self.selectedClass]?.append(normalizedAcc)
                        currentAccData = []
                        currentGyroData = []
                    }
                    
                    if self.isPredicting {
                        self.isPredicting = false
                        
                        // Normalisation for prediction
                        if let minAcc = currentAccData.min(), let maxAcc = currentAccData.max() {
                            let normalizedAcc = currentAccData.map { ($0 - minAcc) / (maxAcc - minAcc) }
                            let normalizedAccFloat = normalizedAcc.map { Float($0) }
                            
                            let prediction = try! self.neuralNet?.update(inputs: normalizedAccFloat)
                            let index = prediction?.firstIndex(of: (prediction?.max()!)!)!
                            
                            let recognizedClass = Classes(rawValue: index!)!
                            print("Recognized class: \(recognizedClass)")
                            detectedShape = recognizedClass
                            
                            var str = "I think it's a "
                            switch recognizedClass {
                            case .Carre: str += "square!"
                            case .Rond: str += "circle!"
                            case .Triangle: str += "triangle!"
                            }
                            
                            currentAccData = []
                            currentGyroData = []
                        } else {
                            print("Accelerometer data is empty!")
                        }
                    }
                }
            }
        }
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
                    SharedToyBox.instance.bolts.forEach { $0.stopRoll(heading: Double(currentAngle)) }
                    isMovingInPattern = false
                    return
                }
    
                SharedToyBox.instance.bolts.forEach { $0.roll(heading: Double(currentAngle), speed: Double(currentSpeed)) }
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
                            neuralNet = FFNN(inputs: Int(newValue), hidden: 20, outputs: 3, learningRate: 0.3, momentum: 0.2, weights: nil, activationFunction: .Sigmoid, errorFunction:.crossEntropy(average: false))
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
                Button("Start Recording") {
                    isRecording = true
                }
                
                Button("Predict") {
                    isPredicting = true
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
            neuralNet = FFNN(inputs: Int(inputQuantity), hidden: 20, outputs: 3, learningRate: 0.3, momentum: 0.2, weights: nil, activationFunction: .Sigmoid, errorFunction:.crossEntropy(average: false))// .default(average: true))
            //
            // Setup sensor control here
            SharedToyBox.instance.bolt?.sensorControl.enable(sensors: SensorMask(arrayLiteral: .accelerometer, .gyro))
            SharedToyBox.instance.bolt?.sensorControl.interval = 1
            SharedToyBox.instance.bolt?.setStabilization(state: .off)
            SharedToyBox.instance.bolt?.sensorControl.onDataReady = { data in
                handleSensorData(data: data)
            }
        }
        .onDisappear {
            SharedToyBox.instance.bolt?.sensorControl.disable()
        }
    }
    
//    
//    // MARK: - State Variables
//    @State private var currentSpeed: Double = 0
//    @State private var currentHeading: Double = 0
//    @State private var isMovingInPattern = false
//    @State private var collisionLabelText = ""
//    @State private var pathPoints: [CGPoint] = []
//    @State private var detectedShape: String = ""
//    
//    @Binding var isSpheroConnected: Bool
//    @State private var nbBolts = SharedToyBox.instance.bolts.count
//    @State private var spheroPosition = CGPoint(x: 200, y: 200)
//    
//    // Neural Network related variables
//    @State private var currentAccData: [Double] = []
//    @State private var neuralNet: FFNN? = nil
//    
//    
//    var movementData = [Classes:[[Double]]]()
//    @State var selectedClass = Classes.Carre
//    
//    enum Classes:Int {
//        case Carre,Triangle,Rond
//        
//        func neuralNetResponse() -> [Double] {
//            switch self {
//            case .Carre: return [1.0,0.0,0.0]
//            case .Triangle: return [0.0,1.0,0.0]
//            case .Rond: return [0.0,0.0,1.0]
//            }
//        }
//        
//    }
//    // MARK: - Initialization
//    init(isSpheroConnected: Binding<Bool>) {
//        self._isSpheroConnected = isSpheroConnected
//        setupNeuralNetwork()
//        movementData[.Carre] = []
//        movementData[.Rond] = []
//        movementData[.Triangle] = []
//    }
//    
//    // MARK: - Neural Network Setup
//    private func setupNeuralNetwork() {
//        self.neuralNet = FFNN(inputs: 1800, hidden: 20, outputs: 3, learningRate: 0.3, momentum: 0.2, weights: nil, activationFunction: .Sigmoid, errorFunction:.crossEntropy(average: false))// .default(average: true))
//        
////        print(self.neuralNet!)
//        print("Neural Network setup complete with improved architecture.")
//    }
//    
//    // MARK: - Shape Detection Methods
//    private func //startShapeDetection() {
//        print("Starting shape detection...")
//        currentAccData = [] // Reset data collection
//        
//        // Enable sensor data collection
//        SharedToyBox.instance.bolt?.sensorControl
//            .enable(sensors: SensorMask.init(arrayLiteral: .accelerometer))
//        SharedToyBox.instance.bolt?.sensorControl.interval = 1
//        
//        SharedToyBox.instance.bolt?.sensorControl.onDataReady = { data in
//            DispatchQueue.main.async {
//                if let acceleration = data.accelerometer?.filteredAcceleration {
//                    // Collect acceleration data
//                    self.currentAccData.append(contentsOf: [
//                        acceleration.x!,
//                        acceleration.y!,
//                        acceleration.z!
//                    ])
//                    print(self.currentAccData.count)
//                    // Predict shape when enough data is collected
//                    if self.currentAccData.count >= 100 {
//                        print("Enough data collected, predicting shape...")
//                        self.predictShape()
//                        SharedToyBox.instance.bolt?.sensorControl.disable()
//                    }
//                }
//            }
//        }
//    }
//    
//    private func predictShape() {
//        print("Predicting shape...")
//        
//        // Normalize the acceleration data
//        
//        let minAcc = currentAccData.min()!
//        let maxAcc = currentAccData.max()!
//        let normalizedAcc = currentAccData.map { Float(($0 - minAcc) / (maxAcc - minAcc)) }
//
//        print("Normalized acceleration data: \(normalizedAcc)")
//        print("Normalized acceleration count: \(normalizedAcc.count)")
//        print(self.neuralNet!)
//        // Get prediction from neural network
//        guard let prediction = try? self.neuralNet?.update(inputs: normalizedAcc) else {
//            print("Prediction failed.")
//            return
//        }
//
//        // Find the index of the highest probability
//        let index = prediction.firstIndex(of: (prediction.max()!))! // [0.89,0.03,0.14]
//        
//        
//        let recognizedClass = Classes(rawValue: index)!
//        print(recognizedClass)
//        print(prediction)
//        // Afficher toutes les probabilités
//           print("Prediction probabilities:")
//           for (index, prob) in prediction.enumerated() {
//               print("Index: \(index), Probability: \(prob)")
//           }
//        // Map index to shape
//        let shape: String
//        switch index {
//        case 0:
//            shape = "Square"
//        case 1:
//            shape = "Triangle"
//        case 2:
//            shape = "Circle"
//        default:
//            shape = "Unknown"
//        }
//
//        // Update UI and speak the result
//        DispatchQueue.main.async {
//            print("Detected shape: \(shape)")
//            self.detectedShape = shape
//            }
//    }
//    
//    
//    func trainNetwork() {
//        
//        // --------------------------------------
//        // TRAINING
//        // --------------------------------------
//        for i in 0...20 {
//            print(i)
//            if let selectedClass = movementData.randomElement(),
//                let input = selectedClass.value.randomElement(){
//                let expectedResponse = selectedClass.key.neuralNetResponse()
//                
//                let floatInput = input.map{ Float($0) }
//                let floatRes = expectedResponse.map{ Float($0) }
//                
//                try! neuralNet?.update(inputs: floatInput) // -> [0.23,0.67,0.99]
//                try! neuralNet?.backpropagate(answer: floatRes)
//                
//            }
//        }
//        
//        // --------------------------------------
//        // VALIDATION
//        // --------------------------------------
//        for k in movementData.keys {
//            print("Inference for \(k)")
//            let values = movementData[k]!
//            for v in values {
//                let floatInput = v.map{ Float($0) }
//                let prediction = try! neuralNet?.update(inputs:floatInput)
//                print(prediction!)
//            }
//        }
//        
//    }
//    
//    // MARK: - Movement Methods with Shape Detection
//    func moveInCircle() {
//        guard isSpheroConnected else {
//            print("Sphero not connected!")
//            return
//        }
//        isMovingInPattern = true
//        currentSpeed = 50
//        let totalSteps = 100
//        let rotateBy = 360.0 / Double(totalSteps)
//        var currentAngle = 0.0
//        
//        func moveToNextStep(step: Int) {
//            if step >= totalSteps {
//                SharedToyBox.instance.bolts.forEach { $0.stopRoll(heading: Double(currentAngle)) }
//                isMovingInPattern = false
//                return
//            }
//            
//            SharedToyBox.instance.bolts.forEach { $0.roll(heading: Double(currentAngle), speed: Double(currentSpeed)) }
//            currentAngle += rotateBy
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                moveToNextStep(step: step + 1)
//            }
//        }
//        selectedClass = .Rond
//        //startShapeDetection()
//        moveToNextStep(step: 0)
//    }
//    func moveInSquare() {
//        guard isSpheroConnected else {
//            print("Sphero not connected!")
//            return
//        }
//        
//        isMovingInPattern = true
//        currentSpeed = 50
//        
//        let totalSteps = 4
//        let rotateBy = 90.0
//        var currentAngle = 0.0
//        
//        func moveToNextStep(step: Int) {
//            if step >= totalSteps {
//                SharedToyBox.instance.bolts.forEach { bolt in
//                    bolt.stopRoll(heading: Double(currentAngle))
//                }
//                isMovingInPattern = false
//                return
//            }
//            
//            SharedToyBox.instance.bolts.forEach { bolt in
//                bolt
//                    .roll(
//                        heading: Double(currentAngle),
//                        speed: Double(currentSpeed)
//                    )
//            }
//            
//            currentAngle += rotateBy
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
//                moveToNextStep(step: step + 1)
//            }
//        }
//        selectedClass = .Carre
//        
//        //startShapeDetection()
//        moveToNextStep(step: 0)
//    }
//    
//    func moveInTriangle() {
//        guard isSpheroConnected else {
//            print("Sphero not connected!")
//            return
//        }
//        
//        isMovingInPattern = true
//        currentSpeed = 50
//        
//        let totalSteps = 3
//        let rotateBy = 120.0
//        var currentAngle = 0.0
//        
//        func moveToNextStep(step: Int) {
//            if step >= totalSteps {
//                SharedToyBox.instance.bolts.forEach { bolt in
//                    bolt.stopRoll(heading: Double(currentAngle))
//                }
//                isMovingInPattern = false
//                return
//            }
//            
//            SharedToyBox.instance.bolts.forEach { bolt in
//                bolt
//                    .roll(
//                        heading: Double(currentAngle),
//                        speed: Double(currentSpeed)
//                    )
//            }
//            
//            currentAngle += rotateBy
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//                moveToNextStep(step: step + 1)
//            }
//        }
//        selectedClass = .Triangle
//        //startShapeDetection()
//        moveToNextStep(step: 0)
//    }
//    // MARK: - UI Layout
//    var body: some View {
//        ScrollView {
//            // Collision message
//            Button
//            Text(collisionLabelText)
//                .font(.title)
//                .foregroundColor(.red)
//                .padding()
//
//            // Current Speed and Heading
//            Text("Speed: \(currentSpeed, specifier: "%.2f")")
//                .padding()
//            Text("Heading: \(currentHeading, specifier: "%.2f")")
//                .padding()
//
//            Text("Detected Shape: \(detectedShape)")
//                .font(.title)
//                .foregroundColor(.blue)
//                .padding()
//               
//            // Start Circle Movement Button
//            Button(action: {
//                moveInCircle()
//            }) {
//                Text(isMovingInPattern ? "Moving in Circle..." : "Start Circle")
//                    .font(.title)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(isMovingInPattern ? Color.gray : Color.blue)
//                    .cornerRadius(10)
//                    .disabled(isMovingInPattern || !isSpheroConnected)
//            }
//            .padding()
//
//            // Start Square Movement Button
//            Button(action: {
//                moveInSquare()
//            }) {
//                Text(isMovingInPattern ? "Moving in Square..." : "Start Square")
//                    .font(.title)
//                    .foregroundColor(.white)
//                    .padding()
//                    .background(isMovingInPattern ? Color.gray : Color.green)
//                    .cornerRadius(10)
//                    .disabled(isMovingInPattern || !isSpheroConnected)
//            }
//            .padding()
//
//            // Start Triangle Movement Button
//            Button(action: {
//                moveInTriangle()
//            }) {
//                Text(
//                    isMovingInPattern ? "Moving in Triangle..." : "Start Triangle"
//                )
//                .font(.title)
//                .foregroundColor(.white)
//                .padding()
//                .background(isMovingInPattern ? Color.gray : Color.red)
//                .cornerRadius(10)
//                .disabled(isMovingInPattern || !isSpheroConnected)
//            }
//            .padding()
//
//            // Display a message if not connected
//            if !isSpheroConnected {
//                Text("Please connect to a Sphero to start moving!")
//                    .foregroundColor(.red)
//                    .font(.headline)
//                    .padding()
//            }
//
//            Spacer()
//
//            // Speed slider
//            Slider(value: $currentSpeed, in: 0...255, step: 1)
//                .padding()
//                .onChange(of: currentSpeed) { newValue in
//                    SharedToyBox.instance.bolts.forEach {
//                        $0
//                            .roll(
//                                heading: Double(currentHeading),
//                                speed: Double(newValue)
//                            )
//                    }
//                }
//
//            // Heading slider
//            //            Slider(value: $currentHeading, in: 0...360, step: 1)
//            //                .padding()
//            //                .onChange(of: currentHeading) { newValue in
//            //                    SharedToyBox.instance.bolts.forEach {
//            //                        $0.stopRoll(heading: Double(newValue))
//            //                    }
//            //                }
//
//            Spacer()
//
//            // Fixed size area for the path drawing
//            ZStack {
//                // Fixed-size rectangle for the drawing area
//                Rectangle()
//                    .fill(Color.gray.opacity(0.1))
//                    .frame(width: 200, height: 200) // Fixed size
//
//                // Draw the path dynamically
//                Path { path in
//                    if let firstPoint = pathPoints.first {
//                        path.move(to: firstPoint)
//                        for point in pathPoints.dropFirst() {
//                            path.addLine(to: point)
//                        }
//                    }
//                }
//                .stroke(Color.blue, lineWidth: 2)
//                .animation(
//                    .easeInOut,
//                    value: pathPoints.count
//                ) // Smooth animation
//            }
//            .padding()
//            .frame(width: 400, height: 800) // Fixed size
//
//            Spacer()
//
//        }
//        .padding()
//        .onAppear {
//            if !isSpheroConnected {
//                //                    connectToSphero()
//            }
//            // Initial setup for the SharedToyBox or other configurations can go ici
//        }
//    }
}

