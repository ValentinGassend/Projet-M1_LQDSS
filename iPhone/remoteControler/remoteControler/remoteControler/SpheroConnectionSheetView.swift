import SwiftUI

enum SpheroRole: String, CaseIterable {
    case maze = "Maze"
    case handle1 = "Handle 1"
    case handle2 = "Handle 2"
    case handle3 = "Handle 3"
    case handle4 = "Handle 4"
    case unassigned = "Unassigned"
}

struct SpheroRoleAssignment {
    var spheroName: String
    var role: SpheroRole
    var toy: BoltToy?
}

class SpheroDiscoveryManager: ObservableObject {
    @Published var discoveredSpheros: Set<String> = []
    private var isObserving = false
    
    func startObserving() {
        isObserving = true
        SharedToyBox.instance.box.addListener(self)
    }
    
    func stopObserving() {
        isObserving = false
        SharedToyBox.instance.box.removeListener(self)
    }
}

extension SpheroDiscoveryManager: ToyBoxListener {
    func toyBoxReady(_ toyBox: ToyBox) {
        // Implementation required by protocol
    }
    
    func toyBox(_ toyBox: ToyBox, discovered descriptor: ToyDescriptor) {
        if let name = descriptor.name {
            DispatchQueue.main.async {
                self.discoveredSpheros.insert(name)
            }
        }
    }
    
    func toyBox(_ toyBox: ToyBox, readied toy: Toy) {
        // Implementation required by protocol
    }
    
    func toyBox(_ toyBox: ToyBox, putAway toy: Toy) {
        // Implementation required by protocol
    }
}

class SpheroRoleManager: ObservableObject {
    @Published var roleAssignments: [SpheroRoleAssignment] = []
    
    func assignRole(to spheroName: String, role: SpheroRole, toy: BoltToy?) {
        if let index = roleAssignments.firstIndex(where: { $0.spheroName == spheroName }) {
            if role != .unassigned {
                if let existingIndex = roleAssignments.firstIndex(where: { $0.role == role }) {
                    roleAssignments[existingIndex].role = .unassigned
                }
            }
            roleAssignments[index].role = role
        } else {
            roleAssignments.append(SpheroRoleAssignment(spheroName: spheroName, role: role, toy: toy))
        }
    }
    
    func getRole(for spheroName: String) -> SpheroRole {
        return roleAssignments.first(where: { $0.spheroName == spheroName })?.role ?? .unassigned
    }
    
    func getRoleAssignment(for role: SpheroRole) -> SpheroRoleAssignment? {
        return roleAssignments.first(where: { $0.role == role })
    }
}

struct SpheroConnectionSheetView: View {
    @Binding var isSpheroConnected: Bool
    @Binding var connectionStatus: String
    @Binding var connectedSpheroNames: [String]
    @Binding var spheroMazeInfo: [String: BoltToy]
    @ObservedObject var roleManager: SpheroRoleManager // Changé de @StateObject à @ObservedObject
        
    @StateObject private var discoveryManager = SpheroDiscoveryManager()
    @State private var isSearching: Bool = false
    @State private var showingRoleSelection = false
    
    var body: some View {
        VStack {
            Text("Connect to Sphero")
                .font(.title)
                .padding()
            
            if !connectionStatus.isEmpty {
                Text(connectionStatus)
                    .font(.headline)
                    .foregroundColor(isSpheroConnected ? .green : .red)
                    .padding()
            }
            
            Button(action: {
                toggleSearch()
            }) {
                HStack {
                    Image(systemName: isSearching ? "stop.circle.fill" : "magnifyingglass.circle.fill")
                    Text(isSearching ? "Stop Searching" : "Search for Spheros")
                }
                .padding()
                .background(isSearching ? Color.orange : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            if !discoveryManager.discoveredSpheros.isEmpty {
                discoveredSpherosView
            }
            
            if !connectedSpheroNames.isEmpty {
                connectedSpherosView
                
                roleAssignmentView
                
                Button("Disconnect All") {
                    disconnectAllSphero()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding()
        .onDisappear {
            cleanup()
        }
    }
    
    private var discoveredSpherosView: some View {
        VStack {
            Text("Discovered Spheros:")
                .font(.headline)
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(discoveryManager.discoveredSpheros).sorted(), id: \.self) { name in
                        Button(action: {
                            connectToSingleSphero(name)
                        }) {
                            Text(name)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(connectedSpheroNames.contains(name) ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        }
    }
    
    private var connectedSpherosView: some View {
        VStack {
            Text("Connected Spheros:")
                .font(.headline)
                .padding(.top)
            
            ForEach(connectedSpheroNames, id: \.self) { name in
                HStack {
                    Text(name)
                    Spacer()
                    Picker("Role", selection: Binding(
                        get: { roleManager.getRole(for: name) },
                        set: { newRole in
                            let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == name })
                            roleManager.assignRole(to: name, role: newRole, toy: toy)
                            
                            if newRole == .maze {
                                spheroMazeInfo.removeAll()
                                if let mazeToy = toy {
                                    spheroMazeInfo[name] = mazeToy
                                }
                            }
                        }
                    )) {
                        ForEach(SpheroRole.allCases, id: \.self) { role in
                            Text(role.rawValue).tag(role)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                .padding()
                .background(Color.green.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
    
    private var roleAssignmentView: some View {
        VStack {
            Text("Role Assignments:")
                .font(.headline)
                .padding(.top)
            
            ForEach(SpheroRole.allCases.filter { $0 != .unassigned }, id: \.self) { role in
                if let assignment = roleManager.getRoleAssignment(for: role) {
                    HStack {
                        Text(role.rawValue)
                        Spacer()
                        Text(assignment.spheroName)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func toggleSearch() {
        isSearching.toggle()
        if isSearching {
            startSearch()
        } else {
            stopSearch()
        }
    }
    
    private func startSearch() {
        connectionStatus = "Searching for Spheros..."
        discoveryManager.discoveredSpheros.removeAll()
        discoveryManager.startObserving()
        SharedToyBox.instance.searchForBoltsNamed([]) { error in }
    }
    
    private func stopSearch() {
        discoveryManager.stopObserving()
        SharedToyBox.instance.stopScan()
        connectionStatus = "Search stopped"
    }
    
    private func cleanup() {
        stopSearch()
    }
    
    private func connectToSingleSphero(_ name: String) {
        connectionStatus = "Connecting to \(name)..."
        SharedToyBox.instance.searchForBoltsNamed([name]) { error in
            DispatchQueue.main.async {
                if error == nil {
                    if !connectedSpheroNames.contains(name) {
                        connectedSpheroNames.append(name)
                        let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == name })
                        roleManager.assignRole(to: name, role: .unassigned, toy: toy)
                    }
                    isSpheroConnected = true
                    connectionStatus = "Connected to \(name)"
                } else {
                    connectionStatus = "Failed to connect to \(name)"
                }
            }
        }
    }
    
    private func disconnectAllSphero() {
        connectionStatus = "Disconnecting all Spheros..."
        SharedToyBox.instance.disconnectAllToys()
        isSpheroConnected = false
        connectionStatus = "All Spheros disconnected"
        connectedSpheroNames.removeAll()
        spheroMazeInfo.removeAll()
        roleManager.roleAssignments.removeAll()
    }
}
