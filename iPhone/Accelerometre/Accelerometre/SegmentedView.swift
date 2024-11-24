//
//  SegmentedView.swift
//  Accelerometre
//
//  Created by digital on 24/10/2024.
//

import SwiftUI

struct SegmentedView: View {
    
    var values:[String]
    
    @Binding var selectedValue:String
    
    var body: some View {
        HStack{
            ForEach(values, id: \.self) { value in
                Spacer()
                ZStack{
                    Rectangle()
                        .fill(value == selectedValue ? .blue : .clear)
                        .clipShape(.capsule)
                    Text(value)
                }.onTapGesture {
                    selectedValue = value
                }
            }
            Spacer()
        }
    }
}
