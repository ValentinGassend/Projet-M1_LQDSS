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
var routes: [RouteInfos] = [
    RouteInfos(routeName: "remoteControllerConnect", textCode: { session, receivedText in
        serverWS.remoteControllerSession = session
        print("Remote controller connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.remoteControllerSession = nil
        print("Remote controller déconnecté")
    }),
    
    RouteInfos(routeName: "remoteControllerMessage", textCode: { session, receivedText in
        print(receivedText)
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "remoteControllerDashboard", textCode: { session, receivedText in
        serverWS.remoteControllerSession = session
        if receivedText == "getDevices" {
            // Créer un dictionnaire de toutes les sessions disponibles
            let allDevices = serverWS.deviceStates.mapValues { state in
                ["type": state.type, "isConnected": state.isConnected]
            }
            // Convertir en JSON et envoyer
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: allDevices, options: .prettyPrinted)
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
    },disconnectedCode: { session in
        serverWS.rpiSession = nil
        print("rpiSession déconnecté")
    }),
    
    RouteInfos(routeName: "rvrTornadoConnect", textCode: { session, receivedText in
        serverWS.rvrTornadoSession = session
        print("RVR Tornado connecté")
        serverWS.rvrTornadoSession?.writeText("start 100")
        serverWS.rvrTornadoSession?.writeText("stop")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.rvrTornadoSession = nil
        print("rvrTornado déconnecté")
    }),
    
    RouteInfos(routeName: "iPhoneConnect", textCode: { session, receivedText in
        serverWS.iPhoneSession = session
        print("iPhone connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.iPhoneSession = nil
        print("iPhone déconnecté")
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
    },disconnectedCode: { session in
        serverWS.laserSession = nil
        print("Rpi lasser déconnecté")
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
// Nouvelles routes générées
// Pour chaque route, trois fonctions seront ajoutées : Connect, Message et Ping

let newRoutes: [RouteInfos] = [
    // Routes pour typhoon
    RouteInfos(routeName: "typhoon_espConnect", textCode: { session, receivedText in
        serverWS.typhoonEspSession = session
        print("typhoon_esp connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.typhoonEspSession = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "typhoon_espMessage", textCode: { session, receivedText in
        print("typhoon_espMessage message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }, parsedMessageCode: { session, parsedMessage in
        print(parsedMessage.toString())
    }),
    RouteInfos(routeName: "typhoon_espPing", textCode: { session, receivedText in
        
        //        print("typhoon_esp // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "typhoon_iphone1Connect", textCode: { session, receivedText in
            print("typhoon_iphone1 connecté")
            serverWS.typhoonIphone1Session = session
        }, dataCode: { session, receivedData in
            print(receivedData)
        },disconnectedCode: { session in
            serverWS.typhoonIphone1Session = nil
            print("Typhoon Iphone1 déconnecté")
        }),
        RouteInfos(routeName: "typhoon_iphone1Message", textCode: { session, receivedText in
            print("typhoon_iphone1 message: \(receivedText)")
        }, dataCode: { session, receivedData in
            print(receivedData)
        }),
        RouteInfos(routeName: "typhoon_iphone1Ping", textCode: { session, receivedText in
            //print("typhoon_iphone1 // ping reçu: \(receivedText)")
        }, dataCode: { session, receivedData in
            print(receivedData)
        }),
    RouteInfos(routeName: "typhoon_iphoneConnect", textCode: { session, receivedText in
        print("typhoon_iphone connecté")
        serverWS.typhoonIphoneSession = session
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.typhoonIphoneSession = nil
        print("Typhoon Iphone déconnecté")
    }),
    RouteInfos(routeName: "typhoon_iphoneMessage", textCode: { session, receivedText in
        print("typhoon_iphone message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "typhoon_iphonePing", textCode: { session, receivedText in
        
        //        print("typhoon_iphone // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    // Routes pour volcano
    RouteInfos(routeName: "volcano_esp1Connect", textCode: { session, receivedText in
        serverWS.volcanoEsp1Session = session
        
        print("volcano_esp1 connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.volcanoEsp1Session = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "volcano_esp1Message", textCode: { session, receivedText in
        print("volcano_esp1 message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "volcano_esp1Ping", textCode: { session, receivedText in
        
        print("volcano_esp1 // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "volcano_esp2Connect", textCode: { session, receivedText in
        serverWS.volcanoEsp2Session = session
        
        print("volcano_esp2 connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.volcanoEsp2Session = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "volcano_esp2Message", textCode: { session, receivedText in
        print("volcano_esp2 message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "volcano_esp2Ping", textCode: { session, receivedText in
        
        print("volcano_esp2 // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "volcano_rpiConnect", textCode: { session, receivedText in
        serverWS.volcanoRpiSession = session
        
        print("volcano_rpi connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.volcanoRpiSession = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "volcano_rpiMessage", textCode: { session, receivedText in
        print("volcano_rpi message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "volcano_rpiPing", textCode: { session, receivedText in
        
        print("volcano_rpi // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    // Routes pour maze
    RouteInfos(routeName: "maze_espConnect", textCode: { session, receivedText in
        serverWS.mazeEspSession = session
        
        print("maze_esp connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.mazeEspSession = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "maze_espMessage", textCode: { session, receivedText in
        print("maze_esp message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "maze_espPing", textCode: { session, receivedText in
        
        print("maze_esp // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "maze_iphoneConnect", textCode: { session, receivedText in
        print("maze_iphone connecté")
        serverWS.mazeIphoneSession = session
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.mazeIphoneSession = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "maze_iphoneMessage", textCode: { session, receivedText in
        print("maze_iphone message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "maze_iphonePing", textCode: { session, receivedText in
        
        print("maze_iphone // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    // Routes pour tornado
    RouteInfos(routeName: "tornado_espConnect", textCode: { session, receivedText in
        serverWS.tornadoEspSession = session
        
        print("tornado_esp connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.tornadoEspSession = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "tornado_espMessage", textCode: { session, receivedText in
        print("tornado_esp message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "tornado_espPing", textCode: { session, receivedText in
        
        print("tornado_esp // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "tornado_rpiConnect", textCode: { session, receivedText in
        print("tornado_rpi connecté")
        serverWS.tornadoRpiSession = session
        // 100, 150, 200, 250
        //        serverWS.tornadoRpiSession?.writeText("start 100")
        // attend 5s et envoie stop
        //        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
        //            print("send stop")
        //            serverWS.tornadoRpiSession?.writeText("stop")
        //        }
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.tornadoRpiSession?.writeText("stop")
        serverWS.tornadoRpiSession = nil
    }),
    RouteInfos(routeName: "tornado_rpiMessage", textCode: { session, receivedText in
        print("tornado_rpi message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "tornado_rpiPing", textCode: { session, receivedText in
        
        print("tornado_rpi // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    // Routes pour crystal
    RouteInfos(routeName: "crystal_esp1Connect", textCode: { session, receivedText in
        serverWS.crystalEsp1Session = session
        
        print("crystal_esp1 connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.crystalEsp1Session = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "crystal_esp1Message", textCode: { session, receivedText in
        print("crystal_esp1 message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "crystal_esp1Ping", textCode: { session, receivedText in
        
        print("crystal_esp1 // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    
    RouteInfos(routeName: "crystal_esp2Connect", textCode: { session, receivedText in
        serverWS.crystalEsp2Session = session
        
        print("crystal_esp2 connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.crystalEsp2Session = nil
        print("Remote controller déconnecté")
    }),
    RouteInfos(routeName: "crystal_esp2Message", textCode: { session, receivedText in
        print("crystal_esp2 message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "crystal_esp2Ping", textCode: { session, receivedText in
        
        print("crystal_esp2 // ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    })
]


// add new routes in routes
routes.append(contentsOf: newRoutes)

// Configuration des routes sur le serveur
for route in routes {
    serverWS.setupWithRoutesInfos(routeInfos: route)
}

// Démarrage du serveur WebSocket
serverWS.start()
RunLoop.main.run()

