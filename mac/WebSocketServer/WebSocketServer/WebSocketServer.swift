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
        "typhoon_iphone1": ("typhoon", false),
        "volcano_esp1": ("volcano", false),
        "volcano_esp2": ("volcano", false),
        "volcano_rpi": ("volcano", false),
        "maze_esp": ("maze", false),
        "maze_iphone": ("maze", false),
        "tornado_esp": ("tornado", false),
        "tornado_rpi": ("tornado", false),
        "crystal_esp1": ("crystal", false),
        "crystal_esp2": ("crystal", false),
        "volcano_espLed": ("volcano", false),
        "typhoon_espLed": ("typhoon", false),
        "maze_espLed": ("maze", false),
        "tornado_espLed": ("tornado", false),
        "crystal_espLed": ("crystal", false)
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
    
    
    
    @State var volcanoEspLedSession: WebSocketSession?
    @State var typhoonEspLedSession: WebSocketSession?
    @State var mazeEspLedSession: WebSocketSession?
    @State var tornadoEspLedSession: WebSocketSession?
    @State var crystalEspLedSession: WebSocketSession?
    
    // New device group sessions
    @State var typhoonEspSession: WebSocketSession?
    @State var typhoonIphoneSession: WebSocketSession?
    @State var typhoonIphone1Session: WebSocketSession?
    
    @State var volcanoEsp1Session: WebSocketSession?
    @State var volcanoEsp2Session: WebSocketSession?
    @State var volcanoRpiSession: WebSocketSession?
    
    @State var mazeEspSession: WebSocketSession?
    @State var mazeIphoneSession: WebSocketSession?
    
    @State var tornadoEspSession: WebSocketSession?
    @State var tornadoRpiSession: WebSocketSession?
    
    @State var crystalEsp1Session: WebSocketSession?
    @State var crystalEsp2Session: WebSocketSession?
    
    @State var ambianceManagerSession: WebSocketSession?
    
    var messageSession: [WebSocketSession?] = []
    
    // Dictionary to store ping-related sessions
    var pingableSessions: [String: PingSessionInfo] = [:]
    // Dictionary to store message-related sessions
    var messageSessions: [String: (session: WebSocketSession, isConnected: Bool)] = [:]
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                if text == "pong" {
                    // print("Received pong from route: \(routeInfos.routeName)")
                    self.sessionQueue.async {
                        if var sessionInfo = self.pingableSessions[routeInfos.routeName] {
                            sessionInfo.lastPingTime = Date()
                            sessionInfo.isConnected = true
                            sessionInfo.consecutiveFailures = 0
                            self.pingableSessions[routeInfos.routeName] = sessionInfo
                        }
                    }
                }
                else if routeInfos.routeName.contains("Message") {
                    print("Text received: \(text) from route: /\(routeInfos.routeName)")
                    if let parsedMessage = self.parseMessage(text) {
                        if let parsedMessageCode = routeInfos.parsedMessageCode {
                            parsedMessageCode(session, parsedMessage)
                        }
                        self.sendMessage(
                            from: parsedMessage.routeOrigin,
                            to: parsedMessage.routeTargets,
                            component: parsedMessage.component,
                            data: parsedMessage.data
                        )
                    } else {
                        print("Failed to parse message: \(text)")
                    }
                }
                else {
                    print("Text received: \(text) from route: /\(routeInfos.routeName)")
                    
                    // Handle other route types
                    routeInfos.textCode(session, text)
                }
                
                // Update last ping time for Ping routes
                if routeInfos.routeName.hasSuffix("Ping") {
                    self.updateLastPingTime(for: routeInfos.routeName, session: session)
                }
            },
            binary: { session, binary in
                let data = Data(binary)
                print("Data received: \(data) from route: /\(routeInfos.routeName)")
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
                if routeInfos.routeName.contains("iphone") {
                    self.cleanupExistingPhoneSession(routeName: routeInfos.routeName)
                }
                routeInfos.connectedCode?(session)
                if (routeInfos.routeName.contains("Connect")){
                    let deviceName = self.normalizeDeviceName(routeName: routeInfos.routeName)
                    
                    if routeInfos.routeName.contains("iphone") {
                        switch deviceName {
                        case "typhoon_iphone":
                            self.typhoonIphoneSession = session
                        case "typhoon_iphone1":
                            self.typhoonIphone1Session = session
                        case "maze_iphone":
                            self.mazeIphoneSession = session
                        default:
                            break
                        }
                    }
                    self.updateDeviceState(routeName: routeInfos.routeName, isConnected: true)
                    print("sending hello message to \(routeInfos.routeName)")
                    session.writeText("Hello from \(routeInfos.routeName)!")
                    
                }
                // Only send hello message if it's not the dashboard
                if !routeInfos.routeName.contains("Dashboard") {
                    session.writeText("Hello from \(routeInfos.routeName)!")
                    
                }
                if routeInfos.routeName.hasSuffix("Ping") {
                    
                    self.sessionQueue.async {
                        self.pingableSessions[routeInfos.routeName] = PingSessionInfo(
                            session: session,
                            isConnected: true,
                            lastPingTime: Date()
                        )
                    }
                }
                else if routeInfos.routeName.contains("Message") {
                    print("Message session connected: \(routeInfos.routeName)")
                    self.sessionQueue.async {
                        let deviceName = self.normalizeDeviceName(routeName: routeInfos.routeName)
                        self.messageSessions[deviceName] = (session, true)
                        print("Registered message session for \(deviceName): \(session)")
                    }
                }
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
                routeInfos.disconnectedCode?(session)
                self.updateDeviceState(routeName: routeInfos.routeName, isConnected: false)
                
                if let pingableSession = self.pingableSessions[routeInfos.routeName] {
                    if pingableSession.isConnected {
                        
                        if (routeInfos.routeName.contains("Connect")){
                            print("Client disconnected from route: /\(routeInfos.routeName)")
                        }
                        else if routeInfos.routeName.contains("Ping") {
                            
                            self.cleanupPingSession(for: routeInfos.routeName)
                            print("Route with 'Ping' suffix is disconnected")
                        }
                    }
                }
            }
        )
    }
    private func cleanupExistingPhoneSession(routeName: String) {
        sessionQueue.async {
            let deviceName = self.normalizeDeviceName(routeName: routeName)
            
            // Clean up message sessions
            if self.messageSessions[deviceName] != nil {
                print("Cleaning up existing message session for \(deviceName)")
                self.messageSessions.removeValue(forKey: deviceName)
            }
            
            // Clean up ping sessions
            let pingRouteName = deviceName + "Ping"
            if self.pingableSessions[pingRouteName] != nil {
                print("Cleaning up existing ping session for \(pingRouteName)")
                self.pingableSessions.removeValue(forKey: pingRouteName)
            }
            
            // Update device state
            self.updateDeviceState(routeName: deviceName, isConnected: false)
            
            // Clean up specific phone sessions based on device name
            switch deviceName {
            case "typhoon_iphone":
                self.typhoonIphoneSession = nil
            case "maze_iphone":
                self.mazeIphoneSession = nil
            default:
                break
            }
        }
    }
    private func registerMessageSession(routeName: String, session: WebSocketSession) {
        let deviceName = normalizeDeviceName(routeName: routeName)
        sessionQueue.async {
            self.messageSessions[deviceName] = (session: session, isConnected: true)
            print("Registered message session for \(deviceName)")
        }
    }
    
    // Handle device connections/disconnections (this logic remains unchanged)
    private func handleDeviceConnections(_ routeInfos: RouteInfos, _ session: WebSocketSession) {
        switch routeInfos.routeName {
        case "typhoon_espConnect": self.typhoonEspSession = session
        case "typhoon_espDisconnect": self.typhoonEspSession = nil
        case "typhoon_iphoneConnect": self.typhoonIphoneSession = session
        case "typhoon_iphoneDisconnect": self.typhoonIphoneSession = nil
        case "typhoon_iphone1Connect": self.typhoonIphone1Session = session
        case "typhoon_iphone1Disconnect": self.typhoonIphone1Session = nil
            
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
            
        case "volcano_espLedConnect": self.volcanoEspLedSession = session
        case "volcano_espLedDisconnect": self.volcanoEspLedSession = nil
        case "typhoon_espLedConnect": self.typhoonEspLedSession = session
        case "typhoon_espLedDisconnect": self.typhoonEspLedSession = nil
        case "maze_espLedConnect": self.mazeEspLedSession = session
        case "maze_espLedDisconnect": self.mazeEspLedSession = nil
        case "tornado_espLedConnect": self.tornadoEspLedSession = session
        case "tornado_espLedDisconnect": self.tornadoEspLedSession = nil
        case "crystal_espLedConnect": self.crystalEspLedSession = session
        case "crystal_espLedDisconnect": self.crystalEspLedSession = nil
        default: break
        }
    }
    
    private func startPingRoutine() {
        Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { _ in
            self.sessionQueue.async {
                for (route, sessionInfo) in self.pingableSessions {
                    // Envoyer d'abord le ping
                    sessionInfo.session.writeText("ping")
                    // print("Ping sent to \(route)")
                    
                    // Ensuite vérifier si le dernier pong a été reçu dans les temps
                    if Date().timeIntervalSince(sessionInfo.lastPingTime) > self.pingTimeout {
                        var updatedInfo = sessionInfo
                        updatedInfo.consecutiveFailures += 1
                        self.pingableSessions[route] = updatedInfo
                        
                        if updatedInfo.consecutiveFailures >= PingSessionInfo.maxFailures {
                            print("Device \(route) failed to respond to ping \(PingSessionInfo.maxFailures) times. Disconnecting...")
                            sessionInfo.session.socket.close()
                            self.pingableSessions[route] = nil
                            let nameRoute = self.normalizeDeviceName(routeName: route)
                            self.updateDeviceState(routeName: route, isConnected: false)
                            self.updateDeviceState(routeName: nameRoute, isConnected: false)
                        }
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
            "typhoon_iphone1": typhoonIphone1Session,
            "volcano_esp1": volcanoEsp1Session,
            "volcano_esp2": volcanoEsp2Session,
            "volcano_rpi": volcanoRpiSession,
            "maze_esp": mazeEspSession,
            "maze_iphone": mazeIphoneSession,
            "tornado_esp": tornadoEspSession,
            "tornado_rpi": tornadoRpiSession,
            "crystal_esp1": crystalEsp1Session,
            "crystal_esp2": crystalEsp2Session,
            "volcano_espLed": volcanoEspLedSession,
            "typhoon_espLed": typhoonEspLedSession,
            "maze_espLed": mazeEspLedSession,
            "tornado_espLed": tornadoEspLedSession,
            "crystal_espLed": crystalEspLedSession
        ]
    }
    func normalizeDeviceName(routeName: String) -> String {
        if routeName.hasSuffix("Connect") {
            return String(routeName.dropLast("Connect".count))
        } else if routeName.hasSuffix("Message") {
            return String(routeName.dropLast("Message".count))
            
        } else if routeName.hasSuffix("Ping") {
            return String(routeName.dropLast("Ping".count))
            
        }
        return routeName
    }
    private func sessions(for targets: [String]) -> [WebSocketSession] {
        targets.compactMap { target in
            print("Fetching session for target: \(target)")
            
            //            print("message session : \(messageSessions)")
            if let messageSession = messageSessions[target]?.session {
                return messageSession
            }
            return nil
        }
    }
    func updateDeviceState(routeName: String, isConnected: Bool) {
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
        let message = "\(component)#\(data)"
        print("Sending message: \(message) to routes: \(to)")
        
        // Vérifie si 'to' contient 'typhoon_iphone' et ajoute 'typhoon_iphone1' si nécessaire
        var updatedTo = to
        if to.contains("typhoon_iphone") {
            updatedTo.append("typhoon_iphone1")
        }
        
        let targetSessions = sessions(for: updatedTo)
        
        if targetSessions.isEmpty {
            print("Warning: No active sessions found for targets: \(updatedTo)")
            return
        }
        
        for session in targetSessions {
            //            print("Sending to session: \(session)")
            session.writeText(message)
        }
    }
    
    
    
    func onDisconnectedHandle(_ handle: WebSocketSession) {
        // deconnecte la session
    }
    func parseMessage(_ message: String) -> ParsedMessage? {
        let components = message.components(separatedBy: "=>")
        guard components.count == 3 else {
            print("Invalid message format (wrong number of components): \(message)")
            return nil
        }
        
        let origin = components[0].trimmingCharacters(in: .whitespaces)
        
        let targetsString = components[1]
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let targets = targetsString
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let componentData = components[2].components(separatedBy: "#")
        guard componentData.count == 2 else {
            print("Invalid component/data format: \(components[2])")
            return nil
        }
        
        return ParsedMessage(
            routeOrigin: origin,
            routeTargets: targets,
            component: componentData[0].trimmingCharacters(in: .whitespaces),
            data: componentData[1].trimmingCharacters(in: .whitespaces)
        )
    }
}


struct PingSessionInfo {
    var session: WebSocketSession
    var isConnected: Bool
    var lastPingTime: Date
    var consecutiveFailures: Int = 0
    static let maxFailures = 3
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
