//
//  LiquidGlassTabBar.swift
//  UnderBro iOS
//
//  Barra de navegación inferior flotante con Liquid Glass nativo (iOS 26+).
//  Aprovecha GlassEffectContainer continuo, .glassEffect() con morphing declarativo
//  mediante .glassEffectID(_:in:) y tintes dinámicos.
//

import SwiftUI

public enum MainTab: String, CaseIterable, Identifiable {
    case stream = "Stream"
    case fotos = "Fotos"
    case yo = "Yo"
    case chat = "Chat"
    case subir = "Subir"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .stream: return "play.circle.fill"
        case .fotos: return "camera.fill"
        case .yo: return "person.crop.circle.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .subir: return "plus"
        }
    }
}

public struct LiquidGlassTabBar: View {
    @Binding public var selectedTab: MainTab
    public var onUploadTapped: (() -> Void)? = nil
    @Namespace private var tabNamespace
    
    public init(selectedTab: Binding<MainTab>, onUploadTapped: (() -> Void)? = nil) {
        self._selectedTab = selectedTab
        self.onUploadTapped = onUploadTapped
    }
    
    public var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(MainTab.allCases) { tab in
                    tabItemButton(for: tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
    
    // MARK: - Botón con Superficie y Morphing de Cristal Líquido Nativo
    
    @ViewBuilder
    private func tabItemButton(for tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        
        Button {
            if tab == .subir {
                onUploadTapped?()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedTab = tab
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.iconName)
                    .font(.system(size: tab == .subir ? 19 : 18, weight: isSelected ? .bold : .medium))
                    .frame(height: 22)
                
                Text(tab.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : UBTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .glassEffect(.regular.tint(UBTheme.accentEnd).interactive(), in: .capsule)
                        .glassEffectID(tab, in: tabNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct LiquidGlassTabBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                LiquidGlassTabBar(selectedTab: .constant(.stream))
            }
        }
    }
}
