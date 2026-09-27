//
//  PlaceholderComponents.swift
//  UnderBro iOS
//
//  Componentes visuales de reemplazo elegante (placeholders) para portadas,
//  avatares de historias y medios gráficos antes de conectar con el CDN/servidor.
//

import SwiftUI

// MARK: - Placeholder de Portadas de Canciones / Álbumes

public struct PlaceholderArtworkView: View {
    public enum Style {
        case vibrantGold
        case deepIndigo
        case neonCyan
        case emeraldDark
        case custom([Color])
        
        var colors: [Color] {
            switch self {
            case .vibrantGold:
                return [Color(red: 0.85, green: 0.35, blue: 0.25), Color(red: 0.95, green: 0.65, blue: 0.20), Color(red: 0.35, green: 0.15, blue: 0.45)]
            case .deepIndigo:
                return [Color(red: 0.18, green: 0.12, blue: 0.35), Color(red: 0.10, green: 0.25, blue: 0.55), Color(red: 0.05, green: 0.05, blue: 0.15)]
            case .neonCyan:
                return [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.10, green: 0.85, blue: 0.80), Color(red: 0.30, green: 0.10, blue: 0.60)]
            case .emeraldDark:
                return [Color(red: 0.10, green: 0.40, blue: 0.30), Color(red: 0.05, green: 0.20, blue: 0.25), Color(red: 0.02, green: 0.05, blue: 0.10)]
            case .custom(let colors):
                return colors
            }
        }
    }
    
    public var style: Style = .vibrantGold
    public var titleHint: String? = nil
    public var systemIcon: String = "music.note"
    public var cornerRadius: CGFloat = 20
    
    public init(
        style: Style = .vibrantGold,
        titleHint: String? = nil,
        systemIcon: String = "music.note",
        cornerRadius: CGFloat = 20
    ) {
        self.style = style
        self.titleHint = titleHint
        self.systemIcon = systemIcon
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        ZStack {
            // Fondo con degradado fluido tipo malla
            LinearGradient(
                colors: style.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Textura visual abstracta de cristal líquido
            RadialGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 200
            )
            
            // Icono sutil de fondo
            VStack {
                Image(systemName: systemIcon)
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.35))
                
                if let title = titleHint {
                    Text(title)
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.40))
                        .padding(.top, 4)
                }
            }
            
            // Reflejo especular superior para dar sensación física de cristal templado
            LinearGradient(
                colors: [Color.white.opacity(0.25), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.overlay)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Placeholder de Avatar de Usuario e Historias

public struct PlaceholderAvatarView: View {
    public var username: String
    public var size: CGFloat = 64
    public var hasNewStory: Bool = false
    public var isMe: Bool = false
    public var isVerified: Bool = false
    
    public init(
        username: String,
        size: CGFloat = 64,
        hasNewStory: Bool = false,
        isMe: Bool = false,
        isVerified: Bool = false
    ) {
        self.username = username
        self.size = size
        self.hasNewStory = hasNewStory
        self.isMe = isMe
        self.isVerified = isVerified
    }
    
    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Anillo exterior de la historia
            Circle()
                .strokeBorder(
                    hasNewStory
                    ? AnyShapeStyle(LinearGradient(
                        colors: [UBTheme.accentPink, UBTheme.accentOrange, UBTheme.accentEnd, UBTheme.accentCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    : AnyShapeStyle(Color.white.opacity(0.18)),
                    lineWidth: hasNewStory ? 2.8 : 1.5
                )
                .frame(width: size, height: size)
                .overlay {
                    // Contenido del avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.25, green: 0.25, blue: 0.38),
                                    Color(red: 0.15, green: 0.15, blue: 0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(hasNewStory ? 4 : 2)
                        .overlay {
                            avatarContent
                        }
                }
            
            // Insignia (+) para "Tu historia"
            if isMe {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: size * 0.32))
                    .foregroundStyle(.white, UBTheme.accentEnd)
                    .background(Circle().fill(UBTheme.backgroundDark).padding(1))
                    .offset(x: 2, y: 2)
            }
        }
    }
    
    @ViewBuilder
    private var avatarContent: some View {
        if isMe {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.85))
                .padding(size * 0.12)
        } else {
            // Inicial de usuario con tipografía futurista
            Text(username.prefix(1).uppercased())
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(UBTheme.textPrimary)
        }
    }
}

// MARK: - Vista genérica para Portadas Asíncronas con Fallback a Placeholder

public struct AsyncCoverImageView: View {
    public let url: URL?
    public var fallbackStyle: PlaceholderArtworkView.Style = .vibrantGold
    public var titleHint: String? = nil
    public var cornerRadius: CGFloat = 20
    public var isSquare: Bool = false
    
    public init(
        url: URL?,
        fallbackStyle: PlaceholderArtworkView.Style = .vibrantGold,
        titleHint: String? = nil,
        cornerRadius: CGFloat = 20,
        isSquare: Bool = false
    ) {
        self.url = url
        self.fallbackStyle = fallbackStyle
        self.titleHint = titleHint
        self.cornerRadius = cornerRadius
        self.isSquare = isSquare
    }
    
    public var body: some View {
        if let url = url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    GeometryReader { geo in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .aspectRatio(isSquare ? 1.0 : nil, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                case .empty, .failure:
                    PlaceholderArtworkView(
                        style: fallbackStyle,
                        titleHint: titleHint,
                        cornerRadius: cornerRadius
                    )
                @unknown default:
                    PlaceholderArtworkView(
                        style: fallbackStyle,
                        titleHint: titleHint,
                        cornerRadius: cornerRadius
                    )
                }
            }
        } else {
            PlaceholderArtworkView(
                style: fallbackStyle,
                titleHint: titleHint,
                cornerRadius: cornerRadius
            )
        }
    }
}
