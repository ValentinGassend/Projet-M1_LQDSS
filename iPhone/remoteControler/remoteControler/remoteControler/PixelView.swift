//
//  PixelView.swift
//  SpheroManager
//
//  Created by Valentin Gassant on 26/11/2024.
//

import SwiftUI

struct PixelView: View {
    @Binding var pixel: ColoredPixel
    @Binding var selectedColor: Color
    
    var body: some View {
        Rectangle()
            .fill(pixel.isOn ? pixel.color : Color.gray.opacity(0.3))
            .frame(width: 30, height: 30)
            .onTapGesture {
                pixel.isOn.toggle()
                if pixel.isOn {
                    pixel.color = selectedColor
                }
            }
    }
}
