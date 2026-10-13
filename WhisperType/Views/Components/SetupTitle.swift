//
//  SetupTitle.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 18/02/2025.
//

import SwiftUI

struct SetupTitle: View {
    let title: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(title)
            .font(.title)
            .fontWeight(.medium)
            .foregroundColor(colorScheme == .dark ? .white : .black)
    }
}
