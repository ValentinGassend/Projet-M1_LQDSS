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
    
    @Published var messageReceive:String = ""
    @Published var isRFIDDetectedForMaze:Bool = false
    @Published var isRFIDDetectedForTyphoon:Bool = false
    @Published var connectedDevices: [Device] = []
    
    func connectForIdentification(route: IdentificationRoute) {
        // Construire l'URL pour la route
        if let socketURL = URL(string: "ws://\(ipAddress)\(route.rawValue)Connect") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[route.rawValue] = socket
            
            // Envoyer le message de bienvenue pour la route
            sendWelcomeMessage(for: route)
            createMessageRoute(for: route)
            createPingRoute(for: route)
            if route == .remoteControllerConnect {
                
                let dashboardRouteKey = "\(route.rawValue)Dashboard"
                if let socketURL = URL(string: "ws://\(ipAddress)\(dashboardRouteKey)") {
                    let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
                    socket.delegate = self
                    socket.connect()
                    routes[dashboardRouteKey] = socket
                    socket.send(string: "getDevices")
                    print("Message route created for \(dashboardRouteKey)")
                }
            }
            
        }
    }
    
    func sendToDashboardroute (route:IdentificationRoute, msg: String ,completion: ((String?) -> Void)? = nil) {
        let dashboardRouteKey = "\(route.rawValue)Dashboard"
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
        // Construire l'URL pour la route de message
        let messageRouteKey = "\(route.rawValue)Message"
        if let socketURL = URL(string: "ws://\(ipAddress)\(messageRouteKey)") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[messageRouteKey] = socket
            
            print("Message route created for \(messageRouteKey)")
        }
    }
    private func createPingRoute(for route: IdentificationRoute) {
        // Construire l'URL pour la route de message
        let messageRouteKey = "\(route.rawValue)Ping"
        if let socketURL = URL(string: "ws://\(ipAddress)\(messageRouteKey)") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[messageRouteKey] = socket
            
            print("Ping route created for \(messageRouteKey)")
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
    func sentToRoute(route: IdentificationRoute, msg: String) {
        // Identifier la route de message associée
        let messageRouteKey = "\(route.rawValue)Message"
        
        // Vérifier si la route de message existe, sinon log une erreur
        if let socket = routes[messageRouteKey] {
            socket.send(string: msg)
            print("Sent: \(msg) to \(messageRouteKey)")
        } else {
            print("Error: Message route \(messageRouteKey) not found!")
        }
    }
    
    func sentToMessageRoute(route:IdentificationRoute, msg:String) {
        if let socket = routes[route.rawValue+"Message"] {
            socket.send(string: msg)
            print("Sended: \(msg) to \(route.rawValue+"Message")")
        }
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
            if origin.contains("maze") {
                
                self.sentToMessageRoute(route: IdentificationRoute.mazeIphoneConnect, msg: formattedMessage)
                
            }
            else {
                self.sentToMessageRoute(route: IdentificationRoute.typhoonIphoneConnect, msg: formattedMessage)
                
            }
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
            // Identifier la route d'identification associée (enlevant le suffixe "Ping")
            let identificationRouteKey = route.replacingOccurrences(of: "Ping", with: "")
            
            // Vérifier si une connexion existe pour cette route d'identification
            if let identificationSocket = routes[route] {
                // Renvoyer la valeur de la route d'identification
                //                    identificationSocket.send(string: identificationRouteKey)
                identificationSocket.send(string: "pong")
                //                    print("Responded to ping on \(route) with \(identificationRouteKey)")
            } else {
                print("Error: Identification route \(identificationRouteKey) not found for ping response")
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
        
        private func routeMessage(_ message: String, for route: String) {
            print("Route Message \(message) on route \(route)")
            
            guard let parsedMessage = parseMessage(message) else {
                print("Failed to parse message: \(message)")
                return
            }
            
            // Traitement basé sur le composant
            switch parsedMessage.component {
            case "rfid":
                handleRFIDMessage(parsedMessage)
            case "relay1", "relay2", "relay3", "relay4":
                handleRelayMessage(parsedMessage)
            case "sphero1", "sphero2", "sphero3", "sphero4":
                handleSpheroMessage(parsedMessage)
            case "sphero":
                handleSpheroConnectionMessage(parsedMessage)
            default:
                print("Unknown component: \(parsedMessage.component)")
            }
        }
        
        // Exemple de traitement pour RFID
    private func handleRFIDMessage(_ message: ParsedMessage) {
        print("component: \(message.component) data: \(message.data)")
        
        if message.data == "typhoon" {
            print("RFID message for typhoon")
            print("RFID detected")
            DispatchQueue.main.async {
                self.isRFIDDetectedForTyphoon = true
                print("isRFIDDetectedForTyphoon is now: \(self.isRFIDDetectedForTyphoon)")
            }
        }
        else if message.data == "maze" {
            print("RFID message for maze")
            print("RFID detected")
            isRFIDDetectedForMaze = true
        }
        else {
            print("RFID not detected")
        }
    }
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
                        guard let self = self else { return }
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
