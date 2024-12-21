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
    private let sessionQueue = DispatchQueue(label: "WebSocketServer.SessionQueue")
    
    static let instance = WebSockerServer()
    let server = HttpServer()
    var deviceStates: [String: (type: String, isConnected: Bool)] = [
        "rpiLaser": ("original", false),
        "iPhone": ("original", false),
        "rvrTornado": ("original", false),
        "remoteController": ("original", false),
        "typhoon_esp": ("typhoon", false),
        "typhoon_iphone": ("typhoon", false),
        "volcano_esp1": ("volcano", false),
        "volcano_esp2": ("volcano", false),
        "volcano_rpi": ("volcano", false),
        "maze_esp": ("maze", false),
        "maze_iphone": ("maze", false),
        "tornado_esp": ("tornado", false),
        "tornado_rpi": ("tornado", false),
        "crystal_esp1": ("crystal", false),
        "crystal_esp2": ("crystal", false)
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
    @State var typhoonEspSession: WebSocketSession?
    @State var typhoonIphoneSession: WebSocketSession?
    
    @State var volcanoEsp1Session: WebSocketSession?
    @State var volcanoEsp2Session: WebSocketSession?
    @State var volcanoRpiSession: WebSocketSession?
    
    @State var mazeEspSession: WebSocketSession?
    @State var mazeIphoneSession: WebSocketSession?
    
    @State var tornadoEspSession: WebSocketSession?
    @State var tornadoRpiSession: WebSocketSession?
    
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
                    self.sessionQueue.async {
                        self.pingableSessions[routeInfos.routeName]?.lastPingTime = Date()
                        self.pingableSessions[routeInfos.routeName]?.isConnected = true
                    }
                }
                else if routeInfos.routeName.contains("Connect"){
                    print("Received \(text) from route: \(routeInfos.routeName)")
                    
                    self.updateDeviceState(routeName: routeInfos.routeName, isConnected: true, session: session)
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
                if routeInfos.routeName.hasSuffix("Ping") {
                    self.sessionQueue.async {
                        self.pingableSessions[routeInfos.routeName] = (session: session, isConnected: true, lastPingTime: Date())
                    }
                }
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                routeInfos.disconnectedCode?(session)
                if let pingableSession = self.pingableSessions[routeInfos.routeName] {
                    if pingableSession.isConnected {
                        if routeInfos.routeName.contains("Ping") {
                            
                            self.cleanupPingSession(for: routeInfos.routeName)
                            print("Route with 'Ping' suffix is disconnected")
                        }
                    }
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
            
        case "volcano_esp1Connect": self.volcanoEsp1Session = session
        case "volcano_esp1Disconnect": self.volcanoEsp1Session = nil
        case "volcano_esp2Connect": self.volcanoEsp2Session = session
        case "volcano_esp2Disconnect": self.volcanoEsp2Session = nil
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
    
    private func startPingRoutine() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            self.sessionQueue.async {
                for (route, sessionInfo) in self.pingableSessions {
                    if Date().timeIntervalSince(sessionInfo.lastPingTime) > self.pingTimeout {
                        sessionInfo.session.socket.close()
                        self.pingableSessions[route] = nil
                    } else {
                        sessionInfo.session.writeText("ping")
                    }
                }
            }
        }
    }
    
    private func updateLastPingTime(for route: String, session: WebSocketSession) {
        self.sessionQueue.async {
            self.pingableSessions[route]?.lastPingTime = Date()
        }
    }
    
    private func cleanupPingSession(for route: String) {
        self.sessionQueue.async {
            self.pingableSessions[route] = nil
        }
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
            "volcano_esp1": volcanoEsp1Session,
            "volcano_esp2": volcanoEsp2Session,
            "volcano_rpi": volcanoRpiSession,
            "maze_esp": mazeEspSession,
            "maze_iphone": mazeIphoneSession,
            "tornado_esp": tornadoEspSession,
            "tornado_rpi": tornadoRpiSession,
            "crystal_esp1": crystalEsp1Session,
            "crystal_esp2": crystalEsp2Session
        ]
    }
    func normalizeDeviceName(routeName: String) -> String {
        if routeName.hasSuffix("Connect") {
            return String(routeName.dropLast("Connect".count))
        }
        return routeName
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
    func updateDeviceState(routeName: String, isConnected: Bool, session: WebSocketSession?) {
        let deviceName = normalizeDeviceName(routeName: routeName)
        sessionQueue.async {
            if var state = self.deviceStates[deviceName] {
                state.isConnected = isConnected
                self.deviceStates[deviceName] = state
                print("Updated state for \(deviceName): isConnected = \(isConnected)")
            } else {
                print("Device \(deviceName) not found in deviceStates")
            }
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

struct DeviceResponse: Codable {
    let type: String
    let isConnected: Bool
    let id: String?  // Optionnel car uniquement présent pour les Sphero
    
    enum CodingKeys: String, CodingKey {
        case type, isConnected, id
    }
}
