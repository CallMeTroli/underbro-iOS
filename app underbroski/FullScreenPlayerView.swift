//
//  FullScreenPlayerView.swift
//  UnderBro iOS
//
//  Reproductor a pantalla completa adaptado con las APIs nativas de Liquid Glass de iOS 26+:
//  GlassEffectContainer, .glassEffect() y estilos de botón .glass y .glassProminent.
//

import SwiftUI

public struct FullScreenPlayerView: View {
    @ObservedObject var player: AudioPlayerService = .shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLiked: Bool = false
    @State private var likesCount: Int = 39
    @State private var commentsCount: Int = 4
    
    public init() {}
    
    public var body: some View {
        ZStack {
            UBTheme.backgroundDark.ignoresSafeArea()
            
            // Resplandor ambiental de fondo dinámico
            ambientBackgroundGlow
            
            VStack(spacing: 20) {
                // Barra superior de cierre
                topDismissBar
                
                Spacer(minLength: 4)
                
                // Portada Gigante 1:1 con Liquid Glass y reflejo
                artworkCard
                    .padding(.horizontal, 28)
                
                // Título de la pista y Artista
                trackMetadataView
                
                // Píldoras de interacción social (Likes, Comentarios, Compartir) con GlassEffectContainer
                socialPillsRow
                
                // Visualizador de Onda de Audio y Duración
                waveformScrubberSection
                    .padding(.horizontal, 24)
                
                // Botonera de control de reproducción con GlassEffectContainer nativo
                playbackControlsDock
                
                // Selector de Velocidad de reproducción (1x, 1.25x, 1.5x, etc.)
                speedPillButton
                
                Spacer(minLength: 12)
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .onAppear {
            if let track = player.currentTrack {
                self.isLiked = track.isLiked
                self.likesCount = track.likesCount
                self.commentsCount = track.commentsCount
            }
        }
    }
    
    // MARK: - Barra Superior de Cierre
    
    private var topDismissBar: some View {
        HStack {
            Button {
                player.isFullScreenPresented = false
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Tarjeta de Arte de Portada (Obligatoriamente tamaño 1:1 manteniendo corner radius 32)
    
    private var artworkCard: some View {
        Color.clear
            .aspectRatio(1.0, contentMode: .fit)
            .frame(maxWidth: 380, maxHeight: 380)
            .overlay {
                ZStack {
                    if let track = player.currentTrack {
                        AsyncCoverImageView(
                            url: track.coverURL,
                            fallbackStyle: .vibrantGold,
                            titleHint: track.title,
                            cornerRadius: 32,
                            isSquare: true
                        )
                    } else {
                        PlaceholderArtworkView(style: .vibrantGold, cornerRadius: 32)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 12)
            .shadow(color: UBTheme.accentStart.opacity(0.35), radius: 36, x: 0, y: 16)
    }
    
    // MARK: - Metadatos de la Pista
    
    private var trackMetadataView: some View {
        VStack(spacing: 6) {
            Text(player.currentTrack?.title ?? "###sol")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(UBTheme.textPrimary)
            
            Text(player.currentTrack?.fullAuthorDisplay ?? "kkikheroina")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [UBTheme.accentEnd, UBTheme.accentCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
    
    // MARK: - Píldoras Sociales Nativas
    
    private var socialPillsRow: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                // Píldora de Like
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLiked.toggle()
                        likesCount += isLiked ? 1 : -1
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundStyle(isLiked ? UBTheme.accentPink : .white)
                        Text("\(likesCount)")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.glass)
                
                // Píldora de Comentarios
                Button {
                    // Abrir comentarios
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left")
                        Text("\(commentsCount)")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .buttonStyle(.glass)
                
                // Píldora de Compartir
                Button {
                    // Compartir
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.glass)
            }
        }
    }
    
    // MARK: - Onda de Audio y Tiempos
    
    private var waveformScrubberSection: some View {
        VStack(spacing: 8) {
            WaveformView(
                samples: player.currentTrack?.waveformSamples?.map { CGFloat($0) },
                progress: player.progressRatio,
                barWidth: 3.5,
                barSpacing: 2.2,
                activeColor: .white,
                inactiveColor: Color.white.opacity(0.28),
                showScrubberHandle: true,
                onSeek: { progress in
                    player.seek(to: progress)
                }
            )
            .frame(height: 54)
            
            HStack {
                Text(player.formattedCurrentTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(UBTheme.textSecondary)
                
                Spacer()
                
                Text(player.currentTrack?.formattedDuration ?? "1:02")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(UBTheme.textSecondary)
            }
        }
    }
    
    // MARK: - Botonera de Control de Reproducción Nativa
    
    private var playbackControlsDock: some View {
        GlassEffectContainer(spacing: 20) {
            HStack(spacing: 20) {
                // Modo aleatorio (Shuffle)
                Button {
                    player.isShuffleEnabled.toggle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 16))
                        .foregroundStyle(player.isShuffleEnabled ? UBTheme.accentCyan : .white.opacity(0.8))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
                
                // Pista anterior
                Button {
                    player.previousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glass)
                
                // Play / Pause Principal con estilo prominente
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(UBTheme.accentEnd)
                
                // Pista siguiente
                Button {
                    player.nextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glass)
                
                // Repetición en bucle (Repeat)
                Button {
                    player.isRepeatEnabled.toggle()
                } label: {
                    Image(systemName: "repeat")
                        .font(.system(size: 16))
                        .foregroundStyle(player.isRepeatEnabled ? UBTheme.accentCyan : .white.opacity(0.8))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.glass)
            }
        }
    }
    
    // MARK: - Botón Selector de Velocidad
    
    private var speedPillButton: some View {
        Button {
            player.togglePlaybackSpeed()
        } label: {
            Text(player.playbackSpeed.title)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
        }
        .buttonStyle(.glass)
    }
    
    // MARK: - Resplandor Ambiental
    
    private var ambientBackgroundGlow: some View {
        GeometryReader { geo in
            Circle()
                .fill(UBTheme.accentStart.opacity(0.22))
                .frame(width: geo.size.width * 0.9)
                .blur(radius: 70)
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.35)
        }
        .allowsHitTesting(false)
    }
}

struct FullScreenPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let _ = {
            let player = AudioPlayerService.shared
            player.currentTrack = Track(
                id: "preview-fs-1",
                title: "###sol",
                author: "kkikheroina",
                coverURL: nil,
                durationSeconds: 154,
                likesCount: 1420,
                commentsCount: 89,
                repostsCount: 312,
                badge: "N.º 1 AHORA MISMO",
                isFeatured: true
            )
            player.isPlaying = true
        }()
        
        return FullScreenPlayerView()
    }
}
