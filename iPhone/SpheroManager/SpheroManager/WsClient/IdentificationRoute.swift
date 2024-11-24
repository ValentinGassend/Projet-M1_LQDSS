//
//  IdentificationRoute.swift
//  SpheroManager
//
//  Created by Valentin Gassant on 23/11/2024.
//

enum IdentificationRoute: String, CaseIterable {
    case spheroTyphoonConnect = "spheroTyphoon"
    case iPhoneConnect = "iPhone"
    case rpiConnect = "rpi"
    
    var welcomeMessage: String {
        return "Hello from \(self.rawValue)"
    }
}

