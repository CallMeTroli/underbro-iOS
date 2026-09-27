//
//  LiquidGlassTheme.swift
//  UnderBro iOS
//
//  Sistema de diseño nativo "Liquid Glass" de iOS 26 / iOS 27.
//  Aprovecha el soporte de primera clase de Apple para:
//    - GlassEffectContainer: contenedor continuo de cristal
//    - .glassEffect(): superficies ópticas translúcidas con tintes dinámicos
//    - .buttonStyle(.glass) y .buttonStyle(.glassProminent): controles de cristal hápticos
//    - .glassEffectID(_:in:): morphing declarativo entre vistas
//

import SwiftUI

// MARK: - Tokens de Color & Gradientes

public enum UBTheme {
    // Fondos espaciales oscuros
    public static let backgroundDark = Color(red: 0.04, green: 0.04, blue: 0.08)
    public static let surfaceDark = Color(red: 0.08, green: 0.09, blue: 0.15)
    public static let surfaceElevated = Color(red: 0.12, green: 0.14, blue: 0.22)
    
    // Gradiente Primario UnderBro (Violeta Eléctrico -> Azul Neón)
    public static let accentStart = Color(red: 0.42, green: 0.36, blue: 0.98) // #6B5CFA
    public static let accentEnd = Color(red: 0.28, green: 0.58, blue: 0.98)   // #4794FA
    public static let accentCyan = Color(red: 0.20, green: 0.85, blue: 0.95)  // #33D9F2
    public static let accentPink = Color(red: 0.95, green: 0.25, blue: 0.55)  // #F2408C
    public static let accentOrange = Color(red: 1.0, green: 0.45, blue: 0.18) // #FF732E
    public static let accentGold = Color(red: 1.0, green: 0.84, blue: 0.0)    // #FFD700
    
    // Textos
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.60)
    public static let textTertiary = Color.white.opacity(0.35)
    
    // Gradientes de marca
    public static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accentStart, accentEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    public static var glassBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.35),
                Color.white.opacity(0.10),
                Color.white.opacity(0.02),
                Color.white.opacity(0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Utilidades de Brillo Dinámico

public extension View {
    /// Aplica un aura o resplandor dinámico de luz sobre el elemento
    func dynamicGlow(color: Color = UBTheme.accentStart, radius: CGFloat = 20, opacity: Double = 0.45) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 8)
    }
}
