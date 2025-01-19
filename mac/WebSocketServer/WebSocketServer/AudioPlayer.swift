import Foundation
import AVFoundation

class AudioPlayer: NSObject {
    static let shared = AudioPlayer()
    
    // Dictionary to store multiple audio players
    private var soundPlayers: [String: AVAudioPlayer] = [:]
    private var musicPlayers: [String: AVAudioPlayer] = [:]
    
    // Keep track of currently playing music tracks
    private var currentlyPlayingMusic: Set<String> = []
    private var loopingSounds: Set<String> = []

    // Dictionary to store fade timers
    private var fadeTimers: [String: Timer] = [:]
    
    override init() {
        super.init()
    }
    
    func playSound(name: String, type: String = "wav", delay: TimeInterval = 0, loop: Bool = false) -> Bool {
            let soundDirectory = "sound"
            
            guard let soundPath = Bundle.main.path(forResource: name, ofType: type, inDirectory: soundDirectory) else {
                print("Sound file '\(name).\(type)' not found in directory '\(soundDirectory)'")
                return false
            }
            
            let soundURL = URL(fileURLWithPath: soundPath)
            
            do {
                let player = try AVAudioPlayer(contentsOf: soundURL)
                player.prepareToPlay()
                
                let playerId = "\(name)_\(UUID().uuidString)"
                soundPlayers[playerId] = player
                
                player.delegate = self
                
                if loop {
                    player.numberOfLoops = -1 // Boucle infinie
                    loopingSounds.insert(playerId)
                }
                
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.soundPlayers[playerId]?.play()
                    }
                } else {
                    player.play()
                }
                
                return true
            } catch {
                print("Error playing sound: \(error.localizedDescription)")
                return false
            }
        }
        
        func stopSound(name: String) {
            // Filtrer les joueurs correspondant au nom donné
            let matchingPlayers = soundPlayers.filter { $0.key.starts(with: name) }
            
            for (playerId, player) in matchingPlayers {
                player.stop()
                soundPlayers.removeValue(forKey: playerId)
                loopingSounds.remove(playerId)
            }
        }
        
        func stopAllSounds() {
            for (playerId, player) in soundPlayers {
                player.stop()
            }
            soundPlayers.removeAll()
            loopingSounds.removeAll()
        }
    
    func playMusic(name: String, type: String = "wav", delay: TimeInterval = 1, fadeInDuration: TimeInterval = 1) -> Bool {
            let soundDirectory = "sound"
            
            guard let musicPath = Bundle.main.path(forResource: name, ofType: type, inDirectory: soundDirectory) else {
                print("Music file '\(name).\(type)' not found in directory '\(soundDirectory)'")
                return false
            }
            
            let musicURL = URL(fileURLWithPath: musicPath)
            
            do {
                let player = try AVAudioPlayer(contentsOf: musicURL)
                player.prepareToPlay()
                player.numberOfLoops = -1  // Loop indefinitely
                
                // If using fade in, start with volume at 0
                if fadeInDuration > 0 {
                    player.volume = 0
                }
                
                musicPlayers[name] = player
                currentlyPlayingMusic.insert(name)
                
                let playMusic = { [weak self] in
                    guard let player = self?.musicPlayers[name] else { return }
                    player.play()
                    
                    if fadeInDuration > 0 {
                        // Cancel any existing fade for this player
                        self?.fadeTimers[name]?.invalidate()
                        
                        let targetVolume: Float = 1.0
                        let volumeIncrease = targetVolume / Float(fadeInDuration * 10) // 10 steps per second
                        
                        DispatchQueue.main.async {
                            self?.fadeTimers[name] = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                                guard let self = self,
                                      let currentPlayer = self.musicPlayers[name] else {
                                    timer.invalidate()
                                    return
                                }
                                
                                let newVolume = currentPlayer.volume + volumeIncrease
                                
                                if newVolume >= targetVolume {
                                    currentPlayer.volume = targetVolume
                                    timer.invalidate()
                                    self.fadeTimers[name] = nil
                                } else {
                                    currentPlayer.volume = newVolume
                                }
                            }
                        }
                    }
                }
                
                if delay > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: playMusic)
                } else {
                    playMusic()
                }
                
                return true
            } catch {
                print("Error playing music: \(error.localizedDescription)")
                return false
            }
        }
    
    func stopMusic(_ name: String, fadeOutDuration: TimeInterval = 2.0) {
        guard let player = musicPlayers[name] else { return }
        
        // Cancel any existing fade for this player
        fadeTimers[name]?.invalidate()
        
        let initialVolume = player.volume
        let volumeReduction = initialVolume / Float(fadeOutDuration * 10) // 10 steps per second
        
        // Create and store new fade timer on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.fadeTimers[name] = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                guard let currentPlayer = self.musicPlayers[name] else {
                    timer.invalidate()
                    self.fadeTimers[name] = nil
                    return
                }
                
                let newVolume = currentPlayer.volume - volumeReduction
                
                if newVolume <= 0 {
                    // Stop and cleanup
                    currentPlayer.stop()
                    self.musicPlayers.removeValue(forKey: name)
                    self.currentlyPlayingMusic.remove(name)
                    timer.invalidate()
                    self.fadeTimers[name] = nil
                } else {
                    currentPlayer.volume = newVolume
                }
            }
        }
    }
    
    func stopAllMusic(fadeOutDuration: TimeInterval = 2.0) {
        // Stop each music track with fade out
        for (name, _) in musicPlayers {
            stopMusic(name, fadeOutDuration: fadeOutDuration)
        }
    }
    
    // Clean up completed sound players
    private func cleanupCompletedPlayers() {
        soundPlayers = soundPlayers.filter { (_, player) in
            player.isPlaying
        }
    }
}

// AVAudioPlayerDelegate implementation to handle sound completion
extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Clean up completed players in the next run loop
        DispatchQueue.main.async { [weak self] in
            self?.cleanupCompletedPlayers()
        }
    }
}
