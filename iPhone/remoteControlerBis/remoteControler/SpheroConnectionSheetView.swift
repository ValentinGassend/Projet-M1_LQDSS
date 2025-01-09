import SwiftUI

enum SpheroRole: String, CaseIterable {
    case maze = "maze"
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
    @Published var disconnectedSpheros: Set<String> = []
    private var isObserving = false
    
    func startObserving() {
        isObserving = true
        SharedToyBox.instance.box.addListener(self)
    }
    
    func stopObserving() {
        isObserving = false
        SharedToyBox.instance.box.removeListener(self)
    }
    
    func handleDisconnection(_ spheroName: String) {
        DispatchQueue.main.async {
            self.discoveredSpheros.remove(spheroName)
            self.disconnectedSpheros.insert(spheroName)
        }
    }
    
    func clearDisconnectedSpheros() {
        disconnectedSpheros.removeAll()
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
                self.disconnectedSpheros.remove(name)
            }
        }
    }
    
    func toyBox(_ toyBox: ToyBox, readied toy: Toy) {
        if let peripheral = toy.peripheral, let name = peripheral.name {
            DispatchQueue.main.async {
                self.disconnectedSpheros.remove(name)
            }
        }
    }
    
    func toyBox(_ toyBox: ToyBox, putAway toy: Toy) {
        if let peripheral = toy.peripheral, let name = peripheral.name {
            handleDisconnection(name)
        }
    }
}

class SpheroRoleManager: ObservableObject {
    @Published var roleAssignments: [SpheroRoleAssignment] = []
    private let wsClient: WebSocketClient
    static let instance = SpheroRoleManager(wsClient:WebSocketClient.instance)
    
    init(wsClient: WebSocketClient) {
        self.wsClient = wsClient
    }
    
    func autoAssignRoles() {
        let spheroNames = ["SB-808F", "SB-313C"]
        let roles: [SpheroRole] = [.handle1, .handle2, .handle3, .handle4]
        
        for (index, spheroName) in spheroNames.enumerated() {
            if index < roles.count {
                let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == spheroName })
                assignRole(to: spheroName, role: roles[index], toy: toy)
            }
        }
    }
    
    func handleDisconnection(_ spheroName: String) {
        if let index = roleAssignments.firstIndex(where: { $0.spheroName == spheroName }) {
            roleAssignments.remove(at: index)
        }
    }

    func assignRole(to spheroName: String, role: SpheroRole, toy: BoltToy?) {
        print("Assigning role \(role.rawValue) to \(spheroName)")
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
        sendRoleAssignmentMessage(spheroName: spheroName, role: role)
    }
    
    private func sendRoleAssignmentMessage(spheroName: String, role: SpheroRole) {
        let routeOrigin = "maze_iphone"
        let routeTarget = ["maze_iphone"]
        let component = "sphero"
        let data = "\(role.rawValue.lowercased())"
        wsClient.sendMessage(from: routeOrigin, to: routeTarget, component: component, data: data)
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
    @ObservedObject var wsClient: WebSocketClient
    @Binding var connectionStatus: String
    @Binding var connectedSpheroNames: [String]
    @Binding var spheroMazeInfo: [String: BoltToy]
    @ObservedObject var roleManager = SpheroRoleManager(wsClient: WebSocketClient.instance)
    
    @StateObject private var discoveryManager = SpheroDiscoveryManager()
    @State private var isSearching: Bool = false
    @State private var showingRoleSelection = false
    @State private var reconnectAttempts: [String: Int] = [:]
    private let maxReconnectAttempts = 3
    
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
            
            // Disconnected Spheros Warning
            if !discoveryManager.disconnectedSpheros.isEmpty {
                ForEach(Array(discoveryManager.disconnectedSpheros), id: \.self) { name in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("\(name) disconnected")
                        Button("Reconnect") {
                            attemptReconnect(name)
                        }
                        .disabled(reconnectAttempts[name] ?? 0 >= maxReconnectAttempts)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(8)
                }
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
                
                Button("Disconnect All") {
                    disconnectAllSphero()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Spacer()
            Button("Connect to Specific Spheros") {
                connectToSpecificSpheros()
            }
        }
        .padding()
        .onDisappear {
            cleanup()
        }
    }
    private func connectToSpecificSpheros() {
        let targetSpheros = ["SB-808F", "SB-313C"]
        connectionStatus = "Starting search for specific Spheros..."
        
        // Start discovery if not already searching
        if !isSearching {
            startSearch()
        }
        
        // Function to check discovered Spheros and connect
        func checkAndConnect() {
            let discoveredTargets = discoveryManager.discoveredSpheros.filter { targetSpheros.contains($0) }
            print("Discovered targets: \(discoveredTargets)")
            
            if discoveredTargets.count == targetSpheros.count {
                // Both Spheros found, connect to them
                SharedToyBox.instance.searchForBoltsNamed(Array(discoveredTargets)) { error in
                    DispatchQueue.main.async {
                        if error == nil {
                            isSpheroConnected = true
                            connectionStatus = "Connected to both Spheros"
                            
                            // Update connected Spheros list
                            connectedSpheroNames = SharedToyBox.instance.bolts
                                .compactMap { $0.peripheral?.name }
                                .filter { targetSpheros.contains($0) }
                            
                            // Assign roles and reset reconnect attempts
                            for name in connectedSpheroNames {
                                if !roleManager.roleAssignments.contains(where: { $0.spheroName == name }) {
                                    let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == name })
                                    roleManager.assignRole(to: name, role: .unassigned, toy: toy)
                                }
                                reconnectAttempts[name] = 0
                            }
                            
                            roleManager.autoAssignRoles()
                            stopSearch() // Stop searching once connected
                        } else {
                            // If connection fails, continue searching
                            connectionStatus = "Connection failed, continuing search..."
                            retrySearch()
                        }
                    }
                }
            } else {
                // Not all Spheros found yet, continue searching
                retrySearch()
            }
        }
        
        // Function to retry search
        func retrySearch() {
            connectionStatus = "Searching for Spheros: \(targetSpheros.joined(separator: ", "))..."
            
            // Wait 2 seconds before checking again
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if discoveryManager.discoveredSpheros.filter({ targetSpheros.contains($0) }).count < targetSpheros.count {
                    // Restart search if needed
                    SharedToyBox.instance.stopScan()
                    SharedToyBox.instance.searchForBoltsNamed([]) { error in }
                    checkAndConnect()
                }
            }
        }
        
        // Start the initial check
        checkAndConnect()
    }
    private func attemptReconnect(_ spheroName: String) {
        let currentAttempts = reconnectAttempts[spheroName] ?? 0
        if currentAttempts < maxReconnectAttempts {
            reconnectAttempts[spheroName] = currentAttempts + 1
            connectToSingleSphero(spheroName)
        }
    }
    
    private func handleSpheroDisconnection(_ spheroName: String) {
        DispatchQueue.main.async {
            connectedSpheroNames.removeAll { $0 == spheroName }
            spheroMazeInfo.removeValue(forKey: spheroName)
            roleManager.handleDisconnection(spheroName)
            
            if connectedSpheroNames.isEmpty {
                isSpheroConnected = false
            }
            
            connectionStatus = "\(spheroName) disconnected"
        }
    }
    
    private func connectToAllSphero() {
        connectionStatus = "Connecting to all discovered Spheros..."
        let discoveredNames = Array(discoveryManager.discoveredSpheros)
        
        if discoveredNames.isEmpty {
            connectionStatus = "No Spheros discovered. Please search first."
            return
        }
        
        SharedToyBox.instance.searchForBoltsNamed(discoveredNames) { error in
            DispatchQueue.main.async {
                if error == nil {
                    isSpheroConnected = true
                    connectionStatus = "Connected to all discovered Spheros"
                    connectedSpheroNames = SharedToyBox.instance.bolts.map { $0.peripheral?.name ?? "Unknown Sphero" }
                    
                    for name in connectedSpheroNames {
                        if !roleManager.roleAssignments.contains(where: { $0.spheroName == name }) {
                            let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == name })
                            roleManager.assignRole(to: name, role: .unassigned, toy: toy)
                        }
                        // Reset reconnect attempts on successful connection
                        reconnectAttempts[name] = 0
                    }
                    roleManager.autoAssignRoles()
                } else {
                    isSpheroConnected = false
                    connectionStatus = "Failed to connect to all Spheros"
                }
            }
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
    
    private func toggleSearch() {
        isSearching.toggle()
        if isSearching {
            startSearch()
        } else {
            stopSearch()
        }
    }
    
    private func startSearch() {
        isSearching = true
        connectionStatus = "Searching for Spheros..."
        discoveryManager.discoveredSpheros.removeAll()
        discoveryManager.clearDisconnectedSpheros()
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
                    reconnectAttempts[name] = 0  // Reset reconnect attempts on successful connection
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
        reconnectAttempts.removeAll()  // Reset all reconnect attempts
    }
}
