//
//  AnimatedFace.swift
//
//  Closed-notch brand mark (replaces the old smile face).
//

import SwiftUI

/// Diamante wordmark — name only (diamond sits separately on the trailing edge).
struct DiamanteNameMark: View {
    var height: CGFloat = 20
    var compact: Bool = true

    var body: some View {
        Text("Diamante")
            .font(.system(size: compact ? 11 : 16, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .foregroundStyle(.white)
            .frame(height: height)
            .accessibilityLabel("Diamante")
    }
}

/// Diamond glyph for the closed-notch trailing edge.
struct DiamanteDiamondMark: View {
    var height: CGFloat = 20
    var compact: Bool = true

    var body: some View {
        Image(systemName: "diamond.fill")
            .font(.system(size: compact ? 10 : 22, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: compact ? 18 : 28, height: height)
            .accessibilityHidden(true)
    }
}

/// Combined mark for EmptyState / previews.
struct DiamanteBrandMark: View {
    var height: CGFloat = 20
    var compact: Bool = true

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            DiamanteNameMark(height: height, compact: compact)
            DiamanteDiamondMark(height: height, compact: compact)
        }
        .accessibilityLabel("Diamante")
    }
}

/// Kept for EmptyState and any call sites that still expect the old face API.
struct MinimalFaceFeatures: View {
    @State var height: CGFloat = 20
    @State var width: CGFloat = 30

    var body: some View {
        DiamanteBrandMark(height: height, compact: width < 50)
            .frame(width: max(width, 90), height: height)
    }
}

#Preview {
    ZStack {
        Color.black
        DiamanteBrandMark()
    }
    .frame(width: 160, height: 40)
}
