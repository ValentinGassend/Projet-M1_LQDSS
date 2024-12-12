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
    
    private var timer: Timer?
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
    
    var mazeEspSession: WebSocketSession?
    var mazeIphoneSession: WebSocketSession?
    
    var tornadoEspSession: WebSocketSession?
    var tornadoRpiSession: WebSocketSession?
    
    var crystalEsp1Session: WebSocketSession?
    var crystalEsp2Session: WebSocketSession?
    
    // Dictionary to store ping-related sessions
    var pingableSessions: [String: (session: WebSocketSession, lastPingTime: Date, pingTimer: Timer?)] = [:]
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { [weak self] session, text in
                print("Text received: \(text) from route: /\(routeInfos.routeName)")
                
                // Update last ping time for routes ending with 'Ping'
                if routeInfos.routeName.hasSuffix("Ping") {
                    self?.updateLastPingTime(for: routeInfos.routeName, session: session)
                }
                
                // Call the original text handler
                routeInfos.textCode(session, text)
                
                // Update device group session (handle routes for connecting and disconnecting devices)
                self?.handleDeviceConnections(routeInfos, session)
            },
            binary: { session, binary in
                let data = Data(binary)
                print("Data received: \(data) from route: /\(routeInfos.routeName)")
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { [weak self] session in
                print("Client connected to route: /\(routeInfos.routeName)")
                routeInfos.connectedCode?(session)
                session.writeText("Hello from \(routeInfos.routeName)!")
                
                // Set up periodic ping for routes ending with 'Ping'
                if routeInfos.routeName.contains("Ping") {
                    print("Route with 'Ping' suffix is connected")
                    self!.setupPingTimer(for: routeInfos.routeName, session: session)
                }
            },
            disconnected: { [weak self] session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                routeInfos.disconnectedCode?(session)
                
                // Clean up ping-related data when disconnected
                if routeInfos.routeName.contains("Ping") {
                    print("Route with 'Ping' suffix is disconnected")
                    self?.cleanupPingSession(for: routeInfos.routeName)
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
        
        case "maze_espConnect": self.mazeEspSession = session
        case "maze_espDisconnect": self.mazeEspSession = nil
        case "maze_iphoneConnect": self.mazeIphoneSession = session
        case "maze_iphoneDisconnect": self.mazeIphoneSession = nil
        
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
    
    private func setupPingTimer(for route: String, session: WebSocketSession) {
        // Create a timer for the specific route
        print("setup ping timer for route: \(route)")
        let pingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Send ping message
            print("send ping to route: \(route)")
            session.writeText("ping")
            
            // Check if no response received for more than 3 seconds
            if let lastPingTime = self.pingableSessions[route]?.lastPingTime,
               Date().timeIntervalSince(lastPingTime) > 3.0 {
                // Disconnect the session if no response
                print("No response for 3 seconds, disconnecting...")
                session.socket.close()
                self.cleanupPingSession(for: route)
            }
        }

        // Store the timer for this route
        pingableSessions[route]?.pingTimer = pingTimer
    }
    
    private func updateLastPingTime(for route: String, session: WebSocketSession) {
        // Update the last ping time for this route
        pingableSessions[route]?.lastPingTime = Date()
    }

    private func cleanupPingSession(for route: String) {
        // Invalidate the specific ping timer and remove the route's data
        pingableSessions[route]?.pingTimer?.invalidate()
        pingableSessions[route] = nil
    }
    
    func start() {
        do {
            try server.start()
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
