//
//  AudioPlayer.swift
//  WebSocketServer
//
//  Created by Valentin Gassant on 13/01/2025.
//

import Foundation
import AVFoundation
class AudioPlayer {
    static let shared = AudioPlayer()
    private var audioPlayer: AVAudioPlayer?
    
    func playSound() {
        // Debug: Afficher tous les fichiers du bundle
        if let resources = Bundle.main.urls(forResourcesWithExtension: "aiff", subdirectory: nil) {
            print("Available .aiff files in bundle:")
            resources.forEach { print($0.lastPathComponent) }
        }
        
        // Debug: Vérifier le chemin exact
        if let path = Bundle.main.path(forResource: "Bottle", ofType: "aiff") {
            print("Found sound file at path: \(path)")
        } else {
            print("Debug bundle path: \(Bundle.main.bundlePath)")
            print("Sound file 'Bottle.aiff' not found in bundle")
        }
        
        guard let soundPath = Bundle.main.path(forResource: "Bottle", ofType: "aiff") else {
            print("Sound file not found")
            return
        }
        
        let soundURL = URL(fileURLWithPath: soundPath)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}
