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
    @State private var selectedTheme: String? = nil
    @State private var selectedDeviceType: String? = nil
    @State private var timer: Timer? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Connected Devices")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding()
                
                // Filtering Controls
                HStack {
                    // Filter by Theme
                    Picker("Theme", selection: $selectedTheme) {
                        Text("All Themes").tag(String?.none)
                        ForEach(uniqueThemes(), id: \.self) { theme in
                            Text(theme.capitalized).tag(String?(theme))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                    
                    // Filter by Device Type
                    Picker("Device", selection: $selectedDeviceType) {
                        Text("All Devices").tag(String?.none)
                        ForEach(uniqueDeviceTypes(), id: \.self) { type in
                            Text(type.uppercased()).tag(String?(type))
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                }
                .padding()
                
                // Filtered and Grouped Devices
                let filteredDevices = applyFilters(to: wsClient.connectedDevices)
                let groupedDevices = Dictionary(grouping: filteredDevices) { $0.isConnected }
                
                List {
                    ForEach([true, false], id: \.self) { isConnected in
                        if let devices = groupedDevices[isConnected]?.sorted(by: { $0.device < $1.device }) {
                            Section(header: Text(isConnected ? "Online" : "Offline")
                                .font(.headline)
                                .foregroundColor(isConnected ? .green : .red)) {
                                    ForEach(devices) { device in
                                        HStack {
                                            Text(device.device)
                                                .font(.headline)
                                            Spacer()
                                            Text(isConnected ? "Online" : "Offline")
                                                .foregroundColor(isConnected ? .green : .red)
                                        }
                                    }
                                }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                
                Button(action: refreshDevices) {
                    Text("Refresh")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Dashboard")
        }
        .onAppear {
            setupConnections()
            startAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
            disconnectAll()
        }
    }
    
    // MARK: - Auto Refresh
    
    private func startAutoRefresh() {
        // Cancel any existing timer
        timer?.invalidate()
        
        // Create new timer that fires every 6 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            refreshDevices()
        }
    }
    
    private func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refreshDevices() {
        wsClient.sendToDashboardroute(route: .remoteController_iphone1Connect, msg: "getDevices")
    }
    
    // MARK: - Connection Management
    
    private func setupConnections() {
//        wsClient.connectForIdentification(route: .remoteController_iphone1Connect)
//        wsClient.connectForIdentification(route: .mazeIphoneConnect)
//        wsClient.connectForIdentification(route: .typhoonIphoneConnect)
    }
    
    private func disconnectAll() {
//        wsClient.disconnect(route: "remoteController_iphone1Connect")
    }
    
    // MARK: - Filtering Logic
    
    /// Apply filters to the devices list
    private func applyFilters(to devices: [Device]) -> [Device] {
        devices.filter { device in
            let matchesTheme = selectedTheme == nil || device.device.lowercased().contains(selectedTheme!.lowercased())
            let matchesDeviceType = selectedDeviceType == nil || device.device.lowercased().contains(selectedDeviceType!.lowercased())
            return matchesTheme && matchesDeviceType
        }
    }
    
    /// Extract unique themes from devices
    private func uniqueThemes() -> [String] {
        Set(wsClient.connectedDevices.map { $0.device.components(separatedBy: "_").first ?? "" }).sorted()
    }
    
    /// Extract unique device types from devices
    private func uniqueDeviceTypes() -> [String] {
        Set(wsClient.connectedDevices.map { $0.device.components(separatedBy: "_").last ?? "" }).sorted()
    }
}
