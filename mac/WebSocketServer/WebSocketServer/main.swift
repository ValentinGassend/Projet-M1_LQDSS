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

// Liste des routes avec leur logique associée
let routes: [RouteInfos] = [
    RouteInfos(routeName: "remoteControllerConnect", textCode: { session, receivedText in
        serverWS.remoteControllerSession = session
        print("Remote controller connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "remoteControllerMessage", textCode: { session, receivedText in
        print(receivedText)
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "remoteControllerDashboard", textCode: { session, receivedText in
        // Envoie l'état actuel des appareils connectés au client
        serverWS.remoteControllerSession = session
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
    
    RouteInfos(routeName: "rpiConnect", textCode: { session, receivedText in
        serverWS.rpiSession = session
        print("RPI connecté : \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "rvrTornadoConnect", textCode: { session, receivedText in
        serverWS.rvrTornadoSession = session
        print("RVR Tornado connecté")
        serverWS.rvrTornadoSession?.writeText("start 100")
        serverWS.rvrTornadoSession?.writeText("stop")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "iPhoneConnect", textCode: { session, receivedText in
        serverWS.iPhoneSession = session
        print("iPhone connecté")
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
    
    RouteInfos(routeName: "rpiLaserConnect", textCode: { session, receivedText in
        serverWS.laserSession = session
        print("Laser connecté")
        serverWS.laserSession?.writeText("python3 laser.py")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "rpiLaserMessage", textCode: { session, receivedText in
        print(receivedText)
        if receivedText == "True" {
            serverWS.laserSession?.writeText("stop")
            serverWS.rpiSession?.writeText("start 100")
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

// Configuration des routes sur le serveur
for route in routes {
    serverWS.setupWithRoutesInfos(routeInfos: route)
}

// Démarrage du serveur WebSocket
serverWS.start()
RunLoop.main.run()

