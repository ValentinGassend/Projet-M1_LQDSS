//
//  ContentView.swift
//  SpheroManager
//
//  Created by Valentin Gassant on 23/11/2024.
//

import SwiftUI

struct SpheroToWsServerView: View {
    @ObservedObject var wsClient = WebSocketClient.instance
    @State var isSpheroConnectedToIphone: Bool = false
    @State var isIphoneConnectedToWsS: Bool = false
    @State var showSheet: Bool = false
    var body: some View {
        VStack {
            Spacer()
            Button("Connect Iphone") {
                wsClient.connectForIdentification(route: .iPhoneConnect)
                isIphoneConnectedToWsS = true
            }
            Spacer()
            Button("Connect Sphero to Iphone") {
                DispatchQueue.main.async {
                    print("Searching")
                    // SB-313C
                    SharedToyBox.instance.searchForBoltsNamed(["SB-8630"]) { err in
                        if err == nil {
                            isSpheroConnectedToIphone = true
                            print("Connected")
                        }
                        
                        
                    }
                }
            }
            Spacer()
            
            if let bolt = SharedToyBox.instance.bolt {
                if let peripheralName = bolt.peripheral?.name {
                    Button("identificate my sphero") {
                        wsClient.connectForIdentification(route: .spheroIdentificationConnect)
                        wsClient.sentToRoute(route: .spheroIdentificationConnect, msg: peripheralName)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .sheet(isPresented: Binding(get: {
            isSpheroConnectedToIphone && isIphoneConnectedToWsS
        }, set: { newValue in
            // Optionally handle the dismissal of the sheet
            showSheet = newValue
        })) {
            // Content displayed in the sheet
            Text("Sphero and iPhone are successfully connected!")
                .font(.headline)
                .padding()
            // text SharedToyBox.instance.bolt?.descriptor
            if let bolt = SharedToyBox.instance.bolt {
                VStack {
                    Text("Bolt Name: \(bolt.peripheral?.name ?? "Unknown")")
                    Button("Send Bolt Name to Typhoon Route") {
                        if let peripheralName = bolt.peripheral?.name {
                            wsClient.sendSpheroTyphoonName(msg: peripheralName)
                            print("Sent peripheral name: \(peripheralName)")
                        } else {
                            print("No peripheral name available to send.")
                        }
                    }
                    
                }
            }
            
        }
        
        
    }
    
    private func connectSphero() {
        DispatchQueue.main.async {
            print("Searching")
            SharedToyBox.instance.searchForBoltsNamed(["SB-8630"]) { err in
                if err == nil {
                    print("Connected")
                }
                
                
            }
        }
    }
    
}

#Preview {
    SpheroToWsServerView()
}
