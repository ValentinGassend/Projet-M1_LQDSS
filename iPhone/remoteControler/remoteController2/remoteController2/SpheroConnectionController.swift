import SwiftUI
import Combine

class SpheroConnectionController: ObservableObject {
    static let shared = SpheroConnectionController()
    
    @Published var connectedSpheroNames: [String] = []
    @Published var connectionStatus: String = ""
    @Published var isConnecting: Bool = false
    @Published var disconnectedSphero: String? = nil
    
    private var searchTask: Task<Void, Never>? = nil
    private var timeoutTask: Task<Void, Never>? = nil
    private var retryCount: Int = 0
    private let maxRetries = 3
    
    private init() {}
    
    func connectToSpheros(_ spheros: [String]) {
        startConnectionAttempt(spheros: spheros)
    }
    
    func reconnectSphero(_ spheroName: String) {
        startConnectionAttempt(spheros: [spheroName])
    }
    
    func disconnectSphero(_ spheroName: String) {
        let box = ToyBox()
        
        if let toy = SharedToyBox.instance.bolts.first(where: { $0.peripheral?.name == spheroName }) {
            box.disconnect(toy: toy)
            box.putAway(toy: toy)
            DispatchQueue.main.async {
                self.connectedSpheroNames.removeAll { $0 == spheroName }
                self.disconnectedSphero = spheroName
                self.connectionStatus = "\(spheroName) déconnecté"
            }
        }
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
                        
                        self.connectedSpheroNames = Array(Set(self.connectedSpheroNames + currentConnected))
                        
                        if currentConnected.count == targetSpheros.count {
                            self.timeoutTask?.cancel()
                            self.timeoutTask = nil
                            self.connectionStatus = targetSpheros.count == 1
                            ? "\(targetSpheros[0]) reconnecté"
                            : "Connecté"
                            self.isConnecting = false
                            self.searchTask = nil
                            self.retryCount = 0
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
    
    func cancelConnection() {
        stopCurrentSearch()
        isConnecting = false
        retryCount = 0
        connectionStatus = "Connexion annulée"
    }
}
