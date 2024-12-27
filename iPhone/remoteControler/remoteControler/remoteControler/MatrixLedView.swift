import SwiftUI

// Structure pour représenter un pixel coloré
struct ColoredPixel {
    var isOn: Bool
    var color: Color
}

struct MatrixPreset {
    var pixels: [[ColoredPixel]]
    var defaultColor: Color
}

struct MatrixLedView: View {
    @Binding var showMazeIcon: Bool
    @Binding var spheroMazeInfo: [String: BoltToy]
    @State private var matrix: [[ColoredPixel]] = Array(
            repeating: Array(repeating: ColoredPixel(isOn: false, color: .yellow), count: 8),
            count: 8
        )
    @State private var selectedColor: Color = .yellow
    
    private let availableColors: [Color] = [.yellow, .red, .green, .blue, .purple, .orange,.black, .white]
    
    private func clearMatrix() {
        matrix = Array(repeating: Array(repeating: ColoredPixel(isOn: false, color: selectedColor), count: 8), count: 8)
    }
    
    private func clearSpheroMatrix() {
        guard let mazeSphero = spheroMazeInfo["SB-313C"] else {
            print("Sphero maze is not connected or info unavailable")
            return
        }
        
        print("Clearing Sphero maze matrix...")
        for x in 0..<8 {
            for y in 0..<8 {
                mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: .black)
            }
        }
    }
    
    private func sendDrawingToSphero() {
        guard let mazeSphero = spheroMazeInfo["SB-313C"] else {
            print("Sphero maze is not connected or info unavailable")
            return
        }
        
        clearSpheroMatrix()
        
        print("Sending drawing to maze Sphero...")
        //        mazeSphero.setBackLed(brightness: 0)
        mazeSphero.setFrontLed(color: .black)
        mazeSphero.setBackLed(color: .black)
        for x in 0..<matrix.count {
                    for y in 0..<matrix[x].count where matrix[x][y].isOn {
                        mazeSphero.drawMatrix(pixel: Pixel(x: x, y: y), color: convertToUIColor(matrix[x][y].color))
                    }
                }
    }
    
    private func convertToUIColor(_ color: Color) -> UIColor {
        switch color {
        case .yellow: return .yellow
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .orange: return .orange
        case .black: return .black
        case .white: return .white
        default: return .yellow
        }
    }
    
    
    private func applyPreset(_ preset: MatrixPreset) {
            matrix = preset.pixels
            selectedColor = preset.defaultColor
        }
        
        private func createColoredPixel(isOn: Bool, color: Color = .yellow) -> ColoredPixel {
            return ColoredPixel(isOn: isOn, color: color)
        }
        
        private func loadSnowflakePreset() {
            let preset = MatrixPreset(
                pixels: Array(repeating: Array(repeating: createColoredPixel(isOn: false, color: .cyan), count: 8), count: 8),
                defaultColor: .cyan
            )
            
            let pattern = [
                [false, false, true,  false, false, true,  false, false],
                [false, true,  false, true,  true,  false, true,  false],
                [true,  false, true,  true,  true,  true,  false, true],
                [false, true,  true,  true,  true,  true,  true,  false],
                [false, true,  true,  true,  true,  true,  true,  false],
                [true,  false, true,  true,  true,  true,  false, true],
                [false, true,  false, true,  true,  false, true,  false],
                [false, false, true,  false, false, true,  false, false]
            ]
            
            var coloredPixels = preset.pixels
            for row in 0..<8 {
                for col in 0..<8 {
                    coloredPixels[row][col].isOn = pattern[row][col]
                }
            }
            
            applyPreset(MatrixPreset(pixels: coloredPixels, defaultColor: .cyan))
        }
        
        private func loadSantaPreset() {
            let preset = MatrixPreset(
                pixels: Array(repeating: Array(repeating: createColoredPixel(isOn: false, color: .red), count: 8), count: 8),
                defaultColor: .red
            )
            
            let pattern = [
                [false, false, true,  true,  true,  true,  false, false],
                [false, true,  true,  false, false, true,  true,  false],
                [true,  true,  false, true,  true,  false, true,  true],
                [false, true,  true,  true,  true,  true,  true,  false],
                [true,  false, true,  true,  true,  true,  false, true],
                [true,  true,  true,  false, false, true,  true,  true],
                [false, true,  true,  true,  true,  true,  true,  false],
                [false, false, true,  true,  true,  true,  false, false]
            ]
            
            var coloredPixels = preset.pixels
            for row in 0..<8 {
                for col in 0..<8 {
                    coloredPixels[row][col].isOn = pattern[row][col]
                    if pattern[row][col] {
                        if row == 2 && (col == 3 || col == 4) {
                            coloredPixels[row][col].color = .white
                        }
                    }
                }
            }
            
            applyPreset(MatrixPreset(pixels: coloredPixels, defaultColor: .red))
        }
        
        private func loadTreePreset() {
            let preset = MatrixPreset(
                pixels: Array(repeating: Array(repeating: createColoredPixel(isOn: false, color: .green), count: 8), count: 8),
                defaultColor: .green
            )
            
            let pattern = [
                [false, false, false, true,  false, false, false, false],
                [false, false, true,  true,  true,  false, false, false],
                [false, true,  true,  true,  true,  true,  false, false],
                [false, false, true,  true,  true,  false, false, false],
                [false, true,  true,  true,  true,  true,  false, false],
                [true,  true,  true,  true,  true,  true,  true,  false],
                [false, false, false, true,  false, false, false, false],
                [false, false, true,  true,  true,  false, false, false]
            ]
            
            var coloredPixels = preset.pixels
            for row in 0..<8 {
                for col in 0..<8 {
                    coloredPixels[row][col].isOn = pattern[row][col]
                    if pattern[row][col] {
                        if (row == 6 || row == 7) && (col == 3 || col == 4) {
                            coloredPixels[row][col].color = .orange
                        }
                    }
                }
            }
            
            applyPreset(MatrixPreset(pixels: coloredPixels, defaultColor: .green))
        }
        
        private func loadGiftPreset() {
            let preset = MatrixPreset(
                pixels: Array(repeating: Array(repeating: createColoredPixel(isOn: false, color: .red), count: 8), count: 8),
                defaultColor: .red
            )
            
            let pattern = [
                [true,  true,  true,  true,  true,  true,  true,  true],
                [true,  false, true,  false, false, true,  false, true],
                [true,  true,  true,  true,  true,  true,  true,  true],
                [true,  false, true,  false, false, true,  false, true],
                [true,  true,  true,  true,  true,  true,  true,  true],
                [false, true,  false, true,  true,  false, true,  false],
                [false, false, true,  true,  true,  true,  false, false],
                [false, false, false, true,  true,  false, false, false]
            ]
            
            var coloredPixels = preset.pixels
            for row in 0..<8 {
                for col in 0..<8 {
                    coloredPixels[row][col].isOn = pattern[row][col]
                    if pattern[row][col] {
                        if row == 2 || col == 3 || col == 4 {
                            coloredPixels[row][col].color = .yellow
                        }
                    }
                }
            }
            
            applyPreset(MatrixPreset(pixels: coloredPixels, defaultColor: .red))
        }
        
        private func loadSnowmanPreset() {
            let preset = MatrixPreset(
                pixels: Array(repeating: Array(repeating: createColoredPixel(isOn: false, color: .white), count: 8), count: 8),
                defaultColor: .white
            )
            
            let pattern = [
                [false, false, true,  true,  true,  true,  false, false],
                [false, true,  false, false, false, false, true,  false],
                [false, true,  true,  false, false, true,  true,  false],
                [false, false, true,  true,  true,  true,  false, false],
                [false, false, true,  true,  true,  true,  false, false],
                [false, true,  true,  false, false, true,  true,  false],
                [false, true,  true,  true,  true,  true,  true,  false],
                [false, false, true,  true,  true,  true,  false, false]
            ]
            
            var coloredPixels = preset.pixels
            for row in 0..<8 {
                for col in 0..<8 {
                    coloredPixels[row][col].isOn = pattern[row][col]
                    // Yeux et boutons en noir
                    if (row == 2 && (col == 2 || col == 5)) || (row == 4 && col == 3) {
                        coloredPixels[row][col].color = .black
                    }
                }
            }
            
            applyPreset(MatrixPreset(pixels: coloredPixels, defaultColor: .white))
        }
        
        private func loadStarPreset() {
            let preset = MatrixPreset(
                pixels: Array(repeating: Array(repeating: createColoredPixel(isOn: false, color: .yellow), count: 8), count: 8),
                defaultColor: .yellow
            )
            
            let pattern = [
                [false, false, false, true,  false, false, false, false],
                [false, false, true,  true,  true,  false, false, false],
                [false, true,  true,  true,  true,  true,  false, false],
                [true,  true,  true,  true,  true,  true,  true,  false],
                [false, true,  true,  true,  true,  true,  false, false],
                [false, true,  true,  false, true,  true,  false, false],
                [false, false, true,  false, true,  false, false, false],
                [false, false, false, true,  false, false, false, false]
            ]
            
            var coloredPixels = preset.pixels
            for row in 0..<8 {
                for col in 0..<8 {
                    coloredPixels[row][col].isOn = pattern[row][col]
                }
            }
            
            applyPreset(MatrixPreset(pixels: coloredPixels, defaultColor: .yellow))
        }
        
        private func loadBellPreset() {
            let preset = MatrixPreset(
                pixels: Array(repeating: Array(repeating: createColoredPixel(isOn: false, color: .yellow), count: 8), count: 8),
                defaultColor: .yellow
            )
            
            let pattern = [
                [false, false, false, true,  true,  false, false, false],
                [false, false, true,  true,  true,  true,  false, false],
                [false, false, true,  false, false, true,  false, false],
                [false, false, true,  true,  true,  true,  false, false],
                [false, true,  true,  true,  true,  true,  true,  false],
                [true,  true,  false, true,  true,  false, true,  true],
                [true,  false, false, true,  true,  false, false, true],
                [false, false, true,  true,  true,  true,  false, false]
            ]
            
            var coloredPixels = preset.pixels
            for row in 0..<8 {
                for col in 0..<8 {
                    coloredPixels[row][col].isOn = pattern[row][col]
                }
            }
            
            applyPreset(MatrixPreset(pixels: coloredPixels, defaultColor: .yellow))
        }
    private func loadCandlePreset() {
        let pattern = [
            [false, false, false, true,  true,  false, false, false],
            [false, false, true,  true,  true,  true,  false, false],
            [false, false, false, true,  true,  false, false, false],
            [false, false, false, true,  true,  false, false, false],
            [false, false, false, true,  true,  false, false, false],
            [false, false, true,  true,  true,  true,  false, false],
            [false, true,  true,  true,  true,  true,  true,  false],
            [false, true,  true,  false, false, true,  true,  false]
        ]
        let coloredPixels = pattern.map { row in
            row.map { value in
                ColoredPixel(isOn: value, color: selectedColor)
            }
        }
        matrix = coloredPixels
    }
    
    private func loadArrowPreset() {
        let arrowPreset = [
            [false, false, false, true,  false, false, false, false],
            [false, false, true,  true,  true,  false, false, false],
            [false, true,  false, true,  false, true,  false, false],
            [true,  false, false, true,  false, false, true,  false],
            [false, false, false, true,  false, false, false, false],
            [false, false, false, true,  false, false, false, false],
            [false, false, false, true,  false, false, false, false],
            [false, false, false, true,  false, false, false, false]
        ]
        matrix = arrowPreset.map { row in
            row.map { value in
                ColoredPixel(isOn: value, color: selectedColor)
            }
        }
    }

    private func loadLightningPreset() {
        let pattern = [
            [false, false, false, false, false, false, false, false],
            [false, false, false, false, true,  true,  true,  false],
            [false, false, false, true,  true,  true,  false, false],
            [false, false, true,  true,  true,  false, false, false],
            [false, true,  true,  true,  true,  true,  false, false],
            [false, false, false, true,  true,  false, false, false],
            [false, false, true,  true,  false, false, false, false],
            [false, true,  false, false, false, false, false, false],
        ]
        matrix = pattern.map { row in
            row.map { value in
                ColoredPixel(isOn: value, color: selectedColor)
            }
        }
    }

    private func loadHeartPreset() {
        let pattern = [
            [false, true,  true,  false, false, true,  true,  false],
            [true,  true,  true,  true,  true,  true,  true,  true],
            [true,  true,  true,  true,  true,  true,  true,  true],
            [true,  true,  true,  true,  true,  true,  true,  true],
            [false, true,  true,  true,  true,  true,  true,  false],
            [false, false, true,  true,  true,  true,  false, false],
            [false, false, false, true,  true,  false, false, false],
            [false, false, false, false, false, false, false, false]
        ]
        matrix = pattern.map { row in
            row.map { value in
                ColoredPixel(isOn: value, color: selectedColor)
            }
        }
    }



    var body: some View {
        VStack {
            Text("Matrix LED View")
                .font(.largeTitle)
                .padding()
            
            // Color picker
            HStack {
                Text("Couleur:")
                ForEach(availableColors, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            VStack(spacing: 1) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 1) {
                        ForEach(0..<8, id: \.self) { column in
                            PixelView(pixel: $matrix[row][column], selectedColor: $selectedColor)
                        }
                    }
                }
            }
            .padding(20)
            
            // Preset buttons in two rows
            VStack {
                HStack {
                    PresetButton(title: "Éclair", color: .blue) {
                        loadLightningPreset()
                    }
                    PresetButton(title: "Cœur", color: .pink) {
                        loadHeartPreset()
                    }
                    PresetButton(title: "Flèche", color: .green) {
                        loadArrowPreset()
                    }
                    
                }
                HStack {
                    PresetButton(title: "Flocon", color: .cyan) {
                        loadSnowflakePreset()
                    }
                    PresetButton(title: "Père Noël", color: .red) {
                        loadSantaPreset()
                    }
                    PresetButton(title: "Cadeau", color: .yellow) {
                        loadGiftPreset()
                    }
                    PresetButton(title: "Sapin", color: .green) {
                        loadTreePreset()
                    }
                    PresetButton(title: "Bonhomme", color: .white) {
                        loadSnowmanPreset()
                    }
                    PresetButton(title: "Étoile", color: .yellow) {
                        loadStarPreset()
                    }
                    PresetButton(title: "Cloche", color: .orange) {
                        loadBellPreset()
                    }
                    PresetButton(title: "Bougie", color: .red) {
                        loadCandlePreset()
                    }
                    
                }
            }
            .padding()
            
            HStack {
                Button("Effacer") {
                    clearMatrix()
                }
                .buttonStyle(ActionButtonStyle(color: .red))
                
                Button("Envoyer à Sphero") {
                    sendDrawingToSphero()
                }
                .buttonStyle(ActionButtonStyle(color: !spheroMazeInfo.isEmpty ? .orange : .gray))
                .disabled(spheroMazeInfo.isEmpty)
                
            }
            .padding()
            
            HStack {
                Button("Stabiliser") {
                    if let mazeSphero = spheroMazeInfo["SB-313C"] {
                        mazeSphero.setStabilization(state: .on)
                    }
                }
                .buttonStyle(ActionButtonStyle(color: .green))
                
                Button("Déstabiliser") {
                    if let mazeSphero = spheroMazeInfo["SB-313C"] {
                        mazeSphero.setStabilization(state: .off)
                    }
                }
                .buttonStyle(ActionButtonStyle(color: .red))
            }
            .padding()
        }
        .onChange(of: showMazeIcon) { newValue in
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

// Helper Views
struct PresetButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding()
                .background(color)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
