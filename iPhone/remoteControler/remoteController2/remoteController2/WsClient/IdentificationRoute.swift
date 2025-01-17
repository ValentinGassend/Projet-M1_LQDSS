//
//  IdentificationRoute.swift
//  SpheroManager
//
//  Created by Valentin Gassant on 23/11/2024.
//

enum IdentificationRoute: String, CaseIterable {
    case spheroIdentificationConnect = "spheroIdentification"
    case typhoonIphoneConnect = "typhoon_iphone"
    case mazeIphoneConnect = "maze_iphone"
    case remoteController_iphone1Connect = "remoteController_iphone1"
    case rpiConnect = "rpi"
    
    var welcomeMessage: String {
        return "Hello from \(self.rawValue)"
    }
}

