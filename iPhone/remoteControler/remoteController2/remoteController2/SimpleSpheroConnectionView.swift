//    private let targetSpheros = ["SB-92B2", "SB-0994"]
import SwiftUI

struct SimpleSpheroConnectionView: View {
    @ObservedObject private var connectionManager = SpheroConnectionController.shared
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var roleManager = SpheroRoleManager.instance

    @State private var connectedSpheroNames: [String] = []
    @State private var connectionStatus: String = ""
    @State private var disconnectedSphero: String? = nil
    @State private var isConnecting: Bool = false
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var timeoutTask: Task<Void, Never>? = nil
    @State private var retryCount: Int = 0
    private let targetSpheros = ["SB-808F","SB-313C","SB-F682"]
    private let maxRetries = 3
    
    private func connectToSpecificSpheros() {
            connectionManager.connectToSpheros(targetSpheros)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    // Assign roles based on the order in targetSpheros array
                    if let firstToy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == targetSpheros[0] }) {
                        roleManager.assignRole(to: targetSpheros[0], role: .handle3, toy: firstToy)
                    }
                    if let secondToy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == targetSpheros[1] }) {
                        roleManager.assignRole(to: targetSpheros[1], role: .handle4, toy: secondToy)
                    }
                    if let thirdToy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == targetSpheros[2] }) {
                        roleManager.assignRole(to: targetSpheros[2], role: .maze, toy: thirdToy)
                    }
                }
        }
    
    private func reconnectSphero(_ spheroName: String) {
        startConnectionAttempt(spheros: [spheroName])
    }
    private func startConnectionAttempt(spheros: [String]) {
        stopCurrentSearch()
        
        connectionStatus = spheros.count == 1
        ? "Reconnexion de \(spheros[0])..."
        : "Connexion en cours..."
        disconnectedSphero = nil
        isConnecting = true
        
        searchTask = Task {
            await withTimeout(targetSpheros: spheros)
        }
    }
    
    private func stopCurrentSearch() {
        timeoutTask?.cancel()
        timeoutTask = nil
        searchTask?.cancel()
        searchTask = nil
        Task {
            SharedToyBox.instance.searchForBoltsNamed([]) { _ in }
            SharedToyBox.instance.disconnectAllToys()
        }
    }
    
    private func withTimeout(targetSpheros: [String]) async {
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            if !Task.isCancelled {
                await checkAndRetry(targetSpheros: targetSpheros)
            }
        }
        
        SharedToyBox.instance.searchForBoltsNamed([]) { _ in }
        SharedToyBox.instance.disconnectAllToys()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        if !Task.isCancelled {
            SharedToyBox.instance.searchForBoltsNamed(targetSpheros) { error in
                DispatchQueue.main.async {
                    if !Task.isCancelled {
                        let currentConnected = SharedToyBox.instance.bolts
                            .compactMap { $0.peripheral?.name }
                            .filter { targetSpheros.contains($0) }
                        
                        // Mettre à jour la liste des connexions en préservant les connexions existantes
                        connectedSpheroNames = Array(Set(connectedSpheroNames + currentConnected))
                        
                        if currentConnected.count == targetSpheros.count {
                            timeoutTask?.cancel()
                            timeoutTask = nil
                            connectionStatus = targetSpheros.count == 1
                            ? "\(targetSpheros[0]) reconnecté"
                            : "Connecté"
                            isConnecting = false
                            searchTask = nil
                            retryCount = 0
                        }
                    }
                }
            }
        }
    }
    
    private func checkAndRetry(targetSpheros: [String]) async {
        await MainActor.run {
            let currentConnected = connectedSpheroNames.filter { targetSpheros.contains($0) }
            if isConnecting && currentConnected.count < targetSpheros.count {
                if retryCount < maxRetries {
                    retryCount += 1
                    connectionStatus = targetSpheros.count == 1
                    ? "Nouvelle tentative de reconnexion (\(retryCount)/\(maxRetries))..."
                    : "Relance de la détection (\(retryCount)/\(maxRetries))..."
                    startConnectionAttempt(spheros: targetSpheros)
                } else {
                    stopCurrentSearch()
                    connectionStatus = targetSpheros.count == 1
                    ? "Échec de la reconnexion de \(targetSpheros[0])"
                    : "Échec de la connexion après \(maxRetries) tentatives"
                    isConnecting = false
                    retryCount = 0
                }
            }
        }
    }
    
    private func cancelConnection() {
        stopCurrentSearch()
        isConnecting = false
        retryCount = 0
        connectionStatus = "Connexion annulée"
    }
    
    private func disconnectSphero(_ spheroName: String) {
        let box = ToyBox()
        
        if let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == spheroName }) {
            box.disconnect(toy: toy)
            box.putAway(toy: toy)
            DispatchQueue.main.async {
                connectedSpheroNames.removeAll { $0 == spheroName }
                disconnectedSphero = spheroName
                connectionStatus = "\(spheroName) déconnecté"
            }
        }
    }
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Spheros ciblés:")
                    .font(.headline)
                
                ForEach(targetSpheros, id: \.self) { targetSphero in
                    HStack {
                        Text(targetSphero)
                        Spacer()
                        // Show assigned role if connected
                        if connectionManager.connectedSpheroNames.contains(targetSphero) {
                            Text(roleManager.getRole(for: targetSphero).rawValue)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
            }
            
            if connectionManager.isConnecting {
                VStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Button(action: { connectionManager.cancelConnection() }) {
                        Text("Annuler la connexion")
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            } else {
                Button(action: connectToSpecificSpheros) {
                    Text("Se connecter aux Spheros")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            SpheroConnectionStatusView()
        }
        .padding()
    }
}
