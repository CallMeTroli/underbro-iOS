//
//  SegmentedPillBar.swift
//  UnderBro iOS
//
//  Barra de pestañas segmentada con GlassEffectContainer nativo de iOS 26+
//  y morphing de cristal mediante .glassEffectID(_:in:).
//

import SwiftUI

public struct SegmentedPillBar: View {
    @Binding public var selectedSegment: FeedSegment
    @Namespace private var segmentNamespace
    
    public init(selectedSegment: Binding<FeedSegment>) {
        self._selectedSegment = selectedSegment
    }
    
    public var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(FeedSegment.allCases) { segment in
                    let isSelected = selectedSegment == segment
                    
                    Text(segment.rawValue)
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : UBTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .glassEffect(.regular.tint(UBTheme.accentStart).interactive(), in: .capsule)
                                    .glassEffectID(segment, in: segmentNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedSegment = segment
                            }
                        }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
