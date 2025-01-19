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
    
    func playSound(name: String, type: String = "wav") -> Bool {
        // Sous-dossier contenant les fichiers audio
        let soundDirectory = "sound"

        // Afficher les fichiers disponibles en mode debug
        if let resources = Bundle.main.urls(
            forResourcesWithExtension: type,
            subdirectory: soundDirectory
        ) {
            print(
                "Fichiers .\(type) disponibles dans le sous-dossier '\(soundDirectory)' :"
            )
            resources.forEach { print($0.lastPathComponent) }
        }
        
        // Vérifier si le fichier existe dans le sous-dossier
        guard let soundPath = Bundle.main.path(forResource: name, ofType: type, inDirectory: soundDirectory) else {
            print(
                "Fichier son '\(name).\(type)' non trouvé dans le sous-dossier '\(soundDirectory)'"
            )
            print("Chemin du bundle: \(Bundle.main.bundlePath)")
            return false
        }
        
        let soundURL = URL(fileURLWithPath: soundPath)
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            return true
        } catch {
            print(
                "Erreur lors de la lecture du son: \(error.localizedDescription)"
            )
            return false
        }
    }
}
