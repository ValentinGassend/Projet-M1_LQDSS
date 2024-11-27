import SwiftUI

struct SpheroDirectionView: View {
    // MARK: - State Variables
    @State private var currentSpeed: Double = 0
    @State private var currentHeading: Double = 0
    @State private var isMovingInPattern = false // General flag for movement
    @State private var collisionLabelText = ""
    @State private var pathPoints: [CGPoint] = [] // Store path points for visualization

    @Binding var isSpheroConnected: Bool // Bind the connection status from the parent view
    @State private var nbBolts = SharedToyBox.instance.bolts.count
    @State private var boltCollision = [Bool]()
    
    @State private var isRecording = false // Flag to track if we're recording the movement
    @State private var spheroPosition = CGPoint(
        x: 200,
        y: 200
    ) // Starting position of the sphero


    // MARK: - Initialization
    init(isSpheroConnected: Binding<Bool>) {
        self._isSpheroConnected = isSpheroConnected
    }

    // MARK: - Function to update the sphero position
    func updateSpheroPosition(newPosition: CGPoint) {
        spheroPosition = newPosition
        if isRecording {
            pathPoints
                .append(
                    newPosition
                ) // Only add points to path if we're recording
        }
    }
    // MARK: - Circle Movement Logic
    
    
    func moveInCircle() {
        if !isSpheroConnected {
            print("Sphero not connected!")
            return
        }
        let totalSteps = 100
        let rotateBy = 360.0 / Double(totalSteps)
        var currentAngle = 0.0
        currentSpeed = 50
        isMovingInPattern = true
        
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
//            currentHeading = currentAngle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                moveToNextStep(step: step + 1)
            }
        }
        moveToNextStep(step: 0)

    }
    
    func moveInSquare() {
        if !isSpheroConnected {
            print("Sphero not connected!")
            return
        }
        let totalSteps = 4
        let rotateBy = 360.0 / Double(totalSteps)
        var currentAngle = 0.0
        currentSpeed = 50
        isMovingInPattern = true
        SharedToyBox.instance.bolts.forEach { bolt in
            bolt.setStabilization(state: SetStabilization.State.on)
        }
        func moveToNextStep(step: Int) {
            print(step)
            print(currentAngle)
            print(currentSpeed)
            if step >= totalSteps {
                SharedToyBox.instance.bolts.forEach { bolt in
                    bolt.stopRoll(heading: Double(currentAngle))
                }
                isMovingInPattern = false
                return
            }
            else {
            
                SharedToyBox.instance.bolts.forEach { bolt in
                    bolt
                        .roll(
                            heading: Double(currentAngle),
                            speed: Double(currentSpeed)
                        )
                }
                currentAngle += rotateBy
//                currentHeading = currentAngle
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    moveToNextStep(step: step + 1)
                }
            }
        }
        moveToNextStep(step: 0)

    }
    func moveInTriangle() {
        if !isSpheroConnected {
            print("Sphero not connected!")
            return
        }
        let totalSteps = 3
        let rotateBy = 360.0 / Double(totalSteps)
        var currentAngle = 0.0
        currentSpeed = 50
        isMovingInPattern = true
        
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
        moveToNextStep(step: 0)

    }
    //    func moveInCircle() {
    //        if !isSpheroConnected {
    //            print("Sphero not connected!")
    //            return
    //        }
    //
    //        let totalSteps = 100
    //        let rotateBy = 360.0 / Double(totalSteps)
    //        var currentAngle = 0.0
    //        var currentPosition = CGPoint(x: 200, y: 200) // Starting position
    //
    //        isMovingInPattern = true
    //        currentSpeed = 100
    //
    //        // Add the starting point to the path
    //        pathPoints = [currentPosition]
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
    //            // Calculate the new position based on current angle
    //            let radius: CGFloat = 50 // radius of the circle
    //            let x = currentPosition.x + radius * CGFloat(
    //                cos(currentAngle * .pi / 180)
    //            )
    //            let y = currentPosition.y + radius * CGFloat(
    //                sin(currentAngle * .pi / 180)
    //            )
    //            currentPosition = CGPoint(x: x, y: y)
    //
    //            // Add the new position to the path
    //            pathPoints.append(currentPosition)
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
    //            currentHeading = currentAngle
    //
    //            // Update the path every 0.1 seconds
    //            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    //                moveToNextStep(step: step + 1)
    //            }
    //        }
    //
    //        moveToNextStep(step: 0)
    //    }

    // MARK: - Square Movement Logic
//    func moveInSquare() {
//        if !isSpheroConnected {
//            print("Sphero not connected!")
//            return
//        }
//
//        let totalSides = 4
//        let anglePerTurn = 90.0
//        let sideLength = 50.0
//        var currentAngle = 0.0
//        var currentPosition = CGPoint(x: 200, y: 200)
//
//        isMovingInPattern = true
//        currentSpeed = 100
//
//        pathPoints = [currentPosition] // Start the path from the initial position
//
//        func moveToNextSide(side: Int) {
//            if side >= totalSides {
//                //                SharedToyBox.instance.bolts.forEach {
//                //                    $0.stopRoll(heading: Double(currentAngle))
//                //                }
//                isMovingInPattern = false
//                return
//            }
//
//            // Calculate new position after moving the side
//            let x = currentPosition.x + sideLength * CGFloat(
//                cos(currentAngle * .pi / 180)
//            )
//            let y = currentPosition.y + sideLength * CGFloat(
//                sin(currentAngle * .pi / 180)
//            )
//            currentPosition = CGPoint(x: x, y: y)
//
//            // Add the new position to the path
//            pathPoints.append(currentPosition)
//
//            SharedToyBox.instance.bolts.forEach {
//                $0.roll(
//                    heading: Double(currentAngle),
//                    speed: Double(currentSpeed)
//                )
//            }
//
//            currentAngle += anglePerTurn
//            currentHeading = currentAngle
//
//            // Update the path every 1 second
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                moveToNextSide(side: side + 1)
//            }
//        }
//
//        moveToNextSide(side: 0)
//    }
    

    // MARK: - Triangle Movement Logic
//    func moveInTriangle() {
//        if !isSpheroConnected {
//            print("Sphero not connected!")
//            return
//        }
//
//        let totalSides = 3
//        let anglePerTurn = 120.0
//        let sideLength = 50.0
//        var currentAngle = 0.0
//        var currentPosition = CGPoint(x: 200, y: 200)
//
//        isMovingInPattern = true
//        currentSpeed = 100
//
//        pathPoints = [currentPosition]
//
//        func moveToNextSide(side: Int) {
//            if side >= totalSides {
//                SharedToyBox.instance.bolts.forEach {
//                    $0.stopRoll(heading: Double(currentAngle))
//                }
//                isMovingInPattern = false
//                return
//            }
//
//            let x = currentPosition.x + sideLength * CGFloat(
//                cos(currentAngle * .pi / 180)
//            )
//            let y = currentPosition.y + sideLength * CGFloat(
//                sin(currentAngle * .pi / 180)
//            )
//            currentPosition = CGPoint(x: x, y: y)
//
//            pathPoints.append(currentPosition)
//
//            SharedToyBox.instance.bolts.forEach {
//                $0.roll(
//                    heading: Double(currentAngle),
//                    speed: Double(currentSpeed)
//                )
//            }
//
//            currentAngle += anglePerTurn
//            currentHeading = currentAngle
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                moveToNextSide(side: side + 1)
//            }
//        }
//
//        moveToNextSide(side: 0)
//    }

    // MARK: - UI Layout
    var body: some View {
        ScrollView {
            // Collision message
            Text(collisionLabelText)
                .font(.title)
                .foregroundColor(.red)
                .padding()

            // Current Speed and Heading
            Text("Speed: \(currentSpeed, specifier: "%.2f")")
                .padding()
            Text("Heading: \(currentHeading, specifier: "%.2f")")
                .padding()

            
            Button(action: {
                if isRecording {
                    // Stop recording
                    isRecording = false
                } else {
                    // Start recording
                    isRecording = true
                    // Clear the path points when starting a new recording
                    pathPoints = [spheroPosition]
                }
            }) {
                Text(isRecording ? "Stop Recording" : "Start Recording")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding()
                    .background(isRecording ? Color.red : Color.green)
                    .cornerRadius(10)
                    .disabled(!isSpheroConnected)
            }
            .padding()
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

            // Heading slider
//            Slider(value: $currentHeading, in: 0...360, step: 1)
//                .padding()
//                .onChange(of: currentHeading) { newValue in
//                    SharedToyBox.instance.bolts.forEach {
//                        $0.stopRoll(heading: Double(newValue))
//                    }
//                }

            Spacer()

            // Fixed size area for the path drawing
            ZStack {
                // Fixed-size rectangle for the drawing area
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 200, height: 200) // Fixed size

                // Draw the path dynamically
                Path { path in
                    if let firstPoint = pathPoints.first {
                        path.move(to: firstPoint)
                        for point in pathPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
                .animation(
                    .easeInOut,
                    value: pathPoints.count
                ) // Smooth animation
            }
            .padding()
            .frame(width: 400, height: 800) // Fixed size

            Spacer()

        }
        .padding()
        .onAppear {
            // Initial setup for the SharedToyBox or other configurations can go ici
        }
    }
}

struct SpheroDirectionView_Previews: PreviewProvider {
    static var previews: some View {
        SpheroDirectionView(isSpheroConnected: .constant(true))
    }
}

