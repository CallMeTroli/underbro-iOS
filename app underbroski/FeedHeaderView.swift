//
//  FeedHeaderView.swift
//  UnderBro iOS
//
//  Cabecera superior de la aplicación utilizando el contenedor nativo
//  GlassEffectContainer y estilos de botón .buttonStyle(.glass) de iOS 26+.
//

import SwiftUI

public struct FeedHeaderView: View {
    public var onSearchTapped: (() -> Void)? = nil
    public var onNotificationsTapped: (() -> Void)? = nil
    public var onProfileTapped: (() -> Void)? = nil
    
    public init(
        onSearchTapped: (() -> Void)? = nil,
        onNotificationsTapped: (() -> Void)? = nil,
        onProfileTapped: (() -> Void)? = nil
    ) {
        self.onSearchTapped = onSearchTapped
        self.onNotificationsTapped = onNotificationsTapped
        self.onProfileTapped = onProfileTapped
    }
    
    public var body: some View {
        HStack(alignment: .center) {
            // Logotipo UnderBro
            HStack(spacing: 0) {
                Text("Under")
                    .foregroundStyle(.white)
                Text("Bro")
                    .foregroundStyle(UBTheme.brandGradient)
            }
            .font(.system(size: 26, weight: .heavy, design: .rounded))
            
            Spacer()
            
            // Botones de acción flotantes con GlassEffectContainer nativo de iOS 26
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    // Buscar
                    Button {
                        onSearchTapped?()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.glass)
                    
                    // Notificaciones
                    Button {
                        onNotificationsTapped?()
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.glass)
                    
                    // Perfil
                    Button {
                        onProfileTapped?()
                    } label: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}
