//
//  HandleView.swift
//  remoteControler
//
//  Created by Valentin Gassant on 17/01/2025.
//

import SwiftUI

struct HandleView: View {
    let handleRole: SpheroRole
    let spheroAssignment: SpheroRoleAssignment?
    @State private var rotationData: [String: SpheroRotationData] = [:]
    let onStartCapture: (BoltToy) -> Void
    let onStopCapture: (BoltToy) -> Void
    
    private var isCapturing: Bool {
        guard let spheroName = spheroAssignment?.spheroName else { return false }
        return rotationData[spheroName]?.isCapturing ?? false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(handleRole.rawValue)")
                .font(.headline)
            
            if let assignment = spheroAssignment {
                if let toy = assignment.toy {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connected: \(assignment.spheroName)")
                            .foregroundColor(.green)
                        
                        Button(action: {
                            if isCapturing {
                                onStopCapture(toy)
                            } else {
                                onStartCapture(toy)
                            }
                        }) {
                            Text(isCapturing ? "Stop Detection" : "Start Detection")
                                .padding()
                                .background(isCapturing ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        if let data = rotationData[assignment.spheroName] {
                            Text("Total Rotations: \(String(format: "%.2f", data.totalRotations))")
                            Text("Current Speed: \(String(format: "%.2f", data.currentRotationSpeed))")
                        }
                    }
                }
            } else {
                Text("No Sphero assigned")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

