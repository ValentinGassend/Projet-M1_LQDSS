import SwiftUI

struct MatrixLedView: View {
    @Binding var showMazeIcon: Bool
    @Binding var spheroMazeInfo: [String: BoltToy]  // Ajouter ce binding pour récupérer les informations sur la Sphero Maze
    @State private var matrix: [[Bool]] = Array(
        repeating: Array(repeating: false, count: 8),
        count: 8
    )

    private func clearMatrix() {
            matrix = Array(repeating: Array(repeating: false, count: 8), count: 8)
        }

    private func clearSpheroMatrix() {
            guard let mazeSphero = spheroMazeInfo["SB-313C"] else {
                print("Sphero maze is not connected or info unavailable")
                return
            }

            print("Clearing Sphero maze matrix...")
            mazeSphero.drawMatrix(pixel: Pixel(x: 0, y: 0), color: .black) // Example of clearing the matrix on the mazeSphero
            // Pour chaque pixel, vous effacez la matrice uniquement sur la mazeSphero
            for x in 0..<8 {
                for y in 0..<8 {
                    mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .black)
                }
            }
        }


    private func sendDrawingToSphero() {
        print(spheroMazeInfo)
            guard let mazeSphero = spheroMazeInfo["SB-313C"] else {
                print("Sphero maze is not connected or info unavailable")
                return
            }

            clearSpheroMatrix()

            print("Sending drawing to maze Sphero...")
            // Envoi de la matrice dessinée à la mazeSphero spécifique
            for x in 0..<matrix.count {
                for y in 0..<matrix[x].count where matrix[x][y] {
                    mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .yellow)
                }
            }

            print("Current Matrix State:")
            for row in matrix {
                print(
                    row.map { $0 ? 1 : 0
                    })
            }
            print("Drawing sent to maze Sphero!")
        }

    private func loadArrowPreset() {
        let arrowPreset = [
            [false, false, false, true,  true,  false, false, false],
            [false, false, true,  true,  true,  true,  false, false],
            [false, true,  true,  true,  true,  true,  true,  false],
            [true,  true,  true,  true,  true,  true,  true,  true],
            [false, false, true,  true,  true,  true,  false, false],
            [false, false, true,  true,  true,  true,  false, false],
            [false, false, true,  true,  true,  true,  false, false],
            [false, false, true,  true,  true,  true,  false, false],
        ]
        matrix = arrowPreset
    }

    private func loadLightningPreset() {
        let lightningPreset = [
            [false, false, false, false, false, false, false, false],
            [false, false, false, false, true,  true,  true,  false],
            [false, false, false, true,  true,  true,  false, false],
            [false, false, true,  true,  true,  false, false, false],
            [false, true,  true,  true,  true,  true,  false, false],
            [false, false, false, true,  true,  false, false, false],
            [false, false, true,  true,  false, false, false, false],
            [false, true,  false, false, false, false, false, false],
        ]
        matrix = lightningPreset
    }

    // Fonction pour charger le preset de cœur
    private func loadHeartPreset() {
        let heartPreset = [
            [false, false, false, false, false, false, false, false],
            [false, true,  false, false, false, true,  false, false],
            [true,  true,  true,  false, true,  true,  true,  false],
            [true,  true,  true,  true,  true,  true,  true,  false],
            [true,  true,  true,  true,  true,  true,  true,  false],
            [false, true,  true,  true,  true,  true,  false, false],
            [false, false, true,  true,  true,  false, false, false],
            [false, false, false, true,  false, false, false, false],
        ]
        matrix = heartPreset
    }
    
    var body: some View {
        VStack {
            Text("Matrix LED View")
                .font(.largeTitle)
                .padding()

            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<8, id: \.self) { column in
                            PixelView(isOn: $matrix[row][column])
                        }
                    }
                }
            }
            .padding(20)
            HStack {
                Button(action: {
                    loadLightningPreset()
                }) {
                    Text("Charger l'éclair")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }

                Button(action: {
                    loadHeartPreset()
                }) {
                    Text("Charger le cœur")
                        .padding()
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Button(action: {
                    loadArrowPreset()
                }) {
                    Text("Charger la fleche")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding()

            HStack {
                Button("Effacer") {
                    clearMatrix()
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Envoyer à Sphero") {
                    sendDrawingToSphero()
                }
                .padding()
                .background(!spheroMazeInfo.isEmpty ? Color.orange : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(spheroMazeInfo.isEmpty)
            }
            .padding()
            HStack {
                Button("stabiliser") {
                        if let mazeSphero = spheroMazeInfo["SB-313C"] {
                            mazeSphero.setStabilization(state: .on)
                        }
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("déstabiliser") {
                    if let mazeSphero = spheroMazeInfo["SB-313C"] {
                        mazeSphero.setStabilization(state: .off)
                    }
                }
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)

                
            }
            .padding()
        }.onChange(of: showMazeIcon) { newValue in
            if newValue {
                loadLightningPreset()
                sendDrawingToSphero()
            }
        }
        .onAppear() {
            print(spheroMazeInfo)
        }
    }
}
    
