import Swifter
import SwiftUI
import Foundation
import Combine

struct RouteInfos {
    var routeName: String
    var textCode: (WebSocketSession, String) -> ()
    var dataCode: (WebSocketSession, Data) -> ()
    var connectedCode: ((WebSocketSession) -> ())? = nil
    var disconnectedCode: ((WebSocketSession) -> ())? = nil
}

class WebSockerServer {
    
    private let pingInterval: TimeInterval = 3.0
    private let pingTimeout: TimeInterval = 6.0
    
    static let instance = WebSockerServer()
    let server = HttpServer()
    var deviceStates: [String: (macAddress: String, isConnected: Bool)] = [
        "rpiLaser": ("AA:BB:CC:DD:EE:01", false),
        "iPhone": ("AA:BB:CC:DD:EE:03", false),
        "rvrTornado": ("AA:BB:CC:DD:EE:04", false),
        "remoteController": ("AA:BB:CC:DD:EE:04", false),
    ]
    
    // Original sessions
    var rpiSession: WebSocketSession?
    var laserSession: WebSocketSession?
    var iPhoneSession: WebSocketSession?
    var rvrTornadoSession: WebSocketSession?
    var remoteControllerSession: WebSocketSession?
    
    // Sphero sessions
    var spheroTyphoonId: String?
    var spheroTyphoonIsConnected: Bool = false
    var spheroStickId: String?
    var spheroStickIsConnected: Bool = false
    
    // New device group sessions
    var typhoonEspSession: WebSocketSession?
    var typhoonIphoneSession: WebSocketSession?
    
    var volcanoEspSession: WebSocketSession?
    var volcanoRpiSession: WebSocketSession?
    
    var electricityEspSession: WebSocketSession?
    var electricityIphoneSession: WebSocketSession?
    
    var tornadoEspSession: WebSocketSession?
    var tornadoRpiSession: WebSocketSession?
    
    var crystalEsp1Session: WebSocketSession?
    var crystalEsp2Session: WebSocketSession?
    
    // Dictionary to store ping-related sessions
    var pingableSessions: [String: (session: WebSocketSession, isConnected: Bool, lastPingTime: Date)] = [:]
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                print("Text received: \(text) from route: /\(routeInfos.routeName)")
                
                if text == "pong" {
                    self.pingableSessions[routeInfos.routeName]?.lastPingTime = Date()
                    self.pingableSessions[routeInfos.routeName]?.isConnected = true
                    print("Received pong from route: \(routeInfos.routeName)")
                  } else {
                      // Traitez d'autres messages normalement
                      routeInfos.textCode(session, text)
                  }
                
                
                // Update last ping time for routes ending with 'Ping'
                if routeInfos.routeName.hasSuffix("Ping") {
                    self.updateLastPingTime(for: routeInfos.routeName, session: session)
                }
                
                // Call the original text handler
                routeInfos.textCode(session, text)
                
                // Update device group session (handle routes for connecting and disconnecting devices)
                self.handleDeviceConnections(routeInfos, session)
                
                
            },
            binary: { session, binary in
                let data = Data(binary)
                print("Data received: \(data) from route: /\(routeInfos.routeName)")
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                routeInfos.connectedCode?(session)
                session.writeText("Hello from \(routeInfos.routeName)!")
                
                self.pingableSessions[routeInfos.routeName] = (session: session, isConnected: true, lastPingTime: Date())
                // Set up periodic ping for routes ending with 'Ping'
                if routeInfos.routeName.contains("Ping") {
                    print("Route with 'Ping' suffix is connected")
                }
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                routeInfos.disconnectedCode?(session)
                self.pingableSessions[routeInfos.routeName]?.isConnected = false
                // Clean up ping-related data when disconnected
                if routeInfos.routeName.contains("Ping") {
                    print("Route with 'Ping' suffix is disconnected")
                    self.cleanupPingSession(for: routeInfos.routeName)
                }
            }
        )
    }

    
    // Handle device connections/disconnections (this logic remains unchanged)
    private func handleDeviceConnections(_ routeInfos: RouteInfos, _ session: WebSocketSession) {
        switch routeInfos.routeName {
        case "typhoon_espConnect": self.typhoonEspSession = session
        case "typhoon_espDisconnect": self.typhoonEspSession = nil
        case "typhoon_iphoneConnect": self.typhoonIphoneSession = session
        case "typhoon_iphoneDisconnect": self.typhoonIphoneSession = nil
        
        case "volcano_espConnect": self.volcanoEspSession = session
        case "volcano_espDisconnect": self.volcanoEspSession = nil
        case "volcano_rpiConnect": self.volcanoRpiSession = session
        case "volcano_rpiDisconnect": self.volcanoRpiSession = nil
        
        case "electricity_espConnect": self.electricityEspSession = session
        case "electricity_espDisconnect": self.electricityEspSession = nil
        case "electricity_iphoneConnect": self.electricityIphoneSession = session
        case "electricity_iphoneDisconnect": self.electricityIphoneSession = nil
        
        case "tornado_espConnect": self.tornadoEspSession = session
        case "tornado_espDisconnect": self.tornadoEspSession = nil
        case "tornado_rpiConnect": self.tornadoRpiSession = session
        case "tornado_rpiDisconnect": self.tornadoRpiSession = nil
        
        case "crystal_esp1Connect": self.crystalEsp1Session = session
        case "crystal_esp1Disconnect": self.crystalEsp1Session = nil
        case "crystal_esp2Connect": self.crystalEsp2Session = session
        case "crystal_esp2Disconnect": self.crystalEsp2Session = nil
        
        default: break
        }
    }
    
    private func startPingRoutine() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            for pingableSession in self.pingableSessions {
                pingableSession.value.session.writeText("ping")
                
                if Date().timeIntervalSince(pingableSession.value.lastPingTime) > self.pingTimeout {
                    // Si aucun pong reçu dans le délai, marquer comme non connecté
                    pingableSession.value.session.socket.close()
                }
            }
        }
    }
    
    private func updateLastPingTime(for route: String, session: WebSocketSession) {
        // Update the last ping time for this route
        pingableSessions[route]?.lastPingTime = Date()
    }

    private func cleanupPingSession(for route: String) {
        // Invalidate the specific ping timer and remove the route's data
        pingableSessions[route] = nil
    }
    
    func start() {
        do {
            try server.start()
            self.startPingRoutine()
            print("Server has started (port = \(try server.port())). Try to connect now...")
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
}

extension WebSockerServer {
    func onDisconnectedHandle(_ handle: WebSocketSession) {
        // deconnecte la session
    }
}
