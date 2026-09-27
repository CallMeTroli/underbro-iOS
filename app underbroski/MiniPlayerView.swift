//
//  MiniPlayerView.swift
//  UnderBro iOS
//
//  Mini-reproductor flotante anclado con .glassEffect() nativo de iOS 26+
//  y controles agrupados con GlassEffectContainer.
//

import SwiftUI

public struct MiniPlayerView: View {
    @ObservedObject var player: AudioPlayerService = .shared
    
    public init() {}
    
    public var body: some View {
        if let track = player.currentTrack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Portada pequeña con efecto squircle
                    AsyncCoverImageView(
                        url: track.coverURL,
                        fallbackStyle: .vibrantGold,
                        titleHint: track.title,
                        cornerRadius: 12
                    )
                    .frame(width: 44, height: 44)
                    
                    // Título y Artista
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(UBTheme.textPrimary)
                            .lineLimit(1)
                        
                        Text(track.author)
                            .font(.caption)
                            .foregroundStyle(UBTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Controles de reproducción rápida nativos en GlassEffectContainer
                    GlassEffectContainer(spacing: 8) {
                        HStack(spacing: 8) {
                            // Anterior
                            Button {
                                player.previousTrack()
                            } label: {
                                Image(systemName: "backward.end.fill")
                                    .font(.system(size: 13))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.glass)
                            
                            // Play / Pause con estilo prominente
                            Button {
                                player.togglePlayPause()
                            } label: {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 15, weight: .bold))
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.glassProminent)
                            .tint(UBTheme.accentEnd)
                            
                            // Siguiente
                            Button {
                                player.nextTrack()
                            } label: {
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 13))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.glass)
                            
                            // Cerrar
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    player.dismissPlayer()
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(width: 14, height: 14)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                // Barra delgada de progreso en la base del mini-reproductor
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 2.5)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [UBTheme.accentStart, UBTheme.accentCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(player.progressRatio), height: 2.5)
                            .animation(.linear(duration: 0.25), value: player.progressRatio)
                    }
                }
                .frame(height: 2.5)
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.35), radius: 15, x: 0, y: 6)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .onTapGesture {
                player.isFullScreenPresented = true
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct MiniPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let _ = {
            let player = AudioPlayerService.shared
            player.currentTrack = Track(
                id: "preview-1",
                title: "UNDERB...",
                author: "neegy",
                coverURL: nil,
                durationSeconds: 160,
                likesCount: 1420,
                commentsCount: 89,
                repostsCount: 312,
                badge: "N.º 1",
                isFeatured: true
            )
            player.isPlaying = true
        }()
        
        return ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                MiniPlayerView()
                    .padding(.bottom, 20)
            }
        }
    }
}
