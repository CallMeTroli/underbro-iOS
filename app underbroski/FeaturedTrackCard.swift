//
//  FeaturedTrackCard.swift
//  UnderBro iOS
//
//  Tarjeta destacada (N.º 1) con diseño nativo Liquid Glass de iOS 26+,
//  utilizando .glassEffect(), .buttonStyle(.glassProminent) y reproductor integrado.
//

import SwiftUI

public struct FeaturedTrackCard: View {
    public let track: Track
    public var allTracks: [Track] = []
    @ObservedObject var player: AudioPlayerService = .shared
    
    public var onAuthorTapped: (() -> Void)? = nil
    
    @State private var isLiked: Bool
    @State private var likesCount: Int
    @State private var isReposted: Bool
    @State private var repostsCount: Int
    
    public init(track: Track, allTracks: [Track] = [], onAuthorTapped: (() -> Void)? = nil) {
        self.track = track
        self.allTracks = allTracks
        self.onAuthorTapped = onAuthorTapped
        _isLiked = State(initialValue: track.isLiked)
        _likesCount = State(initialValue: track.likesCount)
        _isReposted = State(initialValue: track.isReposted)
        _repostsCount = State(initialValue: track.repostsCount)
    }
    
    private var isCurrentTrackPlaying: Bool {
        player.currentTrack?.id == track.id && player.isPlaying
    }
    
    private var currentProgress: Double {
        if player.currentTrack?.id == track.id {
            return player.progressRatio
        }
        return 0.0
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Portada / Fondo con placeholder estilizado
            coverBackground
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            
            // Insignia Superior: N.º 1 AHORA MISMO con .glassEffect nativo
            VStack {
                HStack {
                    if let badge = track.badge {
                        Text(badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                    }
                    Spacer()
                }
                .padding(14)
                
                Spacer()
            }
            
            // Panel de Control Inferior: Metadatos, Onda y Acciones
            VStack(alignment: .leading, spacing: 12) {
                // Título y Autor
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(UBTheme.textPrimary)
                    
                    Button {
                        onAuthorTapped?()
                    } label: {
                        HStack(spacing: 5) {
                            Text("por \(track.author)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(UBTheme.textPrimary.opacity(0.9))
                            
                            if track.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(UBTheme.accentEnd)
                            }
                            
                            if track.isAlpha {
                                Text("α")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .glassEffect(.regular.tint(UBTheme.accentStart), in: .capsule)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if let tagline = track.tagline {
                        Text(tagline)
                            .font(.footnote)
                            .foregroundStyle(UBTheme.textSecondary)
                    }
                }
                
                // Reproductor con Botón Nativo .glassProminent y Onda
                HStack(spacing: 12) {
                    Button {
                        handlePlayButtonTapped()
                    } label: {
                        Image(systemName: isCurrentTrackPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentEnd)
                    
                    // Onda interactiva
                    WaveformView(
                        samples: track.waveformSamples?.map { CGFloat($0) },
                        progress: currentProgress,
                        activeColor: .white,
                        inactiveColor: Color.white.opacity(0.35),
                        showScrubberHandle: false,
                        onSeek: { newProgress in
                            if player.currentTrack?.id == track.id {
                                player.seek(to: newProgress)
                            } else {
                                player.playTrack(track, from: allTracks.isEmpty ? [track] : allTracks)
                                player.seek(to: newProgress)
                            }
                        }
                    )
                    .frame(height: 36)
                }
                
                // Fila de Estadísticas y Botones Sociales
                HStack(spacing: 16) {
                    // Duración y escuchas
                    HStack(spacing: 4) {
                        Image(systemName: "headphones")
                            .font(.caption)
                        Text("\(track.playsCount) · \(track.formattedDuration)")
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(UBTheme.textSecondary)
                    
                    Spacer()
                    
                    // Likes
                    Button {
                        toggleLike()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .foregroundStyle(isLiked ? UBTheme.accentPink : UBTheme.textSecondary)
                            Text("\(likesCount)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(isLiked ? .white : UBTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.glass)
                    
                    // Comentarios
                    Button {
                        player.playTrack(track, from: allTracks.isEmpty ? [track] : allTracks)
                        player.isFullScreenPresented = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .foregroundStyle(UBTheme.textSecondary)
                            Text("\(track.commentsCount)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(UBTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.glass)
                    
                    // Reposts
                    Button {
                        toggleRepost()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.2.squarepath")
                                .foregroundStyle(isReposted ? UBTheme.accentCyan : UBTheme.textSecondary)
                            Text("\(repostsCount)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(isReposted ? .white : UBTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.glass)
                    
                    // Más opciones (...) con .buttonStyle(.glass)
                    Menu {
                        Button("Compartir pista", systemImage: "square.and.arrow.up") {}
                        Button("Añadir a playlist", systemImage: "text.badge.plus") {}
                        Button("Copiar enlace", systemImage: "link") {}
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.glass)
                }
                .font(.footnote)
                .padding(.top, 4)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.65),
                        Color.black.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            UBTheme.accentStart.opacity(0.6),
                            UBTheme.accentEnd.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            player.playTrack(track, from: allTracks.isEmpty ? [track] : allTracks)
            player.isFullScreenPresented = true
        }
    }
    
    // MARK: - Subvistas
    
    @ViewBuilder
    private var coverBackground: some View {
        if let url = track.coverURL {
            AsyncCoverImageView(url: url, fallbackStyle: .vibrantGold, titleHint: track.title, cornerRadius: 24)
        } else {
            PlaceholderArtworkView(
                style: .vibrantGold,
                titleHint: track.title,
                systemIcon: "waveform.circle",
                cornerRadius: 24
            )
        }
    }
    
    // MARK: - Acciones
    
    private func handlePlayButtonTapped() {
        if player.currentTrack?.id == track.id {
            player.togglePlayPause()
        } else {
            player.playTrack(track, from: allTracks.isEmpty ? [track] : allTracks)
        }
    }
    
    private func toggleLike() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked.toggle()
            likesCount += isLiked ? 1 : -1
        }
    }
    
    private func toggleRepost() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isReposted.toggle()
            repostsCount += isReposted ? 1 : -1
        }
    }
}
