//
//  PixelView.swift
//  SpheroManager
//
//  Created by Valentin Gassant on 26/11/2024.
//

import SwiftUI

struct PixelView: View {
    @Binding var isOn: Bool

    var body: some View {
        Rectangle()
            .fill(isOn ? Color.yellow : Color.black)
            .frame(width: 20, height: 20)
            .border(Color.gray)
            .onTapGesture {
                isOn.toggle()
            }
    }
}
