//
//  ContentView.swift
//  Accelerometre
//
//  Created by digital on 24/10/2024.
//

import SwiftUI
import Charts

struct ContentView: View {
    @StateObject private var orientationManager = OrientationManager()
    
    let values = ["Poubelle", "Rond", "Carré", "Triangle"]
    
    @State private var isRecording = false
    @State private var selectedValue = ""
    
    var body: some View {
        ScrollView{
            VStack {
                SegmentedView(values: values, selectedValue: $selectedValue)
                    .frame(height: 50)
                Spacer()
                
                VStack {
                    Spacer()
                    Text("Enregistrement des données :")
                        .font(.headline)
                    
                    if isRecording {
                        if let lastData = orientationManager.accelerometerData.last {
                            HStack{
                                Text("X: \(String(format: "%.2f", lastData.x))")
                                Text("Y: \(String(format: "%.2f", lastData.y))")
                                Text("Z: \(String(format: "%.2f", lastData.z))")
                            }
                            AccelerometerView().environmentObject(orientationManager)
                            TurtleView()
                        } else {
                            Text("Aucune donnée disponible.")
                        }
                    } else {
                        Text("Lancez l'enregistrement")
                    }
                    Spacer()
                    
                    HStack {
                        Button(action: {
                            isRecording.toggle()
                        }) {
                            Text(isRecording ? "Stop" : "Record")
                                .padding()
                                .background(isRecording ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .animation(.easeInOut, value: isRecording)
                    }
                    .padding()
                }
            }
            .padding()
            .onAppear {
                orientationManager.startAccelerometerUpdates()
            }
            .onChange(of: isRecording) { oldValue, newValue in
                if newValue {

                } else {

                }
            }
        }
    }
}

#Preview {
    ContentView()
}

