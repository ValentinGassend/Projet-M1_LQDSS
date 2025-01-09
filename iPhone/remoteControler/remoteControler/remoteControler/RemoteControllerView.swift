import SwiftUI
import Foundation

class SpheroPresetManager {
    static let shared = SpheroPresetManager()
    
    private let lightningPreset = [
        [false, false, false, false, false, false, false, false],
        [false, false, false, false, true,  true,  true,  false],
        [false, false, false, true,  true,  true,  false, false],
        [false, false, true,  true,  true,  false, false, false],
        [false, true,  true,  true,  true,  true,  false, false],
        [false, false, false, true,  true,  false, false, false],
        [false, false, true,  true,  false, false, false, false],
        [false, true,  false, false, false, false, false, false],
    ]
    
    func sendLightningPreset(to sphero: BoltToy) {
        //        print("Envoi du preset Lightning au Sphero \(sphero.name ?? "Inconnu")")
        
        // Efface la matrice
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

// Vue principale
struct RemoteControllerView: View {
    @ObservedObject var wsClient = WebSocketClient.instance
    
    var body: some View {
        TabView {
            VolcanoView(wsClient: wsClient)
                .tabItem {
                    Label("Volcano", systemImage: "flame")
                }
            MazeView(wsClient: wsClient)
                .tabItem {
                    Label("Maze", systemImage: "bolt")
                }
            TyphoonView(wsClient: wsClient)
                .tabItem {
                    Label("Typhoon", systemImage: "tornado")
                }
            TornadoView(wsClient: wsClient)
                .tabItem {
                    Label("Tornado", systemImage: "wind")
                }
            CrystalView(wsClient: wsClient)
                .tabItem {
                    Label("Crystal", systemImage: "sparkles")
                }
        }
    }
}

struct VolcanoView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        
        "crystal_esp1=>[crystal_esp2,crystal_esp1,volcano_esp1,volcano_esp2,ambianceManager_rpi]=>rfid#volcano",
        "volcano_esp1=>[volcano_esp1,volcano_esp2]=>rfid#volcano",
        "volcano_esp1=>[volcano_esp1,volcano_esp2 crystal_esp2,crystal_esp1]=>rfid#first",
        "volcano_esp1=>[volcano_esp2]=>relay1#true",
        "volcano_esp1=>[volcano_esp2]=>relay1#false",
        "volcano_esp2=>[volcano_esp1]=>rfid#second"
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct MazeView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        "crystal_esp1=>[crystal_esp2,crystal_esp1,maze_esp,ambianceManager_rpi]=>rfid#maze",
        "maze_esp=>[maze_esp,maze_iphone,ambianceManager_rpi]=>rfid#maze",
        "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn1#true",
        "maze_esp=>[maze_iphone]=>btn1#false",
        "maze_esp=>[maze_iphone,ambianceManager_rpi]=>btn2#true"
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct TyphoonView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        "crystal_esp2=>[crystal_esp2,crystal_esp1,typhoon_esp,ambianceManager_rpi]=>rfid#typhoon",
        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>rfid#typhoon",
        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay1#true",
        "typhon_esp=>[typhoon_iphone]=>relay1#false",
        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay2#true",
        "typhon_esp=>[typhoon_iphone]=>relay2#false",
        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay3#true",
        "typhon_esp=>[typhoon_iphone]=>relay3#false",
        "typhon_esp=>[typhoon_iphone,ambianceManager_rpi]=>relay4#true",
        "typhon_esp=>[typhoon_iphone]=>relay4#false",
        "typhoon_iphone=>[typhoon_esp]=>sphero1#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero1#false",
        "typhoon_iphone=>[typhoon_esp]=>sphero1#completed",
        "typhoon_iphone=>[typhoon_esp]=>sphero2#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero2#false",
        "typhoon_iphone=>[typhoon_esp]=>sphero2#completed",
        "typhoon_iphone=>[typhoon_esp]=>sphero3#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero3#false",
        "typhoon_iphone=>[typhoon_esp]=>sphero3#completed",
        "typhoon_iphone=>[typhoon_esp]=>sphero4#true",
        "typhoon_iphone=>[typhoon_esp]=>sphero4#false",
        "typhoon_iphone=>[typhoon_esp]=>sphero4#completed"
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct TornadoView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        "crystal_esp2=>[crystal_esp2,crystal_esp1,tornado_esp,ambianceManager_rpi]=>rfid#tornado",
        "tornado_esp=>[tornado_esp,tornado_rpi,ambianceManager_rpi]=>rfid#tornado",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic1#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic1#false",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic2#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic2#false",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic3#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic3#false",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic4#true",
        "tornado_esp=>[tornado_rpi,ambianceManager_rpi]=>mic4#false",
        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#first",
        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#second",
        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#third",
        "tornado_rpi=>[tornado_esp,ambianceManager_rpi]=>rvr#fourth"
        
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct CrystalView: View {
    let wsClient: WebSocketClient
    
    private let commands = [
        "crystal_esp1=>[crystal_esp2,crystal_esp1,volcano_esp1,volcano_esp2,ambianceManager_rpi]=>rfid#volcano",
        "crystal_esp1=>[crystal_esp2,crystal_esp1,maze_esp,ambianceManager_rpi]=>rfid#maze",
        //        "crystal_esp2=>[crystal_esp2,crystal_esp1,AmbianceManager_rpi]=>crystal_start_animation",
        "crystal_esp2=>[crystal_esp2,crystal_esp1,tornado_esp,ambianceManager_rpi]=>rfid#tornado",
        "crystal_esp2=>[crystal_esp2,crystal_esp1,typhoon_esp,ambianceManager_rpi]=>rfid#typhoon"
    ]
    
    var body: some View {
        CommandListView(commands: commands, wsClient: wsClient)
    }
}

struct CommandListView: View {
    let commands: [String]
    let wsClient: WebSocketClient
    
    var body: some View {
        List(commands, id: \ .self) { command in
            Button(action: {
                if let messageParsed = wsClient.parseSendedMessage(command) {
                    wsClient.sendMessage(from: messageParsed.routeOrigin, to: messageParsed.routeTargets, component: messageParsed.component, data: messageParsed.data)
                }
            }) {
                Text(command)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(title, action: action)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}
