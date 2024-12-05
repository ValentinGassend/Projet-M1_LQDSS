//
//  DashbaordView.swift
//  remoteControler
//
//  Created by Valentin Gassant on 03/12/2024.
//

import SwiftUI
struct Device: Identifiable, Codable {
    var id: String { device }
    var device: String
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
                        }
                        Spacer()
                        Text(device.isConnected ? "Online" : "Offline")
                            .foregroundColor(device.isConnected ? .green : .red)
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
        }
    }

    
}


