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
    var macAddress: String
    var isConnected: Bool

    // Custom decoding to handle missing "isConnected" field
    enum CodingKeys: String, CodingKey {
        case device
        case macAddress
        case isConnected
    }

    init(device: String, macAddress: String, isConnected: Bool?) {
        self.device = device
        self.macAddress = macAddress
        self.isConnected = isConnected ?? false 
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.device = try container.decode(String.self, forKey: .device)
        self.macAddress = try container.decode(String.self, forKey: .macAddress)
        
        // Handle missing "isConnected"
        self.isConnected = try container.decodeIfPresent(Bool.self, forKey: .isConnected) ?? false
    }
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


