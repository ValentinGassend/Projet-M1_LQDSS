//
//  WebSocketClient.swift
//  WebSocketClient
//
//  Created by digital on 22/10/2024.
//

import SwiftUI
import Network
import NWWebSocket

class WebSocketClient:ObservableObject {
    static let instance = WebSocketClient()
    
    var routes = [String:NWWebSocket]()
    var ipAddress = "192.168.1.15:8080/"
    
    @Published var messageReceive:String = ""
    
    func connectForIdentification(route: IdentificationRoute) {
        // Construire l'URL pour la route
        if let socketURL = URL(string: "ws://\(ipAddress)\(route.rawValue)Connect") {
            let socket = NWWebSocket(url: socketURL, connectAutomatically: true)
            socket.delegate = self
            socket.connect()
            routes[route.rawValue] = socket
            
            // Envoyer le message de bienvenue pour la route
            sendWelcomeMessage(for: route)
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
    func sentToRoute(route:IdentificationRoute, msg:String) {
        if let socket = routes[route.rawValue] {
            socket.send(string: msg)
            print("Sended: \(msg) to \(route.rawValue)")
        }
    }
    func sendWelcomeMessage(for route: IdentificationRoute) {
        // Envoie le message de bienvenue pour cette route
        if let socket = routes[route.rawValue] {
            let message = route.welcomeMessage
            socket.send(string: message)
            print("Message sent: \(message)")
        }
    }
}

extension WebSocketClient: WebSocketConnectionDelegate {
    
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
    
    func webSocketDidReceiveMessage(connection: WebSocketConnection, string: String) {
        // Respond to a WebSocket connection receiving a `String` message
        print("Receive String Message \(string)")
        messageReceive = string
    }
    
    func webSocketDidReceiveMessage(connection: WebSocketConnection, data: Data) {
        // Respond to a WebSocket connection receiving a binary `Data` message
        print("Receive Data Message \(data)")
    }
}
