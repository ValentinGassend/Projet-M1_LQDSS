//
//  WebSocketServer.swift
//  WebSocketServer
//
//  Created by digital on 22/10/2024.
//

import Swifter
import SwiftUI

struct RouteInfos {
    var routeName: String
    var textCode: (WebSocketSession, String) -> ()
    var dataCode: (WebSocketSession, Data) -> ()
}

class WebSockerServer {
    
    static let instance = WebSockerServer()
    let server = HttpServer()
    
    var rpiSession: WebSocketSession?
    var iPhoneSession: WebSocketSession?
    var spheroTyphoonId: String?
    var spheroTyphoonIsConnected: Bool = false
    var spheroStickId: String?
    var spheroStickIsConnected: Bool = false
    
    func setupWithRoutesInfos(routeInfos: RouteInfos) {
        server["/" + routeInfos.routeName] = websocket(
            text: { session, text in
                print("Text received: \(text) from route: /\(routeInfos.routeName) ")
                routeInfos.textCode(session, text)
            },
            binary: { session, binary in
                let data = Data(binary)
                print("Data received: \(data) (original: \(binary)) from route: /\(routeInfos.routeName)")
                routeInfos.dataCode(session, Data(binary))
            },
            connected: { session in
                print("Client connected to route: /\(routeInfos.routeName)")
            },
            disconnected: { session in
                print("Client disconnected from route: /\(routeInfos.routeName)")
            }
        )
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
