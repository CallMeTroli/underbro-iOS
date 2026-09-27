//
//  CompactTrackCard.swift
//  UnderBro iOS
//
//  Tarjeta de pista compacta (#2 MALA, etc.) con diseño Liquid Glass nativo de iOS 26+,
//  utilizando .glassEffect() en tarjetas, rangos numéricos y tags de género.
//

import SwiftUI

public struct CompactTrackCard: View {
    public let track: Track
    @ObservedObject var player: AudioPlayerService = .shared
    
    public init(track: Track) {
        self.track = track
    }
    
    private var isCurrentTrackPlaying: Bool {
        player.currentTrack?.id == track.id && player.isPlaying
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Portada con rango numérico superpuesto en cristal nativo
            ZStack(alignment: .topLeading) {
                AsyncCoverImageView(
                    url: track.coverURL,
                    fallbackStyle: .deepIndigo,
                    titleHint: track.title,
                    cornerRadius: 16
                )
                .frame(width: 80, height: 80)
                
                if let rank = track.rank {
                    Text("\(rank)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(8)
                        .glassEffect(.regular, in: .circle)
                        .padding(4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Información central
            VStack(alignment: .leading, spacing: 5) {
                // Etiqueta de género con tinte de cristal nativo
                if let genre = track.genre {
                    Text(genre)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassEffect(.regular.tint(UBTheme.accentCyan), in: .capsule)
                }
                
                // Título
                Text(track.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(UBTheme.textPrimary)
                    .lineLimit(1)
                
                // Artista(s)
                Text("por \(track.fullAuthorDisplay)")
                    .font(.caption)
                    .foregroundStyle(UBTheme.textSecondary)
                    .lineLimit(1)
                
                // Indicador de duración y reproducciones
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "headphones")
                        Text("\(track.playsCount)")
                    }
                    Text("•")
                    Text(track.formattedDuration)
                }
                .font(.caption2)
                .foregroundStyle(UBTheme.textTertiary)
            }
            
            Spacer()
            
            // Botón de reproducción rápida con estilo nativo
            if isCurrentTrackPlaying {
                Button {
                    player.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glassProminent)
                .tint(UBTheme.accentEnd)
            } else {
                Button {
                    player.playTrack(track)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            player.playTrack(track)
            player.isFullScreenPresented = true
        }
    }
}
