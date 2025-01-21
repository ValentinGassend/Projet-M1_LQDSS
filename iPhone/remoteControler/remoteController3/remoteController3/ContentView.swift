//
//  ContentView.swift
//  remoteController3
//
//  Created by Valentin Gassant on 20/01/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var wsClient = WebSocketClient.instance
    @StateObject private var roleManager = SpheroRoleManager.instance
    @StateObject private var rotationManager = SpheroRotationManager.instance  // Ajout comme StateObject
    @State private var showConnectSheet = false
    @State private var spheroStates: [String: SpheroBoltState] = [:]
    @State private var connectedSpheros: [String: BoltToy] = [:]
    @State private var refreshTrigger = false

    private var spheroIds: [String] {
        return getHandleAssignments()
            .compactMap { $0.spheroName }
    }
    private func updateConnectedSpheros() {
            connectedSpheros.removeAll()
            spheroStates.removeAll()
            
            // Mettre à jour avec tous les Bolts actuellement connectés
            for bolt in SharedToyBox.instance.bolts {
                if let name = bolt.peripheral?.name {
                    spheroStates[name] = SpheroBoltState()
                    connectedSpheros[name] = bolt
                }
            }
        }
    private func getHandleNumber(for spheroId: String) -> String? {
        for role in [SpheroRole.handle1, .handle2, .handle3, .handle4] {
            if let assignment = roleManager.getRoleAssignment(for: role),
               assignment.spheroName == spheroId {
                return role.rawValue.replacingOccurrences(of: "Handle ", with: "")
            }
        }
        return nil
    }
    
    private func getHandleAssignments() -> [SpheroRoleAssignment] {
        return [.handle1, .handle2, .handle3, .handle4].compactMap { role in
            roleManager.getRoleAssignment(for: role)
        }
    }
    
    private func configureBolts() {
        for bolt in SharedToyBox.instance.bolts {
            if let name = bolt.peripheral?.name, spheroIds.contains(name) {
                rotationManager.configureBolt(sphero: bolt, id: name)
                spheroStates[name] = SpheroBoltState()
                connectedSpheros[name] = bolt
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SpheroConnectionStatusView()
                    MazeSpheroControlView()
                    
                    Button(action: { showConnectSheet.toggle() }) {
                        Text("Connect Spheros")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button("Config") {
                        configureBolts()
                    }
                    
                    VStack(spacing: 16) {
                        ForEach(spheroIds, id: \.self) { spheroId in
                            VStack {
                                HStack {
                                    Text(spheroId)
                                    Text(connectedSpheros[spheroId] != nil ? "Connected" : "Not Connected")
                                        .foregroundColor(connectedSpheros[spheroId] != nil ? .green : .red)
                                }
                                
                                if connectedSpheros[spheroId] != nil {
                                    HStack {
                                        Button(rotationManager.isSpheroCaptureActive(spheroId) ? "Stop Capture" : "Start Capture") {
                                            if rotationManager.isSpheroCaptureActive(spheroId) {
                                                rotationManager.stopDataCapture(for: spheroId)
                                            } else {
                                                if let handleNumber = getHandleNumber(for: spheroId) {
                                                    rotationManager.startDataCapture(for: spheroId, handleNumber: handleNumber)
                                                }
                                            }
                                        }
                                        .padding()
                                        .background(rotationManager.isSpheroCaptureActive(spheroId) ? Color.red : Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                    }
                                    
                                    if let rotationInfo = rotationManager.getRotationData(for: spheroId) {
                                        VStack {
                                            Text("Total Rotations: \(String(format: "%.2f", rotationInfo.totalRotations))")
                                            Text("Current Speed: \(String(format: "%.2f", rotationInfo.currentRotationSpeed))")
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1))
                            .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showConnectSheet, onDismiss: {
            refreshTrigger.toggle()
        }) {
            SimpleSpheroConnectionView()
        }
        .onChange(of: refreshTrigger) { _ in
                    // Force la mise à jour des vues qui dépendent des Spheros connectées
                    updateConnectedSpheros()
                }
        .onAppear {
            wsClient.connectForIdentification(route: .remoteController_iphone3Connect)
        }
        .onDisappear {
            wsClient.disconnect(route: "remoteController_iphone3Connect")
        }
    }
}
