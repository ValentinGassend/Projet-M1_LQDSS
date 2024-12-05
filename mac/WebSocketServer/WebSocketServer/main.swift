//
//  main.swift
//  WebSocketServer
//
//  Created by Al on 22/10/2024.
//

import Foundation
import Combine
import Swifter

// Initialisation du serveur WebSocket
var serverWS = WebSockerServer()
var cmd = TerminalCommandExecutor()
var cancellable: AnyCancellable? = nil
var pingTimer: Timer?

// Liste des routes avec leur logique associée
let otherRoutes: [RouteInfos] = [
    RouteInfos(routeName: "remoteControllerDashboard", textCode: { session, receivedText in
        // Envoie l'état actuel des appareils connectés au client
        if receivedText == "getDevices" {
            // Mise à jour dynamique des états des appareils
            serverWS.deviceStates["rpiLaser"]?.isConnected = (serverWS.laserSession != nil)
            serverWS.deviceStates["iPhone"]?.isConnected = (serverWS.iPhoneSession != nil)
            serverWS.deviceStates["remoteController"]?.isConnected = (serverWS.remoteControllerSession != nil)
            serverWS.deviceStates["rvrTornado"]?.isConnected = (serverWS.rvrTornadoSession != nil)
            
            // Générer le JSON pour le retour
            let devicesJSON = serverWS.deviceStates.map { key, value in
                [
                    "device": key,
                    "macAddress": value.macAddress,
                    "isConnected": value.isConnected
                ]
            }
            
            // Convertir en JSON et envoyer
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: devicesJSON, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    session.writeText(jsonString)
                    print("Envoyé à la requête 'getDevices': \(jsonString)")
                }
            } catch {
                print("Erreur lors de la génération du JSON: \(error)")
            }
        }
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "spheroIdentificationConnect", textCode: { session, receivedText in
        print(receivedText)
        if let iPhoneSession = serverWS.iPhoneSession {
            if receivedText == "SB-8630" {
                serverWS.spheroTyphoonId = "SB-8630"
                serverWS.spheroTyphoonIsConnected = true
                print("spheroTyphoonId connecté")
                iPhoneSession.writeText("\(serverWS.spheroTyphoonId) [consigne]")
            } else if receivedText == "SB-313C" {
                serverWS.spheroStickId = "SB-313C"
                serverWS.spheroStickIsConnected = true
                print("spheroStickId connecté")
                iPhoneSession.writeText("\(serverWS.spheroStickId) [consigne]")
            }
        } else {
            print("iPhoneSession non connecté")
        }
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "moveRobot", textCode: { session, receivedText in
        if let rpiSess = serverWS.rpiSession {
            print("Mouvement du robot : \(receivedText)")
            rpiSess.writeText("python3 \(receivedText).py")
        } else {
            print("RPI non connecté")
        }
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "say", textCode: { session, receivedText in
        cmd.say(textToSay: receivedText)
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "imagePrompting", textCode: { session, receivedText in
        if let jsonData = receivedText.data(using: .utf8),
           let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
            let dataImageArray = imagePrompting.toDataArray()
            let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
            if tmpImagesPath.count == 1 {
                cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
            } else {
                print("You are sending too many images.")
            }
        }
    }, dataCode: { session, receivedData in
    })
]
func createConnectRoute(routeName: String,
                        sessionProvider: @escaping () -> WebSocketSession?,
                        sessionSetter: @escaping (WebSocketSession?) -> Void) -> RouteInfos {
    return RouteInfos(routeName: routeName, textCode: { session, receivedText in
        // Lorsque la session est connectée, on l'associe à l'appareil
        sessionSetter(session)
        print("\(routeName) connecté : \(receivedText)")
    }, dataCode: { session, receivedData in
        print("Données reçues sur \(routeName) : \(receivedData)")
    }, disconnectedCode: { session in
        // Si la session se déconnecte, on la désassocie
        sessionSetter(nil)
        print("\(routeName) déconnecté")
    })
}

func createPingRoute(routeName: String,
                     sessionProvider: @escaping () -> WebSocketSession?,
                     sessionSetter: @escaping (WebSocketSession?) -> Void,
                     expectedResponse: String) -> RouteInfos {
    var pingTimer: Timer?
    return RouteInfos(routeName: routeName, textCode: { session, receivedText in
        if let currentSession = sessionProvider() {
            // Démarre ou redémarre le Timer pour envoyer des pings toutes les secondes
            if pingTimer == nil {
                pingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    currentSession.writeText("ping")
                    print("Ping envoyé pour la route \(routeName)")
                    
                    // Gère un timeout pour la réponse
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if sessionProvider() != nil {
                            print("Pas de réponse reçue pour \(routeName), session déclarée comme nil")
                            sessionSetter(nil)
                            pingTimer?.invalidate()
                            pingTimer = nil
                        }
                    }
                }
            }
            
            // Vérification de la réponse attendue
            if receivedText == expectedResponse {
                print("Réponse attendue reçue pour \(routeName): \(receivedText)")
                // La réponse est reçue, la session reste active
            }
        } else {
            print("Session non connectée pour \(routeName)")
        }
    }, dataCode: { session, receivedData in
        print(receivedData)
    }, disconnectedCode: { session in
        print("\(routeName) déconnecté")
        sessionSetter(nil)
        pingTimer?.invalidate()
        pingTimer = nil
    })
}


func createMessageRoute(routeName: String,
                        sessionProvider: @escaping () -> WebSocketSession?,
                        sessionSetter: @escaping (WebSocketSession?) -> Void,
                        textHandler: @escaping (WebSocketSession, String) -> Void,
                        dataHandler: @escaping (WebSocketSession, Data) -> Void) -> RouteInfos {
    return RouteInfos(routeName: routeName, textCode: { session, receivedText in
        if let currentSession = sessionProvider() {
            // Action personnalisée à réaliser lorsque du texte est reçu
            textHandler(currentSession, receivedText)
            
            print("Message texte reçu sur \(routeName): \(receivedText)")
        }
    }, dataCode: { session, receivedData in
        if let currentSession = sessionProvider() {
            // Action personnalisée à réaliser lorsque des données sont reçues
            dataHandler(currentSession, receivedData)
            print("Données reçues sur \(routeName): \(receivedData)")
        }
    })
}


let connectionRoutes: [RouteInfos] = [
    createConnectRoute(
        routeName: "remoteControllerConnect",
        sessionProvider: { serverWS.remoteControllerSession },
        sessionSetter: { serverWS.remoteControllerSession = $0 }
    
    ),
    createConnectRoute(
        routeName: "rpiConnect",
        sessionProvider: { serverWS.rpiSession },
        sessionSetter: { serverWS.rpiSession = $0 }
    ),
    createConnectRoute(
        routeName: "rvrTornadoConnect",
        sessionProvider: { serverWS.rvrTornadoSession },
        sessionSetter: { serverWS.rvrTornadoSession = $0 }
    ),
    createConnectRoute(
        routeName: "rpiLaserConnect",
        sessionProvider: { serverWS.laserSession },
        sessionSetter: { serverWS.laserSession = $0 }
    )
]


let messageRoutes: [RouteInfos] = [
    createMessageRoute(
        routeName: "remoteControllerMessage",
        sessionProvider: { serverWS.remoteControllerSession },
        sessionSetter: { serverWS.remoteControllerSession = $0 },
        textHandler: { session, receivedText in
            // Traitement du texte reçu
            print(receivedText)
            if let remoteControllerSession = serverWS.remoteControllerSession {
                if receivedText == "remoteControllerMessage" {
                    serverWS.remoteControllerSession?.writeText("test")
                    print("message envoyé \("test")")

//                    print("Message texte reçu : \(receivedText)")
                }
                
            }
        },
        dataHandler: { session, receivedData in
            // Traitement des données reçues
            print("Données reçues : \(receivedData)")
        }
    ),
    createMessageRoute(
        routeName: "rpiLaserMessage",
        sessionProvider: { serverWS.laserSession },
        sessionSetter: { serverWS.laserSession = $0 },
        textHandler: { session, receivedText in
            // Exemple de logique pour traiter le texte reçu
            print("Texte reçu sur rpiLaserMessage: \(receivedText)")
            if receivedText == "True" {
                serverWS.laserSession?.writeText("stop")
                serverWS.rpiSession?.writeText("start 100")
            }
        },
        dataHandler: { session, receivedData in
            // Exemple de logique pour traiter les données reçues
            print("Données reçues sur rpiLaserMessage: \(receivedData)")
        }
    )
]

let pingRoutes: [RouteInfos] = [
    createPingRoute(
        routeName: "remoteControllerPing",
        sessionProvider: { serverWS.remoteControllerSession },
        sessionSetter: { serverWS.remoteControllerSession = $0 },
        expectedResponse: "remoteController"
    ),
    createPingRoute(
        routeName: "rpiPing",
        sessionProvider: { serverWS.rpiSession },
        sessionSetter: { serverWS.rpiSession = $0 },
        expectedResponse: "rpi"
    ),
    createPingRoute(
        routeName: "rvrTornadoPing",
        sessionProvider: { serverWS.rvrTornadoSession },
        sessionSetter: { serverWS.rvrTornadoSession = $0 },
        expectedResponse: "rvrTornado"
    ),
    createPingRoute(
        routeName: "iPhonePing",
        sessionProvider: { serverWS.iPhoneSession },
        sessionSetter: { serverWS.iPhoneSession = $0 },
        expectedResponse: "iPhone"
    ),
    createPingRoute(
        routeName: "rpiLaserPing",
        sessionProvider: { serverWS.laserSession },
        sessionSetter: { serverWS.laserSession = $0 },
        expectedResponse: "rpiLaser"
    )
]

let allRoutes = connectionRoutes + pingRoutes + messageRoutes + otherRoutes

for route in allRoutes {
    serverWS.setupWithRoutesInfos(routeInfos: route)
}

// Démarrage du serveur WebSocket
serverWS.start()
RunLoop.main.run()

