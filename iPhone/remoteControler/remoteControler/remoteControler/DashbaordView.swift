//
//  DashbaordView.swift
//  remoteControler
//
//  Created by Valentin Gassant on 03/12/2024.
//

import SwiftUI
struct Device: Identifiable, Codable {
    var id: String { macAddress }
    var device: String
    var macAddress: String
    var isConnected: Bool
}

struct DashboardView: View {
    @ObservedObject var wsClient = WebSocketClient.instance
    @State private var connectedDevices: [Device] = []

    var body: some View {
        
        NavigationStack {
            VStack {
                Text("Connected Devices")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                    List(wsClient.connectedDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.device)
                                    .font(.headline)
                                Text("MAC: \(device.macAddress)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text(device.isConnected ? "Online" : "Offline")
                                .foregroundColor(
                                    device.isConnected ? .green : .red
                                )
                        }
                }

                Button(action: {
                    wsClient.sendToDashboardroute(route: .remoteControllerConnect, msg: "getDevices")
                }) {
                    Text("Refresh")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Dashboard")
        }.onAppear {
            wsClient.connectForIdentification(route: .remoteControllerConnect)
        }.onChange(of: wsClient.messageReceive) { newValue in
            // Ce bloc s'exécutera chaque fois que `messageReceive` change
            print("Message received: \(newValue)")
            print("wsClient.connectedDevices \(wsClient.connectedDevices)")
            // Si nécessaire, vous pouvez ajouter des actions supplémentaires ici.
        }
    }

    
}


