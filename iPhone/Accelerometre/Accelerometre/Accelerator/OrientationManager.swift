//
//  OrientationManager.swift
//  Accelerometre
//
//  Created by digital on 24/10/2024.
//

import SwiftUI
import CoreMotion
import Combine

import Foundation

struct AccelerometerData: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var z: Double
    var timestamp: Date
    
    func toString() -> String {
        return "x:\(x) y:\(y) z:\(z)"
    }
}

class OrientationManager: ObservableObject {
    private var motionManager = CMMotionManager()
    
    @Published var accelerometerData: [AccelerometerData] = []
    @Published var direction: Direction?
    
    enum Direction {
        case left, right, forward
    }
    
    init() {
        startAccelerometerUpdates()
    }
    
    func startAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                if let data = data {
                    let newData = AccelerometerData(x: data.acceleration.x,
                                                     y: data.acceleration.y,
                                                     z: data.acceleration.z,
                                                     timestamp: Date())
                    self?.accelerometerData.append(newData)
                    
                    self?.updateDirection(with: newData)
                }
                
                if let error = error {
                    print("Erreur : \(error.localizedDescription)")
                }
            }
        } else {
            print("Accéléromètre non disponible.")
        }
    }
    
    private func updateDirection(with data: AccelerometerData) {
        if data.x < -0.2 {
            direction = .left
        } else if data.x > 0.2 {
            direction = .right
        } else if data.y > 0.2 || data.y < -0.2 {
            direction = .forward
//        } else if data.y < -0.2 {
//            direction = .bas
        } else {
            direction = nil
        }
    }
    
    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}
