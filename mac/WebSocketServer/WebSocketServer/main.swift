//
//  main.swift
//  WebSocketServer
//
//  Created by Al on 22/10/2024.
//

import Foundation
import Combine
import Swifter

var serverWS = WebSockerServer()
var cmd = TerminalCommandExecutor()
var cancellable:AnyCancellable? = nil


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "rpiConnect", textCode: { session, receivedText in
    serverWS.rpiSession = session
    print("RPI Connecté")
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "iPhoneConnect", textCode: { session, receivedText in
    serverWS.iPhoneSession = session
    print("IPhone Connecté")
}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "spheroIdentificationConnect", textCode: { session, receivedText in
    print(receivedText)
    if let iPhoneSession = serverWS.iPhoneSession {
        if (receivedText == "SB-8630") {
            serverWS.spheroTyphoonId = "SB-8630"
            print("spheroTyphoonId connecté")
            serverWS.spheroTyphoonIsConnected = true
            
            if serverWS.spheroTyphoonIsConnected {
                iPhoneSession.writeText("\(serverWS.spheroTyphoonId) [consigne]")
            }
        }
        else if (receivedText == "SB-313C") {
            serverWS.spheroStickId = "SB-313C"
            print("spheroStickId connecté")
            serverWS.spheroStickIsConnected = true

            if serverWS.spheroTyphoonIsConnected {
                iPhoneSession.writeText("\(serverWS.spheroStickId) [consigne]")
            }
        }
    }
    else {
        print("iPhoneSession Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "spheroTyphoon", textCode: { session, receivedText in
    print(receivedText)
    if let iPhoneSession = serverWS.iPhoneSession {
        print("iPhoneSession connecté")
        iPhoneSession.writeText(" I have received: \(receivedText)")
    }
    else {
        print("iPhoneSession Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))



serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "testRobot", textCode: { session, receivedText in
    if let rpiSess = serverWS.rpiSession {
        rpiSess.writeText("python3 drive.py")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))


serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "spheroTyphoonHello", textCode: { session, receivedText in
    
    print("Message received: \(receivedText)")
    if let spheroTyphoonSession = serverWS.rpiSession {
        spheroTyphoonSession.writeText("python3 \(receivedText).py")
        print("Mouvement du robot fini")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "moveRobot", textCode: { session, receivedText in
    if let rpiSess = serverWS.rpiSession {
        print("Mouvement du robot \(receivedText)")
        rpiSess.writeText("python3 \(receivedText).py")
        print("Mouvement du robot fini")
    } else {
        print("RPI Non connecté")
    }
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "say", textCode: { session, receivedText in
    cmd.say(textToSay: receivedText)
}, dataCode: { session, receivedData in
    print(receivedData)
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "imagePrompting", textCode: { session, receivedText in
    if let jsonData = receivedText.data(using: .utf8),
       let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
        let dataImageArray = imagePrompting.toDataArray()
        let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
        
        if (tmpImagesPath.count == 1) {
            cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
        } else {
            print("You are sending too much images.")
        }
    }
}, dataCode: { session, receivedData in
}))

serverWS.setupWithRoutesInfos(routeInfos: RouteInfos(routeName: "imagePromptingToText", textCode: { session, receivedText in
    
    cancellable?.cancel()
    cancellable = cmd.$output.sink { newValue in
        session.writeText(newValue)
    }
    
    if let jsonData = receivedText.data(using: .utf8),
       let imagePrompting = try? JSONDecoder().decode(ImagePrompting.self, from: jsonData) {
        let dataImageArray = imagePrompting.toDataArray()
        let tmpImagesPath = TmpFileManager.instance.saveImageDataArray(dataImageArray: dataImageArray)
        
        if (tmpImagesPath.count == 1) {
            cmd.imagePrompting(imagePath: tmpImagesPath[0], prompt: imagePrompting.prompt)
        } else {
            print("You are sending too much images.")
        }
    }
}, dataCode: { session, receivedData in
}))

serverWS.start()

RunLoop.main.run()

