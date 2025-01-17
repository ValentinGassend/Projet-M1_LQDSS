//
//  SpheroPresetManager.swift
//  remoteController2
//
//  Created by Valentin Gassant on 17/01/2025.
//

import Foundation

class SpheroPresetManager {
    static let shared = SpheroPresetManager()
    
    private let lightningPreset = [
        [false, false, false, false, false, true, true, true],
        [false, false, false, false, true,  true,  true,  false],
        [false, false, false, true,  true,  true,  false, false],
        [false, false, true,  true,  true,  false, false, false],
        [false, true,  true,  true,  true,  true,  false, false],
        [false, false, false, true,  true,  false, false, false],
        [false, false, false,  true,  false, false, false, false],
        [false, false,  true, false, false, false, false, false],
    ]
    
    func sendLightningPreset(to sphero: BoltToy) {
        for x in 0..<8 {
            for y in 0..<8 {
                sphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .black)
            }
        }
        
        // Applique le preset
        for x in 0..<8 {
            for y in 0..<8 where lightningPreset[x][y] {
                sphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .yellow)
            }
        }
        
        //        print("Preset Lightning envoyé au Sphero \(sphero.name ?? "Inconnu")")
    }
}
