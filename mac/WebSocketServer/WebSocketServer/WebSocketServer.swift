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
    private let sessionQueue = DispatchQueue(
        label: "WebSocketServer.SessionQueue"
    )
    
    static let instance = WebSockerServer()
    let server = HttpServer()
    var deviceStates: [String: (type: String, isConnected: Bool)] = [
        "remoteController_iphone3": ("remoteController", false),
        "remoteController_iphone2": ("remoteController", false),
        "remoteController_iphone1": ("remoteController", false),
        "tornado_rpi": ("tornado", false),
        "typhoon_esp": ("typhoon", false),
        "volcano_esp1": ("volcano", false),
        "volcano_esp2": ("volcano", false),
        "maze_esp": ("maze", false),
        "tornado_esp": ("tornado", false),
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
    @State var remoteController_iphone3Session: WebSocketSession?
    @State var remoteController_iphone2Session: WebSocketSession?
    @State var remoteController_iphone1Session: WebSocketSession?
    
    @State var volcanoEsp1Session: WebSocketSession?
    @State var volcanoEsp2Session: WebSocketSession?
    
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
    
    let audioPlayer = AudioPlayer.shared
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: {
                session,
                text in
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
                else if routeInfos.routeName == "remoteController_iphone1Dashboard" {
                    //                    print("Message received on remoteController_iphone1Dashboard: \(text)")
                    if text == "getDevices" {
                        //                        self.audioPlayer.playSound()
                        self.sessionQueue.async {
                            let allDevices = self.deviceStates.mapValues { state in
                                [
                                    "type": state.type,
                                    "isConnected": state.isConnected
                                ]
                            }
                            
                            do {
                                let jsonData = try JSONSerialization.data(
                                    withJSONObject: allDevices,
                                    options: .prettyPrinted
                                )
                                if let jsonString = String(
                                    data: jsonData,
                                    encoding: .utf8
                                ) {
                                    session.writeText(jsonString)
                                    //                                    print("Sent device states to dashboard: \(jsonString)")
                                }
                            } catch {
                                print("Error generating JSON: \(error)")
                            }
                        }
                    }
                }
                else if routeInfos.routeName.contains("Message") {
                    print(
                        "Text received: \(text) from route: /\(routeInfos.routeName)"
                    )
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
                    print(
                        "Text received: \(text) from route: /\(routeInfos.routeName)"
                    )
                    
                    // Handle other route types
                    routeInfos.textCode(session, text)
                }
                
                // Update last ping time for Ping routes
                if routeInfos.routeName.hasSuffix("Ping") {
                    self.updateLastPingTime(
                        for: routeInfos.routeName,
                        session: session
                    )
                }
            },
            binary: {
                session,
                binary in
                let data = Data(binary)
                print(
                    "Data received: \(data) from route: /\(routeInfos.routeName)"
                )
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                if  !routeInfos.routeName.contains("Dashboard") {
                    print("Client connected to route: /\(routeInfos.routeName)")
                }
                if routeInfos.routeName.contains("iphone") {
                    self.handleIPhoneConnection(
                        routeName: routeInfos.routeName,
                        session: session
                    )
                }
                routeInfos.connectedCode?(session)
                if (routeInfos.routeName.contains("Connect")){
                    let deviceName = self.normalizeDeviceName(
                        routeName: routeInfos.routeName
                    )
                    
                    if routeInfos.routeName.contains("iphone") {
                        switch deviceName {
                        case "remoteController_iphone1":
                            self.remoteController_iphone1Session = session
                        case "remoteController_iphone2":
                            self.remoteController_iphone2Session = session
                         case "remoteController_iphone3":
                            self.remoteController_iphone3Session = session
                            
                        default:
                            break
                        }
                    }
                    self.updateDeviceState(
                        routeName: routeInfos.routeName,
                        isConnected: true
                    )
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
                        let deviceName = self.normalizeDeviceName(
                            routeName: routeInfos.routeName
                        )
                        self.messageSessions[deviceName] = (session, true)
                        print(
                            "Registered message session for \(deviceName): \(session)"
                        )
                    }
                }
            },
            disconnected: { session in
                print(
                    "Client disconnected from route: /\(routeInfos.routeName)"
                )
                
                // Gérer la déconnexion iPhone si nécessaire
                if routeInfos.routeName.contains("iphone") {
                    self.handleIPhoneDisconnection(
                        routeName: routeInfos.routeName,
                        session: session
                    )
                }
                
                routeInfos.disconnectedCode?(session)
                self.updateDeviceState(
                    routeName: routeInfos.routeName,
                    isConnected: false
                )
                
                if let pingableSession = self.pingableSessions[routeInfos.routeName] {
                    if pingableSession.isConnected {
                        if (routeInfos.routeName.contains("Connect")) {
                            print(
                                "Client disconnected from route: /\(routeInfos.routeName)"
                            )
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
            
        }
    }
    private func registerMessageSession(
        routeName: String,
        session: WebSocketSession
    ) {
        let deviceName = normalizeDeviceName(routeName: routeName)
        sessionQueue.async {
            self.messageSessions[deviceName] = (
                session: session,
                isConnected: true
            )
            print("Registered message session for \(deviceName)")
        }
    }
    
    // Handle device connections/disconnections (this logic remains unchanged)
    private func handleDeviceConnections(
        _ routeInfos: RouteInfos,
        _ session: WebSocketSession
    ) {
        switch routeInfos.routeName {
        case "typhoon_espConnect": self.typhoonEspSession = session
        case "typhoon_espDisconnect": self.typhoonEspSession = nil
        case "remoteController_iphone1Connect": self.remoteController_iphone1Session = session
        case "remoteController_iphone1Disconnect": self.remoteController_iphone1Session = nil
        case "remoteController_iphone2Connect": self.remoteController_iphone2Session = session
        case "remoteController_iphone2Disconnect": self.remoteController_iphone2Session = nil
        case "remoteController_iphone3Connect": self.remoteController_iphone3Session = session
        case "remoteController_iphone3Disconnect": self.remoteController_iphone3Session = nil
            
        case "volcano_esp1Connect": self.volcanoEsp1Session = session
        case "volcano_esp1Disconnect": self.volcanoEsp1Session = nil
        case "volcano_esp2Connect": self.volcanoEsp2Session = session
        case "volcano_esp2Disconnect": self.volcanoEsp2Session = nil
            
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
        Timer
            .scheduledTimer(
                withTimeInterval: pingInterval,
                repeats: true
            ) { _ in
                self.sessionQueue.async {
                    for (route, sessionInfo) in self.pingableSessions {
                        // Envoyer d'abord le ping
                        sessionInfo.session.writeText("ping")
                        // print("Ping sent to \(route)")
                    
                        // Ensuite vérifier si le dernier pong a été reçu dans les temps
                        if Date()
                            .timeIntervalSince(sessionInfo.lastPingTime) > self.pingTimeout {
                            var updatedInfo = sessionInfo
                            updatedInfo.consecutiveFailures += 1
                            self.pingableSessions[route] = updatedInfo
                        
                            if updatedInfo.consecutiveFailures >= PingSessionInfo.maxFailures {
                                print(
                                    "Device \(route) failed to respond to ping \(PingSessionInfo.maxFailures) times. Disconnecting..."
                                )
                                sessionInfo.session.socket.close()
                                self.pingableSessions[route] = nil
                                let nameRoute = self.normalizeDeviceName(
                                    routeName: route
                                )
                                self.updateDeviceState(
                                    routeName: route,
                                    isConnected: false
                                )
                                self.updateDeviceState(
                                    routeName: nameRoute,
                                    isConnected: false
                                )
                            }
                        }
                    }
                }
            }
    }
    
    
    private func updateLastPingTime(
        for route: String,
        session: WebSocketSession
    ) {
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
            print(
                "Server has started (port = \(try server.port())). Try to connect now..."
            )
            self.audioPlayer.playMusic(name:"musique1")
        } catch {
            print("Server failed to start: \(error.localizedDescription)")
        }
    }
}


extension WebSockerServer {
    private var sessionMapping: [String: WebSocketSession?] {
        return [
            "typhoon_esp": typhoonEspSession,
            "remoteController_iphone1": remoteController_iphone1Session,
            "remoteController_iphone2": remoteController_iphone2Session,
            "remoteController_iphone3": remoteController_iphone3Session,
            "volcano_esp1": volcanoEsp1Session,
            "volcano_esp2": volcanoEsp2Session,
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
    private func handleIPhoneConnection(
        routeName: String,
        session: WebSocketSession
    ) {
        let deviceName = normalizeDeviceName(routeName: routeName)
        
        switch deviceName {
        case "remoteController_iphone1":
            self.remoteController_iphone1Session = session
            // Register message session
            if routeName.contains("Message") {
                registerMessageSession(routeName: routeName, session: session)
            }
            // Update device state
            updateDeviceState(routeName: deviceName, isConnected: true)
            
        case "remoteController_iphone2":
            self.remoteController_iphone2Session = session
            if routeName.contains("Message") {
                registerMessageSession(routeName: routeName, session: session)
            }
            updateDeviceState(routeName: deviceName, isConnected: true)
        case "remoteController_iphone3":
            self.remoteController_iphone3Session = session
            if routeName.contains("Message") {
                registerMessageSession(routeName: routeName, session: session)
            }
            updateDeviceState(routeName: deviceName, isConnected: true)
            
        default:
            break
        }
    }
    private func handleIPhoneDisconnection(
        routeName: String,
        session: WebSocketSession
    ) {
        let deviceName = normalizeDeviceName(routeName: routeName)
        sessionQueue.async {
            // Nettoyer les sessions de message
            if let messageSession = self.messageSessions[deviceName] {
                print("Cleaning up message session for \(deviceName)")
                self.messageSessions.removeValue(forKey: deviceName)
            }
                
            // Nettoyer les sessions de ping
            let pingRouteName = deviceName + "Ping"
            if let pingSession = self.pingableSessions[pingRouteName] {
                print("Cleaning up ping session for \(pingRouteName)")
                self.pingableSessions.removeValue(forKey: pingRouteName)
            }
                
            // Mettre à jour l'état du device
            self.updateDeviceState(routeName: deviceName, isConnected: false)
                
            // Nettoyer les sessions spécifiques selon le device
            switch deviceName {
            case "remoteController_iphone1":
                if self.remoteController_iphone1Session?.socket.hashValue == session.socket.hashValue {
                    self.remoteController_iphone1Session = nil
                }
            case "remoteController_iphone2":
                if self.remoteController_iphone2Session?.socket.hashValue == session.socket.hashValue {
                    self.remoteController_iphone2Session = nil
                }
            case "remoteController_iphone3":
                if self.remoteController_iphone3Session?.socket.hashValue == session.socket.hashValue {
                    self.remoteController_iphone3Session = nil
                }
            default:
                break
            }
        }
    }
    func updateDeviceState(routeName: String, isConnected: Bool) {
        let deviceName = normalizeDeviceName(routeName: routeName)
        // Don't process dashboard routes
        if deviceName.contains("Dashboard") {
            return
        }
        
        sessionQueue.async {
            if var state = self.deviceStates[deviceName] {
                state.isConnected = isConnected
                self.deviceStates[deviceName] = state
                print(
                    "Updated state for \(deviceName): isConnected = \(isConnected)"
                )
                
                // Notify dashboard of state change
                if let dashboardSession = self.remoteController_iphone1Session {
                    do {
                        let allDevices = self.deviceStates.mapValues { state in
                            [
                                "type": state.type,
                                "isConnected": state.isConnected
                            ]
                        }
                        let jsonData = try JSONSerialization.data(
                            withJSONObject: allDevices,
                            options: .prettyPrinted
                        )
                        if let jsonString = String(
                            data: jsonData,
                            encoding: .utf8
                        ) {
                            dashboardSession.writeText(jsonString)
                        }
                    } catch {
                        print("Error sending update to dashboard: \(error)")
                    }
                }
            }
        }
    }
    func handleSoundMessage(_ message: String) {
        switch message {
        case "":
            print("")
            
            
            // tornado
        case "rfid#tornado":
            self.audioPlayer.stopMusic("musique1")
            self.audioPlayer.playSound(name:"son1")
            self.audioPlayer
                .playMusic(name:"musique2")  // end on tornado_to_crystal#end
        case "tornado_to_crystal#end":
            self.audioPlayer.stopMusic("musique2")
        case "tornado_finished#true", "all_mics_active#true":
            self.audioPlayer.playSound(name:"son2")
            
            
            
            
            
            // maze
        case "rfid#maze":
            self.audioPlayer.playSound(name:"son1")
            self.audioPlayer
                .playMusic(name:"musique3")  // end on maze_to_crystal#end
            
    case "maze_to_crystal#end":
        self.audioPlayer.stopMusic("musique3")
        case "btn2#true":
            self.audioPlayer.playSound(name:"son5")
        case "btn3#true":
            self.audioPlayer.playSound(name:"son5")
        case "btn1#end":
            self.audioPlayer.playSound(name:"son2")
            self.audioPlayer.playSound(name:"son6", loop: true) // end on crystal_maze#end
        case "crystal_maze#end":
            self.audioPlayer.stopSound(name:"son6")
        
            
            
            // typhoon
        case "rfid#typhoon":
            self.audioPlayer.playSound(name:"son1")
            self.audioPlayer
                .playMusic(name:"musique4")  // end on typhoon_to_crystal#end
            
    case "typhoon_to_crystal#end":
        self.audioPlayer.stopMusic("musique4")
        case "typhoon_finished#true", "all_relays#completed":
            self.audioPlayer.playSound(name:"son2")
            
            
            
            
            
            
            
            // volcano
        case "rfid#volcano":
            self.audioPlayer.playSound(name:"son1")
            self.audioPlayer.playMusic(name:"musique5")
            
    case "volcano_to_crystal#end":
        self.audioPlayer.stopMusic("musique5")
        case "volcano_finished#true", "all_rifds#completed":
            self.audioPlayer.playSound(name:"son2")
            self.audioPlayer.playSound(name:"son7")
            
            // crystal
        case "crystal_started#true":
            self.audioPlayer.playSound(name:"son1")
        case "tornado_to_crystal#end", "crystal#tornado":
            self.audioPlayer.playSound(name:"son3")
        case "maze_to_crystal#end", "crystal#maze":
            self.audioPlayer.playSound(name:"son3")
        case "typhoon_to_crystal#end", "crystal#typhoon":
            self.audioPlayer.playSound(name:"son3")
        case "volcano_to_crystal#end", "crystal#volcano":
            self.audioPlayer.playSound(name:"son3")
        case "crystal_finish#start":
            self.audioPlayer.playSound(name:"son4", delay: 6) // add delay
            self.audioPlayer.playMusic(name:"musique6", delay: 8) // add delay
            
            
            
//            Sons
//            son1 : Son court de “déblocage” (lorsque les amulettes sont posées sur les ateliers ou pour la pose des 4 amulettes au début).
//            son2 : Son de validation (joué à la fin de l’expérience pendant le clignotement des LEDs).
//            son3 : Son “méchant” (l’esprit reprend la main lorsque les LEDs retournent au crystal).
//            son4 : Son de joie (les éléments reprennent la main sur le crystal après le feu, avec délai pour ne pas parer l’éruption).
//            son5 : Son d’orage (lors de la validation d’une étape du bouton sur l’atelier d’électricité).
//            son6 : Son beaucoup d’éclair (joué avec les LEDs du labyrinthe imitant des éclairs).
//            son7 : Son grondement volcan (enchaîné après l’atelier du feu).
//            Musiques
//            musique1 : Ambiance crystal (déclenchée dès le début de l’expérience).
//            musique2 : Ambiance du vent (jouée après la pose de l’amulette sur l’atelier du vent et jusqu’à la fin de l’expérience).
//            musique3 : Ambiance de l’électricité (jouée après la pose de l’amulette sur l’atelier de l’électricité et jusqu’à la fin de l’expérience).
//            musique4 : Ambiance de l’eau (jouée après la pose de l’amulette sur l’atelier de l’eau et jusqu’à la fin de l’expérience).
//            musique5 : Ambiance du feu (jouée après la pose de l’amulette sur l’atelier du feu et jusqu’à la fin de l’expérience).
//            musique6 : Musique de victoire (jouée à la fin de l’expérience après la joie des éléments).

            
        default:
            print("no sound")
        }
    }
    func sendMessage(
        from: String,
        to: [String],
        component: String,
        data: String
    ) {
        let message = "\(component)#\(data)"
        print("Sending message: \(message) to routes: \(to)")
        let ledDevices = [
            "volcano_espLed",
            "typhoon_espLed",
            "maze_espLed",
            "tornado_espLed",
            "crystal_espLed"
        ]
        
        
        // Vérifie si 'to' contient 'typhoon_iphone' et ajoute 'typhoon_iphone1' si nécessaire
        var updatedTo = to
        
        if to.contains("ambianceManager") {
            
            handleSoundMessage(message)
            
            
            
            updatedTo.append(contentsOf: ledDevices)
            // Retirer ambianceManager de la liste pour éviter le double envoi
            updatedTo.removeAll { $0 == "ambianceManager" }
        }
        if to.contains("typhoon_iphone") {
            updatedTo.append("typhoon_iphone1")
        }
        updatedTo = Array(Set(updatedTo))
        print("Liste finale des destinataires: \(updatedTo)")
        
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
            print(
                "Invalid message format (wrong number of components): \(message)"
            )
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
