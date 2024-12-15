import Swifter
import SwiftUI
import Foundation
import Combine

struct RouteInfos {
    var routeName: String
    var textCode: (WebSocketSession, String) -> ()
    var dataCode: (WebSocketSession, Data) -> ()
    var parsedMessageCode: ((WebSocketSession, ParsedMessage) -> ())? = nil
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
    @State var typhoonIphoneSession: WebSocketSession?
    
    var volcanoEspSession: WebSocketSession?
    var volcanoRpiSession: WebSocketSession?
    
    var electricityEspSession: WebSocketSession?
    var electricityIphoneSession: WebSocketSession?
    
    var tornadoEspSession: WebSocketSession?
    var tornadoRpiSession: WebSocketSession?
    
    var crystalEsp1Session: WebSocketSession?
    var crystalEsp2Session: WebSocketSession?
    
    var messageSession: [WebSocketSession?] = []
    
    // Dictionary to store ping-related sessions
    var pingableSessions: [String: (session: WebSocketSession, isConnected: Bool, lastPingTime: Date)] = [:]
    // Dictionary to store message-related sessions
    var messageSessions: [String: (session: WebSocketSession, isConnected: Bool)] = [:]
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                
                if text == "pong" {
                    self.pingableSessions[routeInfos.routeName]?.lastPingTime = Date()
                    self.pingableSessions[routeInfos.routeName]?.isConnected = true
                    //                    print("Received pong from route: \(routeInfos.routeName)")
                }
                else if routeInfos.routeName.contains("Connect"){
                    print("Received \(text) from route: \(routeInfos.routeName)")
                } else if routeInfos.routeName.contains("Message") {
                    self.messageSessions[routeInfos.routeName.replacing("Message", with: "")] = (session, true)
                    print("Text received: \(text) from route: /\(routeInfos.routeName)")
                    if let parsedMessage = self.parseMessage(text){
                        if let parsedMessageCode = routeInfos.parsedMessageCode {
                            parsedMessageCode(session, parsedMessage)
                        } else {
                            print("Invalid message format received: \(text)")
                        }
                    }
                } else {
                    print("Text received: \(text) from route: /\(routeInfos.routeName)")
                    routeInfos.textCode(session, text)
                }
                
                
                // Update last ping time for routes ending with 'Ping'
                if routeInfos.routeName.hasSuffix("Ping") {
                    self.updateLastPingTime(for: routeInfos.routeName, session: session)
                }
                
                // Call the original text handler
                //                routeInfos.textCode(session, text)
                
                // Update device group session (handle routes for connecting and disconnecting devices)
                //                self.handleDeviceConnections(routeInfos, session)
                
                
            },
            binary: { session, binary in
                let data = Data(binary)
                print("Data received: \(data) from route: /\(routeInfos.routeName)")
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                routeInfos.connectedCode?(session)
                if (routeInfos.routeName.contains("Connect")){
                    session.writeText("Hello from \(routeInfos.routeName)!")
                }
                if (routeInfos.routeName.contains("Ping")){
                    self.pingableSessions[routeInfos.routeName] = (session: session, isConnected: true, lastPingTime: Date())
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
    private var sessionMapping: [String: WebSocketSession?] {
        return [
            "typhoon_esp": typhoonEspSession,
            "typhoon_iphone": typhoonIphoneSession,
            "volcano_esp": volcanoEspSession,
            "volcano_rpi": volcanoRpiSession,
            "electricity_esp": electricityEspSession,
            "electricity_iphone": electricityIphoneSession,
            "tornado_esp": tornadoEspSession,
            "tornado_rpi": tornadoRpiSession,
            "crystal_esp1": crystalEsp1Session,
            "crystal_esp2": crystalEsp2Session
        ]
    }
    private func sessions(for targets: [String]) -> [WebSocketSession] {
        targets.compactMap { target in
            print("Fetching session for target: \(target)")
            if let messageSession = messageSessions[target]?.session {
                return messageSession
            }
            return nil
        }
    }
    func sendMessage(from: String, to: [String], component: String, data: String) {
        let message = "\(from)=>[\(to.joined(separator: ","))]=>\(component)#\(data)"
        print("Envoi du message : \(message) vers les routes : \(to)")
        
        // Récupérer les sessions des cibles
        let targetSessions = sessions(for: to) // `to` contient "typhoon_iphone", etc.
        
        for session in targetSessions {
            print("Envoi de \(message) à la session : \(session)")
            session.writeText(message)
        }
    }
    
    
    func onDisconnectedHandle(_ handle: WebSocketSession) {
        // deconnecte la session
    }
    func parseMessage(_ message: String) -> ParsedMessage? {
        let components = message.components(separatedBy: "=>")
        guard components.count == 3 else {
            print("Invalid message format: \(message)")
            return nil
        }
        
        // Extraction des cibles et des données
        let routeTargetsRaw = components[1]
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        let componentData = components[2].components(separatedBy: "#")
        guard componentData.count == 2 else {
            print("Invalid component format in message: \(message)")
            return nil
        }
        
        return ParsedMessage(
            routeOrigin: components[0],
            routeTargets: routeTargetsRaw,
            component: componentData[0],
            data: componentData[1]
        )
    }
}


struct ParsedMessage {
    let routeOrigin: String
    let routeTargets: [String]
    let component: String
    let data: String
    func toString() -> String {
        "==== Parsed Message ====\norigin: \(routeOrigin)\ntargets: \(routeTargets.joined(separator: ","))\ncomponent: \(component)\ndata: \(data)\n========================"
    }
}

