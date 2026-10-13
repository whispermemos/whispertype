//
//  DevBadge.swift
//  WhisperType
//
//  Created by Vojtech Rinik on 03/03/2025.
//

import SwiftUI

struct DevBadge: View {
    var body: some View {
        Text(getEnv())
            .foregroundStyle(Color.red.opacity(0.8))
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.red.opacity(0.2))
            .cornerRadius(4)
    }
}
