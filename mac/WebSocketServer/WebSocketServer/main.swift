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
    RouteInfos(routeName: "remoteController_iphone1Connect", textCode: { session, receivedText in
            print("typhoon_iphone1 connecté")
        serverWS.remoteController_iphone1Session = session
        }, dataCode: { session, receivedData in
            print(receivedData)
        },disconnectedCode: { session in
            serverWS.remoteController_iphone1Session = nil
            print("Typhoon Iphone1 déconnecté")
        }),
        RouteInfos(routeName: "remoteController_iphone1Message", textCode: { session, receivedText in
            print("typhoon_iphone1 message: \(receivedText)")
        }, dataCode: { session, receivedData in
            print(receivedData)
        }),
        RouteInfos(routeName: "remoteController_iphone1Ping", textCode: { session, receivedText in
            //print("typhoon_iphone1 // ping reçu: \(receivedText)")
        }, dataCode: { session, receivedData in
            print(receivedData)
        }),
    // Add this to the existing routes in main.swift after the ambianceManager routes
    RouteInfos(routeName: "remoteController_iphone1Dashboard", textCode: { session, receivedText in
        
//        print("message received on remoteController_iphone1Dashboard: \(receivedText)")
        if receivedText == "getDevices" {
            let audioPlayer = AudioPlayer.shared
            audioPlayer.playSound()
            let server = WebSockerServer.instance
            // Create a dictionary of all available sessions and their states
            let allDevices = server.deviceStates.mapValues { state in
                [
                    "type": state.type,
                    "isConnected": state.isConnected
                ]
            }
            
            // Convert to JSON and send
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: allDevices, options: .prettyPrinted)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    session.writeText(jsonString)
//                    print("Sent device states to dashboard: \(jsonString)")
                }
            } catch {
//                print("Error generating JSON: \(error)")
            }
        }
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "remoteController_iphone2Connect", textCode: { session, receivedText in
        print("remoteController iphone 2 connecté")
        serverWS.remoteController_iphone2Session = session
    }, dataCode: { session, receivedData in
        print(receivedData)
    },disconnectedCode: { session in
        serverWS.remoteController_iphone2Session = nil
        print("remoteController iphone 2 déconnecté")
    }),
    RouteInfos(routeName: "remoteController_iphone2Message", textCode: { session, receivedText in
        print("remoteController iphone 2 message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "remoteController_iphone2Ping", textCode: { session, receivedText in
        
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
    }),
    RouteInfos(routeName: "ambianceManagerConnect", textCode: { session, receivedText in
            serverWS.ambianceManagerSession = session
            print("Ambiance Manager connecté")
        }, dataCode: { session, receivedData in
            print(receivedData)
        }, disconnectedCode: { session in
            serverWS.ambianceManagerSession = nil
            print("Ambiance Manager déconnecté")
        }),
        RouteInfos(routeName: "ambianceManagerMessage", textCode: { session, receivedText in
            print("Message Ambiance Manager: \(receivedText)")
            // Ajouter logique spécifique pour traiter les messages
        }, dataCode: { session, receivedData in
            print(receivedData)
        }),
        RouteInfos(routeName: "ambianceManagerPing", textCode: { session, receivedText in
            print("Ping Ambiance Manager: \(receivedText)")
        }, dataCode: { session, receivedData in
            print(receivedData)
        })
]
let ledRoutes: [RouteInfos] = [
    // Routes pour volcano LED
    RouteInfos(routeName: "volcano_espLedConnect", textCode: { session, receivedText in
        serverWS.volcanoEspLedSession = session
        print("volcano_espLed connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }, disconnectedCode: { session in
        serverWS.volcanoEspLedSession = nil
        print("volcano_espLed déconnecté")
    }),
    RouteInfos(routeName: "volcano_espLedMessage", textCode: { session, receivedText in
        print("volcano_espLed message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "volcano_espLedPing", textCode: { session, receivedText in
        print("volcano_espLed ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),

    // Routes pour typhoon LED
    RouteInfos(routeName: "typhoon_espLedConnect", textCode: { session, receivedText in
        serverWS.typhoonEspLedSession = session
        print("typhoon_espLed connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }, disconnectedCode: { session in
        serverWS.typhoonEspLedSession = nil
        print("typhoon_espLed déconnecté")
    }),
    RouteInfos(routeName: "typhoon_espLedMessage", textCode: { session, receivedText in
        print("typhoon_espLed message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "typhoon_espLedPing", textCode: { session, receivedText in
        print("typhoon_espLed ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),

    // Routes pour maze LED
    RouteInfos(routeName: "maze_espLedConnect", textCode: { session, receivedText in
        serverWS.mazeEspLedSession = session
        print("maze_espLed connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }, disconnectedCode: { session in
        serverWS.mazeEspLedSession = nil
        print("maze_espLed déconnecté")
    }),
    RouteInfos(routeName: "maze_espLedMessage", textCode: { session, receivedText in
        print("maze_espLed message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "maze_espLedPing", textCode: { session, receivedText in
        print("maze_espLed ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),

    // Routes pour tornado LED
    RouteInfos(routeName: "tornado_espLedConnect", textCode: { session, receivedText in
        serverWS.tornadoEspLedSession = session
        print("tornado_espLed connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }, disconnectedCode: { session in
        serverWS.tornadoEspLedSession = nil
        print("tornado_espLed déconnecté")
    }),
    RouteInfos(routeName: "tornado_espLedMessage", textCode: { session, receivedText in
        print("tornado_espLed message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "tornado_espLedPing", textCode: { session, receivedText in
        print("tornado_espLed ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),

    // Routes pour crystal LED
    RouteInfos(routeName: "crystal_espLedConnect", textCode: { session, receivedText in
        serverWS.crystalEspLedSession = session
        print("crystal_espLed connecté")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }, disconnectedCode: { session in
        serverWS.crystalEspLedSession = nil
        print("crystal_espLed déconnecté")
    }),
    RouteInfos(routeName: "crystal_espLedMessage", textCode: { session, receivedText in
        print("crystal_espLed message: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    }),
    RouteInfos(routeName: "crystal_espLedPing", textCode: { session, receivedText in
        print("crystal_espLed ping reçu: \(receivedText)")
    }, dataCode: { session, receivedData in
        print(receivedData)
    })
]

// Ajouter les nouvelles routes LED aux routes existantes
routes.append(contentsOf: ledRoutes)

// add new routes in routes
routes.append(contentsOf: newRoutes)

// Configuration des routes sur le serveur
for route in routes {
    serverWS.setupWithRoutesInfos(routeInfos: route)
}

// Démarrage du serveur WebSocket
serverWS.start()
RunLoop.main.run()

