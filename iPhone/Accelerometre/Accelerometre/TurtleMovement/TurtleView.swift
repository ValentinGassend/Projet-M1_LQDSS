//
//  TurtleView.swift
//  Accelerometre
//
//  Created by Al on 24/10/2024.
//

import SwiftUI

struct TurtleView: View {
    @StateObject private var orientationManager = OrientationManager()
    @StateObject private var movementManager = TurtleMovementManager()
    @State private var isMoving: Bool = false
    @State private var timer: Timer?
    @State private var isConnected: Bool = false
    
    private let colors: [Color] = [.red, .green, .blue]
    @State private var colorIndex: Int = 0

    @ObservedObject var wsClient = WebSocketClient.instance

    var body: some View {
        NavigationView {
            VStack {
                if isConnected {
                    mainContent
                } else {
                    Button("Connect") {
                        wsClient.connect(route: "moveRobot")
                        isConnected = true
                    }
                    .foregroundStyle(.green)
                    .bold()
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Turtle Control")
                        .font(.headline)
                }
                ToolbarItem(placement: .bottomBar) {
                    if isConnected {
                        Button("Disconnect") {
                            wsClient.disconnect(route: "moveRobot")
                            isConnected = false
                        }
                        .foregroundStyle(.red)
                        .bold()
                    }
                }
            }
        }
    }
    
    var mainContent: some View {
        ZStack {
            Path { path in
                if !movementManager.pathPoints.isEmpty {
                    for (index, point) in movementManager.pathPoints.enumerated() {
                        let nextIndex = index + 1
                        if nextIndex < movementManager.pathPoints.count {
                            let nextPoint = movementManager.pathPoints[nextIndex]
                            path.move(to: point)
                            path.addLine(to: nextPoint)
                        }
                    }
                }
            }
            .stroke(Color.clear)
            .frame(width: 400, height: 400)
            .background(Color.white)
            .border(Color.gray)

            ForEach(movementManager.pathPoints.indices, id: \.self) { index in
                if index < movementManager.pathPoints.count - 1 {
                    let point = movementManager.pathPoints[index]
                    let nextPoint = movementManager.pathPoints[index + 1]
                    LineView(start: point, end: nextPoint, color: colors[index % colors.count])
                }
            }

            VStack {
                Spacer()
                Button(action: {
                    isMoving.toggle()
                    if isMoving {
                        startMovement()
                    } else {
                        stopMovement()
                    }
                }) {
                    Text(isMoving ? "Arrêter" : "Démarrer")
                        .padding()
                        .background(isMoving ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .onDisappear {
            stopMovement()
        }
    }

    private func startMovement() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            guard let direction = orientationManager.direction else { return }
            let command: String
            
            switch direction {
            case .left:
                command = "left"
            case .right:
                command = "right"
            case .forward:
                command = "forward"
//            case .bas:
//                command = "backward"
            }

            // Send command to the WebSocket server
            wsClient.sendMoveRobot(command: command)
            
            // Update the movement manager for local visualization
            switch direction {
            case .left:
                movementManager.turnLeft()
            case .right:
                movementManager.turnRight()
            case .forward:
                movementManager.moveForward()
//            case .bas:
//                movementManager.moveBackward()
            }
            
            let newPoint = movementManager.currentPosition
            movementManager.pathPoints.append(newPoint)
        }
    }

    private func stopMovement() {
        timer?.invalidate()
        timer = nil
        // Optionally, send a stop command or close the WebSocket connection
    }
}

struct LineView: View {
    var start: CGPoint
    var end: CGPoint
    var color: Color

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(color, lineWidth: 2)
    }
}
