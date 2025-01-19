//
//  DeviceStatusView.swift
//  remoteControler
//
//  Created by Valentin Gassant on 19/01/2025.
//

import SwiftUI

struct DeviceStatusView: View {
    @ObservedObject var wsClient = WebSocketClient.instance
    let devicePrefix: String  // e.g. "volcano", "maze", etc.
    
    private var filteredDevices: [Device] {
        wsClient.connectedDevices
            .filter { device in
                device.device.lowercased().contains(devicePrefix.lowercased())
            }
            .sorted { device1, device2 in
                // D'abord trier par statut de connexion
                if device1.isConnected != device2.isConnected {
                    return device1.isConnected && !device2.isConnected
                }
                // Ensuite trier par ordre alphabétique
                return device1.device.lowercased() < device2.device.lowercased()
            }
    }
    
    private var otherDevices: [Device] {
        let excludedPrefixes = ["tornado", "maze", "typhoon", "volcano", "crystal"]
        return wsClient.connectedDevices
            .filter { device in
                !excludedPrefixes.contains { prefix in
                    device.device.lowercased().contains(prefix.lowercased())
                }
            }
            .sorted { device1, device2 in
                // D'abord trier par statut de connexion
                if device1.isConnected != device2.isConnected {
                    return device1.isConnected && !device2.isConnected
                }
                // Ensuite trier par ordre alphabétique
                return device1.device.lowercased() < device2.device.lowercased()
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Section des appareils filtrés
            VStack(alignment: .leading) {
                Text("\(devicePrefix.capitalized) Devices")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                ForEach(filteredDevices) { device in
                    HStack {
                        Text(device.device)
                            .font(.subheadline)
                        Spacer()
                        Circle()
                            .fill(device.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.vertical, 2)
                }
                
                if filteredDevices.isEmpty {
                    Text("No \(devicePrefix) devices found")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .italic()
                }
            }
            
            Divider()
            
            // Section de tous les autres appareils
            VStack(alignment: .leading) {
                Text("All Other Devices")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                ForEach(otherDevices) { device in
                    HStack {
                        Text(device.device)
                            .font(.subheadline)
                        Spacer()
                        Circle()
                            .fill(device.isConnected ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.vertical, 2)
                }
                
                if otherDevices.isEmpty {
                    Text("No other devices found")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .italic()
                }
            }
        }
        .padding()
    }
}
