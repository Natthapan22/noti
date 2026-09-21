//
//  AnimatedFace.swift
//
//  Closed-notch brand mark (replaces the old smile face).
//

import SwiftUI

/// Diamante mark shown in the closed notch when idle.
struct DiamanteBrandMark: View {
    var height: CGFloat = 20
    var compact: Bool = true

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            Image(systemName: "diamond.fill")
                .font(.system(size: compact ? 9 : 22, weight: .semibold))
                .symbolRenderingMode(.hierarchical)

            Text("Diamante")
                .font(.system(size: compact ? 10 : 16, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .frame(height: height)
        .accessibilityLabel("Diamante")
    }
}

/// Kept for EmptyState and any call sites that still expect the old face API.
struct MinimalFaceFeatures: View {
    @State var height: CGFloat = 20
    @State var width: CGFloat = 30

    var body: some View {
        DiamanteBrandMark(height: height, compact: width < 50)
            .frame(width: max(width, 72), height: height)
    }
}

#Preview {
    ZStack {
        Color.black
        DiamanteBrandMark()
    }
    .frame(width: 120, height: 40)
}
