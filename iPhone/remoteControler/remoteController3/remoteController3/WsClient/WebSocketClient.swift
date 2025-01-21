//
//  WebSocketClient.swift
//  WebSocketClient
//
//  Created by digital on 22/10/2024.
//

import SwiftUI
import Network
import NWWebSocket

protocol WebSocketMessageHandler: AnyObject {
    func handleMessage(_ message: String)
}

class WebSocketClient:ObservableObject {
    static let instance = WebSocketClient()
    private var webSocketTask: URLSessionWebSocketTask?
    private var messageHandlers: [String: WebSocketMessageHandler] = [:]
    
    var routes = [String:NWWebSocket]()
    var ipAddress = "192.168.10.146:8080/"
//    @StateObject var roleManager:SpheroRoleManager = SpheroRoleManager.instance
    @Published var messageReceive:String = ""
    @Published var isRFIDDetectedForMaze:Bool = false
    @Published var isRFIDDetectedForTyphoon:Bool = false
    @Published var connectedDevices: [Device] = []
    
    func connectForIdentification(route: IdentificationRoute) {
        // Construire l'URL pour la route d'identification
        if let socketURL = URL(string: "ws://\(ipAddress)\(route.rawValue)Connect") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[route.rawValue] = socket
            
            // Envoyer le message de bienvenue pour la route
            sendWelcomeMessage(for: route)
            createMessageRoute(for: route)
            createPingRoute(for: route)
            
            
        }
    }
    
    private func createDashboardRoute(for route: IdentificationRoute) {
        // Supprimer le "Connect" du rawValue pour le dashboard
        let baseRoute = route.rawValue.replacingOccurrences(of: "Connect", with: "")
        let dashboardRouteKey = "\(baseRoute)Dashboard"
        
        if let socketURL = URL(string: "ws://\(ipAddress)\(dashboardRouteKey)") {
            print("Creating dashboard connection for \(dashboardRouteKey)")
            
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            
            // Stocker la socket dans les routes
            routes[dashboardRouteKey] = socket
            
            // Connecter la socket
            socket.connect()
            
            // Attendre un court instant pour s'assurer que la connexion est établie
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                print("Sending getDevices to dashboard")
                socket.send(string: "getDevices")
            }
        }
    }
    func sendToDashboardroute(route: IdentificationRoute, msg: String, completion: ((String?) -> Void)? = nil) {
        let baseRoute = route.rawValue.replacingOccurrences(of: "Connect", with: "")
        let dashboardRouteKey = "\(baseRoute)Dashboard"
        
        guard let url = URL(string: "ws://\(ipAddress)\(dashboardRouteKey)") else { return }
        
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        if let socket = routes[dashboardRouteKey] {
            socket.send(string: msg)
            print("Sent: \(msg) to \(dashboardRouteKey)")
        } else {
            print("Error: Message route \(dashboardRouteKey) not found!")
        }
    }
    
    private func updateConnectedDevices(from message: String) {
        if let jsonData = message.data(using: .utf8) {
            do {
                let newDevices = try JSONDecoder().decode([Device].self, from: jsonData)
                DispatchQueue.main.async {
                    // Fusionner les nouveaux appareils avec les existants
                    for newDevice in newDevices {
                        if let index = self.connectedDevices.firstIndex(where: { $0.device == newDevice.device }) {
                            self.connectedDevices[index] = newDevice
                        } else {
                            self.connectedDevices.append(newDevice)
                        }
                    }
                    print("Updated connected devices: \(self.connectedDevices)")
                }
            } catch {
                print("Erreur lors du décodage JSON : \(error)")
            }
        } else {
            print("Erreur: Le message reçu n'est pas un format JSON valide")
        }
    }
    
    private func createMessageRoute(for route: IdentificationRoute) {
        // Supprimer le "Connect" du rawValue pour la route message
        let baseRoute = route.rawValue.replacingOccurrences(of: "Connect", with: "")
        let messageRouteKey = "\(baseRoute)Message"
        
        if let socketURL = URL(string: "ws://\(ipAddress)\(messageRouteKey)") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[messageRouteKey] = socket
            
            print("Message route created for \(messageRouteKey)")
        }
    }

    private func createPingRoute(for route: IdentificationRoute) {
        // Supprimer le "Connect" du rawValue pour la route ping
        let baseRoute = route.rawValue.replacingOccurrences(of: "Connect", with: "")
        let pingRouteKey = "\(baseRoute)Ping"
        
        if let socketURL = URL(string: "ws://\(ipAddress)\(pingRouteKey)") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[pingRouteKey] = socket
            
            print("Ping route created for \(pingRouteKey)")
        }
    }

    func sentToRoute(route: IdentificationRoute, msg: String) {
        // Supprimer le "Connect" du rawValue pour la route message
        let baseRoute = route.rawValue.replacingOccurrences(of: "Connect", with: "")
        let messageRouteKey = "\(baseRoute)Message"
        
        if let socket = routes[messageRouteKey] {
            socket.send(string: msg)
            print("Sent: \(msg) to \(messageRouteKey)")
        } else {
            print("Error: Message route \(messageRouteKey) not found!")
        }
    }

    func sentToMessageRoute(route: IdentificationRoute, msg: String) {
        // Supprimer le "Connect" du rawValue pour la route message
        let baseRoute = route.rawValue.replacingOccurrences(of: "Connect", with: "")
        let messageRouteKey = "\(baseRoute)Message"
        
        if let socket = routes[messageRouteKey] {
            socket.send(string: msg)
            print("Sended: \(msg) to \(messageRouteKey)")
        }
    }
    func connect(route: String) {
        // Construire l'URL pour la route
        if let socketURL = URL(string: "ws://\(ipAddress)\(route)") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[route] = socket
            
        }
    }
    
    func disconnect(route:String){
        routes[route]?.disconnect()
    }
    
    
    func sendSpheroTyphoonName(msg:String) {
        self.connect(route: "spheroTyphoon")
        routes["spheroTyphoon"]?.send(string: msg)
    }
    
    func sendWelcomeMessage(for route: IdentificationRoute) {
        // Envoie le message de bienvenue pour cette route
        if let socket = routes[route.rawValue] {
            let message = route.welcomeMessage
            socket.send(string: message)
            print("Message sent: \(message) to \(route.rawValue)")
        }
    }
}

extension WebSocketClient: WebSocketConnectionDelegate {
    func parseMessage(_ message: String) -> ParsedMessage? {
        let components = message.components(separatedBy: "#")
        guard components.count == 2 else {
            print("Invalid message format: \(message)")
            return nil
        }
        
        return ParsedMessage(
            component: components[0],
            data: components[1]
        )
    }
    
    func parseSendedMessage(_ message: String) -> ParsedSendedMessage? {
        let components = message.components(separatedBy: "=>")
        
        // Cas où le message est bien au format "origin=>targets=>component#data"
        if components.count == 3 {
            let routeOrigin = components[0].trimmingCharacters(in: .whitespaces)
            
            let routeTargetsRaw = components[1]
                .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            
            let componentData = components[2].components(separatedBy: "#")
            guard componentData.count == 2 else {
                print("Invalid component format in message: \(message)")
                return nil
            }
            
            return ParsedSendedMessage(
                routeOrigin: routeOrigin,
                routeTargets: routeTargetsRaw,
                component: componentData[0],
                data: componentData[1]
            )
        }
        
        
        print("Invalid message format: \(message)")
        return nil
    }

        
        func sendMessage(
            from origin: String,
            to targets: [String],
            component: String,
            data: String
        ) {
            // Formater les cibles comme une liste séparée par des virgules
            let targetString = targets.joined(separator: ",")
            let formattedMessage = "\(origin)=>[\(targetString)]=>\(component)#\(data)"
            let originMessage = origin+"Message"
            
            self.sentToMessageRoute(route: IdentificationRoute.remoteController_iphone3Connect, msg: formattedMessage)
              
        }
        func processReceivedMessage(connection: NWWebSocket, string: String) {
            //            print("Receive String Message \(string) on \(connection)")
            DispatchQueue.main.async {
                self.messageReceive = string
                
                if let route = self.routes.first(where: { $0.value === connection })?.key {
                    if route.hasSuffix("Dashboard") {
                        print("Message received on dashboard route: \(string)")
                        self.updateDevicesFromJson(string)
                    }
                    // Handle specific route behaviors
                    else if route.hasSuffix("Ping") {
                        if string == "ping" {
                            self.respondToPing(for: route)
                        }
                    } else if route.hasSuffix("Connect") {
                        connection.send(string: "hello")
                        print("Responded with 'hello' on \(route)")
                    } else if route.hasSuffix("Message") {
                        print("Message received on route Message: \(route)")
                        self.routeMessage(string, for: route)
                    } else {
                        print("Message received : \(string), on route: \(route)")
                        print("Unhandled route type for \(route)")
                    }
                }
            }
        }
        
        
    private func respondToPing(for route: String) {
        // Supprimer le suffixe "Ping" et "Connect" pour obtenir la route de base
        let baseRoute = route
            .replacingOccurrences(of: "Ping", with: "")
            .replacingOccurrences(of: "Connect", with: "")
        
        if let pingSocket = routes[route] {
            pingSocket.send(string: "pong")
        } else {
            print("Error: Ping route \(route) not found for ping response")
        }
    }
        func webSocketDidReceiveMessage(
            connection: WebSocketConnection,
            string: String
        ) {
            //                print("Receive String Message \(string)")
            DispatchQueue.main.async {
                self.messageReceive = string
                
                if let connection = connection as? NWWebSocket {
                    self.processReceivedMessage(connection: connection, string: string)
                }
                
            }
            
            
            
        }
    private func handleMazeRFID() {
        // Liste des rôles pour lesquels appliquer la configuration
        let roles: [SpheroRole] = [.maze]
        let roleManager = SpheroRoleManager.instance
        for role in roles {
            // Récupérer la Sphero assignée au rôle
            if let roleAssignment = roleManager.getRoleAssignment(for: role),
               let sphero = roleAssignment.toy {
                sphero.setFrontLed(color: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.0))
                sphero.setBackLed(color: UIColor(red: 0/255, green: 0/255, blue: 0/255, alpha: 0.0))
                SpheroPresetManager.shared.sendLightningPreset(
                    to: sphero,
                    defaultColor: .black,
                    presetColor: UIColor(red: 48/255, green: 48/255, blue: 30/255, alpha: 1.0)
                )
            }
        }
    }
    private func handleBtn1Start() {
        // Liste des rôles pour lesquels appliquer la configuration
        let roles: [SpheroRole] = [.maze]
        let roleManager = SpheroRoleManager.instance
        for role in roles {
            // Récupérer la Sphero assignée au rôle
            if let roleAssignment = roleManager.getRoleAssignment(for: role),
               let sphero = roleAssignment.toy {
                // Configurer les LEDs en jaune
                sphero.setFrontLed(color: UIColor(red: 110/255, green: 60/255, blue: 0/255, alpha: 1.0))
                                sphero.setBackLed(color: UIColor(red: 110/255, green: 60/255, blue: 0/255, alpha: 1.0))
                                
                // Envoyer le motif d'éclair (commenté pour l'instant)
                SpheroPresetManager.shared.sendLightningPreset(
                                    to: sphero,
                                    defaultColor: .black,
                                    presetColor: UIColor(red: 110/255, green: 110/255, blue: 0/255, alpha: 1.0)
                                )            }
        }
    }
    private func handleTyphoonRFID() {
        // Liste des rôles pour lesquels appliquer la configuration
        let roles: [SpheroRole] = [.handle3, .handle4]
        let roleManager = SpheroRoleManager.instance
        for role in roles {
            // Récupérer la Sphero assignée au rôle
            if let roleAssignment = roleManager.getRoleAssignment(for: role),
               let sphero = roleAssignment.toy {
                // Configurer les LEDs en jaune
                sphero.setFrontLed(color: UIColor(red: 0/255, green: 0/255, blue: 255/255, alpha: 1.0))
                                sphero.setBackLed(color: UIColor(red: 0/255, green: 0/255, blue: 255/255, alpha: 1.0))
                                
            }
        }
    }
    
        private func routeMessage(_ message: String, for route: String) {
            print("Route Message \(message) on route \(route)")
            
            
            
            
            // Traitement basé sur le composant
            switch message {
            case "rfid#typhoon":
                handleTyphoonRFID()
            case "rfid#maze":
                handleMazeRFID()
            case "btn1#start":
                handleBtn1Start()
            default:
                print("Unknown component: \(message)")
            }
        }
    

        // Exemple de traitement pour RFID
    
        func updateDevicesFromJson(_ jsonString: String) {
            guard let jsonData = jsonString.data(using: .utf8) else {
                print("Error: Cannot convert string to data")
                return
            }
            
            do {
                // Décoder le JSON en dictionnaire [String: DeviceResponse]
                let decoder = JSONDecoder()
                let deviceDict = try decoder.decode([String: DeviceResponse].self, from: jsonData)
                
                DispatchQueue.main.async {
                    // Convertir le dictionnaire en array de Device
                    self.connectedDevices = deviceDict.map { (key, value) in
                        Device(
                            device: key,
                            isConnected: value.isConnected
                        )
                    }
                }
            } catch {
                print("Error decoding JSON: \(error)")
            }
        }
        
        // Exemple de traitement pour Relay
        private func handleSpheroMessage(_ message: ParsedMessage) {
            print("Sphero message for \(message.component): \(message.data)")
        }
        // Exemple de traitement pour Relay
        private func handleSpheroConnectionMessage(_ message: ParsedMessage) {
            print("Sphero message for \(message.component): \(message.data)")
            switch message.data {
            case "maze":
                    print("maze sphero connection received")
                    // Add a delay to allow for role assignment to be properly registered
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard self != nil else { return }
                        let roleManager = SpheroRoleManager.instance
                        
                        // First, ensure there's a Sphero assigned to the maze role
                        if let mazeAssignment = roleManager.getRoleAssignment(for: .maze) {
                            print("Found maze assignment: \(mazeAssignment.spheroName)")
                            if let mazeSphero = mazeAssignment.toy {
                                // Enable stabilization
                                mazeSphero.setStabilization(state: .on)
                                mazeSphero.setFrontLed(color: .yellow)
                                mazeSphero.setBackLed(color: .yellow)
                                print("Stabilization enabled for Maze Sphero (\(mazeAssignment.spheroName))")
                                
                                // Clear the matrix first
                                for x in 0..<8 {
                                    for y in 0..<8 {
                                        mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .black)
                                    }
                                }
                                
                                // Draw the lightning preset
                                let lightningPreset = [
                                    [false, false, false, false, false, false, false, false],
                                    [false, false, false, false, true,  true,  true,  false],
                                    [false, false, false, true,  true,  true,  false, false],
                                    [false, false, true,  true,  true,  false, false, false],
                                    [false, true,  true,  true,  true,  true,  false, false],
                                    [false, false, false, true,  true,  false, false, false],
                                    [false, false, true,  true,  false, false, false, false],
                                    [false, true,  false, false, false, false, false, false],
                                ]
                                
                                // Apply the lightning preset
                                for x in 0..<8 {
                                    for y in 0..<8 where lightningPreset[x][y] {
                                        mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .yellow)
                                    }
                                }
                                print("Lightning preset sent to Maze Sphero (\(mazeAssignment.spheroName))")
                            } else {
                                print("No Sphero toy found for maze assignment")
                            }
                        } else {
                            print("No Sphero assigned to maze role")
                        }
                    }
            case "typhoon1":
                
                print("typhoon1 sphero connection received")
                
            case "typhoon2":
                
                print("typhoon2 sphero connection received")
                
            case "typhoon3":
                
                print("typhoon3 sphero connection received")
                
            case "typhoon4":
                print("typhoon4 sphero connection received")
                
            default:
                print( "Unknown message: \(message)")
            }
        }
        // Exemple de traitement pour Relay
        private func handleRelayMessage(_ message: ParsedMessage) {
            print("Relay message for \(message.component): \(message.data)")
        }
        
        
        func webSocketDidConnect(connection: WebSocketConnection) {
            // Respond to a WebSocket connection event
            print("DidConnect")
        }
        
        func webSocketDidDisconnect(connection: WebSocketConnection,
                                    closeCode: NWProtocolWebSocket.CloseCode, reason: Data?) {
            // Respond to a WebSocket disconnection event
            print("DidDisonnect")
        }
        
        func webSocketViabilityDidChange(connection: WebSocketConnection, isViable: Bool) {
            // Respond to a WebSocket connection viability change event
            print("Viability \(isViable)")
        }
        
        func webSocketDidAttemptBetterPathMigration(result: Result<WebSocketConnection, NWError>) {
            // Respond to when a WebSocket connection migrates to a better network path
            // (e.g. A device moves from a cellular connection to a Wi-Fi connection)
        }
        
        func webSocketDidReceiveError(connection: WebSocketConnection, error: NWError) {
            // Respond to a WebSocket error event
            print("Error \(error)")
        }
        
        func webSocketDidReceivePong(connection: WebSocketConnection) {
            // Respond to a WebSocket connection receiving a Pong from the peer
            print("Receive pong")
        }
        
        
        func webSocketDidReceiveMessage(connection: WebSocketConnection, data: Data) {
            // Respond to a WebSocket connection receiving a binary `Data` message
            print("Receive Data Message \(data)")
        }
    }
    struct ParsedMessage {
        let component: String
        let data: String
    }
    struct ParsedSendedMessage {
        let routeOrigin: String
        let routeTargets: [String]
        let component: String
        let data: String
    }
    struct DeviceResponse: Codable {
        let type: String
        let isConnected: Bool
        let id: String?
        
        enum CodingKeys: String, CodingKey {
            case type, isConnected, id
        }
    }

struct Device: Identifiable, Codable {
    var id: String { device }
    var device: String
    var isConnected: Bool
}
