//
//  AudioPlayerService.swift
//  UnderBro iOS
//
//  Servicio centralizado de audio y estado de reproducción.
//  Controla tanto el mini-reproductor flotante como el reproductor a pantalla completa,
//  con soporte para streaming AVPlayer y simulación interactiva con temporizador.
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
public final class AudioPlayerService: ObservableObject {
    public static let shared = AudioPlayerService()
    
    // MARK: - Estado Publicado (Observable)
    
    @Published public var currentTrack: Track? = nil
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 63.0
    @Published public var playbackSpeed: PlaybackSpeed = .normal
    @Published public var isShuffleEnabled: Bool = false
    @Published public var isRepeatEnabled: Bool = false
    @Published public var isFullScreenPresented: Bool = false
    
    // Cola de reproducción
    @Published public var playlist: [Track] = []
    @Published public var currentIndex: Int = 0
    
    // MARK: - Propiedades Internas
    
    private var avPlayer: AVPlayer? = nil
    private var playbackTimer: AnyCancellable? = nil
    
    public init() {
        setupAudioSession()
    }
    
    // MARK: - Configuración de Sesión de Audio
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[UnderBro Audio] No se pudo inicializar AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Control de Reproducción
    
    /// Carga una pista y comienza la reproducción
    public func playTrack(_ track: Track, from list: [Track] = []) {
        if !list.isEmpty {
            self.playlist = list
            if let index = list.firstIndex(where: { $0.id == track.id }) {
                self.currentIndex = index
            }
        } else if !playlist.contains(where: { $0.id == track.id }) {
            self.playlist.append(track)
            self.currentIndex = self.playlist.count - 1
        }
        
        self.currentTrack = track
        self.duration = Double(track.durationSeconds)
        self.currentTime = 0.0
        
        // Conexión con stream real si existe URL remota
        if let streamURL = track.audioStreamURL {
            let playerItem = AVPlayerItem(url: streamURL)
            self.avPlayer = AVPlayer(playerItem: playerItem)
            self.avPlayer?.rate = Float(playbackSpeed.rawValue)
            self.avPlayer?.play()
        }
        
        self.isPlaying = true
        startProgressTimer()
    }
    
    /// Alterna entre reproducir y pausar
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    public func resume() {
        guard currentTrack != nil else { return }
        isPlaying = true
        avPlayer?.play()
        avPlayer?.rate = Float(playbackSpeed.rawValue)
        startProgressTimer()
    }
    
    public func pause() {
        isPlaying = false
        avPlayer?.pause()
        stopProgressTimer()
    }
    
    /// Salta a una posición porcentual de la pista (0.0 a 1.0)
    public func seek(to progress: Double) {
        let clamped = max(0.0, min(1.0, progress))
        let targetSeconds = duration * clamped
        self.currentTime = targetSeconds
        
        if let player = avPlayer {
            let targetCMTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
            player.seek(to: targetCMTime)
        }
    }
    
    /// Siguiente canción en la lista
    public func nextTrack() {
        guard !playlist.isEmpty else { return }
        
        if isShuffleEnabled {
            currentIndex = Int.random(in: 0..<playlist.count)
        } else {
            currentIndex = (currentIndex + 1) % playlist.count
        }
        
        playTrack(playlist[currentIndex], from: playlist)
    }
    
    /// Canción anterior o reiniciar si ya pasaron más de 3 segundos
    public func previousTrack() {
        if currentTime > 3.0 {
            seek(to: 0.0)
            return
        }
        
        guard !playlist.isEmpty else { return }
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = playlist.count - 1
        }
        
        playTrack(playlist[currentIndex], from: playlist)
    }
    
    /// Cierra y descarta el mini-reproductor
    public func dismissPlayer() {
        pause()
        currentTrack = nil
        isFullScreenPresented = false
    }
    
    /// Alterna la velocidad entre 0.75x, 1x, 1.25x, 1.5x, 2x
    public func togglePlaybackSpeed() {
        playbackSpeed.toggleNext()
        if isPlaying {
            avPlayer?.rate = Float(playbackSpeed.rawValue)
        }
    }
    
    // MARK: - Temporizador Simulado / Sincronizado
    
    private func startProgressTimer() {
        stopProgressTimer()
        
        playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                
                let step = 0.25 * self.playbackSpeed.rawValue
                let nextTime = self.currentTime + step
                
                if nextTime >= self.duration {
                    if self.isRepeatEnabled {
                        self.seek(to: 0.0)
                    } else {
                        self.nextTrack()
                    }
                } else {
                    self.currentTime = nextTime
                }
            }
    }
    
    private func stopProgressTimer() {
        playbackTimer?.cancel()
        playbackTimer = nil
    }
    
    // MARK: - Helpers de Formato
    
    public var formattedCurrentTime: String {
        let mins = Int(currentTime) / 60
        let secs = Int(currentTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var formattedRemainingTime: String {
        let remaining = max(0, duration - currentTime)
        let mins = Int(remaining) / 60
        let secs = Int(remaining) % 60
        return String(format: "-%d:%02d", mins, secs)
    }
    
    public var progressRatio: Double {
        guard duration > 0 else { return 0.0 }
        return min(1.0, max(0.0, currentTime / duration))
    }
}
