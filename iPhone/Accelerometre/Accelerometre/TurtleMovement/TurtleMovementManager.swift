//
//  TurtleMovementManager.swift
//  Accelerometre
//
//  Created by Al on 24/10/2024.
//

import SwiftUI

class TurtleMovementManager: ObservableObject {
    @Published var currentPosition: CGPoint = CGPoint(x: 200, y: 200)
    @Published var pathPoints: [CGPoint] = []
    private var direction: Double = 0.0

    func turnLeft() {
        direction -= .pi / 8
        moveForward()
    }

    func turnRight() {
        direction += .pi / 8
        moveForward()
    }

    func moveForward() {
        let step: CGFloat = 40.0
        let newX = currentPosition.x + step * CGFloat(cos(direction))
        let newY = currentPosition.y + step * CGFloat(sin(direction))
        let newPoint = CGPoint(x: newX, y: newY)

        pathPoints.append(newPoint)
        currentPosition = newPoint
    }
    
//    func moveBackward() {
//        let step: CGFloat = 10.0
//        let newX = currentPosition.x - step * CGFloat(cos(direction))
//        let newY = currentPosition.y - step * CGFloat(sin(direction))
//        let newPoint = CGPoint(x: newX, y: newY)
//
//        pathPoints.append(newPoint)
//        currentPosition = newPoint
//    }
}
