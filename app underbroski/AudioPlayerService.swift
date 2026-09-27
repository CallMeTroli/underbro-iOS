//
//  AudioPlayerService.swift
//  UnderBro iOS
//
//  Servicio centralizado de audio y estado de reproducción con soporte completo
//  para reproducción en segundo plano (Background Audio), controles remotos de hardware
//  (MPRemoteCommandCenter), metadatos de bloqueo y Dynamic Island (MPNowPlayingInfoCenter),
//  gestión de interrupciones de audio (llamadas, Siri), desconexión de auriculares
//  y fallback silencioso en bucle para pistas offline/simuladas.
//

import SwiftUI
import AVFoundation
import MediaPlayer
import Combine
#if canImport(UIKit)
import UIKit
#endif

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
    
    // MARK: - Propiedades Internas de Audio y Background
    
    private var avPlayer: AVPlayer? = nil
    private var timeObserverToken: Any? = nil
    private var playerItemEndObserver: NSObjectProtocol? = nil
    private var silentAudioPlayer: AVAudioPlayer? = nil
    private var playbackTimer: AnyCancellable? = nil
    
    // Anclas de tiempo para sincronización milimétrica al volver de background
    private var playbackAnchorTime: Date? = nil
    private var playbackAnchorPosition: Double = 0.0
    private var wasInterrupted: Bool = false
    
    // Carátula de Now Playing
    #if os(iOS)
    private var currentArtworkImage: UIImage? = nil
    private var artworkTask: Task<Void, Never>? = nil
    #endif
    
    public init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        setupSessionObservers()
        setupLifecycleObservers()
    }
    
    // MARK: - Configuración de Sesión de Audio
    
    private func setupAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            activateAudioSessionAsync()
            UIApplication.shared.beginReceivingRemoteControlEvents()
        } catch {
            print("[UnderBro Audio] No se pudo inicializar AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }
    
    // MARK: - Activación y Desactivación Asíncrona (Prevención de UI Hang Risk)
    
    private func activateAudioSessionAsync() {
        #if os(iOS)
        if #available(iOS 27.0, *) {
            AVAudioSession.sharedInstance().activate(options: []) { _, error in
                if let error = error {
                    print("[UnderBro Audio] Error activando AVAudioSession de forma asíncrona: \(error.localizedDescription)")
                }
            }
        } else {
            Task.detached(priority: .userInitiated) {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("[UnderBro Audio] Error activando AVAudioSession: \(error.localizedDescription)")
                }
            }
        }
        #endif
    }
    
    private func deactivateAudioSessionAsync() {
        #if os(iOS)
        if #available(iOS 27.0, *) {
            AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) { _, error in
                if let error = error {
                    print("[UnderBro Audio] Error desactivando AVAudioSession de forma asíncrona: \(error.localizedDescription)")
                }
            }
        } else {
            Task.detached(priority: .background) {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    print("[UnderBro Audio] Error desactivando AVAudioSession: \(error.localizedDescription)")
                }
            }
        }
        #endif
    }
    
    // MARK: - Manejo de Interrupciones y Cambio de Ruta
    
    private func setupSessionObservers() {
        #if os(iOS)
        // Interrupciones de audio y desactivación de sesión (iOS 27+)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.didBecomeInactiveNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isPlaying {
                    self.wasInterrupted = true
                    self.pause()
                }
            }
        }
        
        // Notificación de recomendación de reanudación del sistema tras la interrupción (iOS 27+)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.resumptionRecommendationNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let context = notification.userInfo?[AVAudioSession.resumptionContextKey] as? AVAudioSession.ResumptionContext
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.wasInterrupted && context?.recommendation == .shouldResume {
                    self.wasInterrupted = false
                    self.resume()
                }
            }
        }
        
        // Cambio de salida de audio (desconexión de auriculares o Bluetooth)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            
            Task { @MainActor [weak self] in
                guard let self = self,
                      let reasonValue = reasonValue,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                    return
                }
                
                if reason == .oldDeviceUnavailable {
                    // Se desenchufaron auriculares / se desconectó Bluetooth: pausar automáticamente
                    if self.isPlaying {
                        self.pause()
                    }
                }
            }
        }
        #endif
    }
    
    // MARK: - Observadores de Ciclo de Vida de la App
    
    private func setupLifecycleObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.playbackAnchorTime = Date()
                self.playbackAnchorPosition = self.currentTime
                self.updateNowPlayingInfo()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.syncElapsedPositionIfNeeded()
                self.playbackAnchorTime = Date()
                self.playbackAnchorPosition = self.currentTime
                self.updateNowPlayingInfo()
            }
        }
        #endif
    }
    
    // MARK: - Configuración de Centro de Control y Pantalla de Bloqueo (MPRemoteCommandCenter)
    
    private func setupRemoteCommandCenter() {
        #if os(iOS)
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Comando Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.resume()
            }
            return .success
        }
        
        // Comando Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
        
        // Comando Toggle Play/Pause (AirPods, auriculares con cable)
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }
        
        // Comando Siguiente Pista
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.nextTrack()
            }
            return .success
        }
        
        // Comando Pista Anterior
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previousTrack()
            }
            return .success
        }
        
        // Barra de desplazamiento interactiva en pantalla de bloqueo
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                let targetSec = positionEvent.positionTime
                let ratio = self.duration > 0 ? (targetSec / self.duration) : 0.0
                self.seek(to: ratio)
            }
            return .success
        }
        
        // Comando Me Gusta
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                guard let self = self, var track = self.currentTrack else { return }
                track.isLiked.toggle()
                track.likesCount += track.isLiked ? 1 : -1
                self.currentTrack = track
                commandCenter.likeCommand.isActive = track.isLiked
            }
            return .success
        }
        #endif
    }
    
    // MARK: - Actualización de Metadatos en Bloqueo y Dynamic Island (MPNowPlayingInfoCenter)
    
    public func updateNowPlayingInfo() {
        #if os(iOS)
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        // Establecer estado de reproducción para que la Isla Dinámica y la pantalla de bloqueo sincronicen el estado
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.fullAuthorDisplay
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "UnderBro"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed.rawValue : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = false
        
        if let artworkImage = currentArtworkImage {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artworkImage.size) { _ in
                return artworkImage
            }
        } else {
            let placeholder = makeFallbackArtwork(title: track.title, author: track.author)
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: placeholder.size) { _ in
                return placeholder
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }
    
    // MARK: - Carga de Portada y Generador de Placeholder
    
    #if os(iOS)
    private func loadArtwork(for track: Track) {
        artworkTask?.cancel()
        currentArtworkImage = makeFallbackArtwork(title: track.title, author: track.author)
        updateNowPlayingInfo()
        
        guard let url = track.coverURL else { return }
        
        artworkTask = Task { [weak self] in
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let image = UIImage(data: data) else {
                    return
                }
                
                await MainActor.run {
                    guard let self = self, self.currentTrack?.id == track.id else { return }
                    self.currentArtworkImage = image
                    self.updateNowPlayingInfo()
                }
            } catch {
                // Conserva el placeholder de alta fidelidad generado
            }
        }
    }
    
    private func makeFallbackArtwork(title: String, author: String) -> UIImage {
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            
            // Fondo oscuro estelar
            let colors = [
                UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1.0).cgColor
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
            }
            
            // Tarjeta central redondeada translúcida
            let cardRect = CGRect(x: 56, y: 56, width: 400, height: 400)
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 40)
            UIColor(white: 1.0, alpha: 0.07).setFill()
            cardPath.fill()
            
            UIColor(white: 1.0, alpha: 0.12).setStroke()
            cardPath.lineWidth = 2.0
            cardPath.stroke()
            
            // Icono musical con tinte dorado
            let config = UIImage.SymbolConfiguration(pointSize: 110, weight: .bold)
            if let noteImage = UIImage(systemName: "music.note.list", withConfiguration: config)?
                .withTintColor(UIColor(red: 1.0, green: 0.78, blue: 0.12, alpha: 1.0), renderingMode: .alwaysOriginal) {
                let noteOrigin = CGPoint(
                    x: (size.width - noteImage.size.width) / 2,
                    y: 120
                )
                noteImage.draw(at: noteOrigin)
            }
            
            // Título
            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.alignment = .center
            titleParagraph.lineBreakMode = .byTruncatingTail
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: titleParagraph
            ]
            let titleRect = CGRect(x: 70, y: 290, width: 372, height: 38)
            (title as NSString).draw(in: titleRect, withAttributes: titleAttributes)
            
            // Artista
            let authorParagraph = NSMutableParagraphStyle()
            authorParagraph.alignment = .center
            authorParagraph.lineBreakMode = .byTruncatingTail
            let authorAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor(red: 0.95, green: 0.75, blue: 0.2, alpha: 1.0),
                .paragraphStyle: authorParagraph
            ]
            let authorRect = CGRect(x: 70, y: 335, width: 372, height: 28)
            (author as NSString).draw(in: authorRect, withAttributes: authorAttributes)
            
            // Marca UnderBro
            let brandParagraph = NSMutableParagraphStyle()
            brandParagraph.alignment = .center
            let brandAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .heavy),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.45),
                .paragraphStyle: brandParagraph
            ]
            let brandRect = CGRect(x: 70, y: 410, width: 372, height: 22)
            ("UNDERBRO" as NSString).draw(in: brandRect, withAttributes: brandAttributes)
        }
    }
    #endif
    
    // MARK: - Control de Reproducción
    
    /// Carga una pista y comienza la reproducción con soporte para streaming y background
    public func playTrack(_ track: Track, from list: [Track] = []) {
        #if os(iOS)
        activateAudioSessionAsync()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif
        
        if !list.isEmpty {
            self.playlist = list
            if let index = list.firstIndex(where: { $0.id == track.id }) {
                self.currentIndex = index
            } else {
                self.currentIndex = 0
            }
        } else {
            if let index = playlist.firstIndex(where: { $0.id == track.id }) {
                self.currentIndex = index
            } else {
                self.playlist = [track]
                self.currentIndex = 0
            }
        }
        
        self.currentTrack = track
        self.duration = Double(track.durationSeconds)
        self.currentTime = 0.0
        self.playbackAnchorTime = Date()
        self.playbackAnchorPosition = 0.0
        
        #if os(iOS)
        loadArtwork(for: track)
        #endif
        
        // Conexión con stream real si existe URL remota
        if let streamURL = track.audioStreamURL {
            stopSilentFallback()
            setupAVPlayer(url: streamURL)
        } else {
            teardownAVPlayer()
            startSilentFallback()
        }
        
        self.isPlaying = true
        startProgressTimer()
        updateNowPlayingInfo()
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
        #if os(iOS)
        activateAudioSessionAsync()
        UIApplication.shared.beginReceivingRemoteControlEvents()
        #endif
        isPlaying = true
        playbackAnchorTime = Date()
        playbackAnchorPosition = currentTime
        
        if let player = avPlayer {
            player.rate = Float(playbackSpeed.rawValue)
            player.play()
        } else if currentTrack?.audioStreamURL == nil {
            startSilentFallback()
        }
        
        startProgressTimer()
        updateNowPlayingInfo()
    }
    
    public func pause() {
        isPlaying = false
        avPlayer?.pause()
        silentAudioPlayer?.pause()
        stopProgressTimer()
        updateNowPlayingInfo()
    }
    
    /// Salta a una posición porcentual de la pista (0.0 a 1.0)
    public func seek(to progress: Double) {
        let clamped = max(0.0, min(1.0, progress))
        let targetSeconds = duration * clamped
        self.currentTime = targetSeconds
        self.playbackAnchorTime = Date()
        self.playbackAnchorPosition = targetSeconds
        
        if let player = avPlayer {
            let targetCMTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
            player.seek(to: targetCMTime)
        }
        
        updateNowPlayingInfo()
    }
    
    /// Siguiente canción en la lista secuencial
    public func nextTrack() {
        guard !playlist.isEmpty else { return }
        
        if isShuffleEnabled {
            if playlist.count > 1 {
                var next = Int.random(in: 0..<playlist.count)
                if next == currentIndex {
                    next = (currentIndex + 1) % playlist.count
                }
                currentIndex = next
            }
        } else {
            currentIndex = (currentIndex + 1) % playlist.count
        }
        
        let nextSong = playlist[currentIndex]
        playTrack(nextSong, from: playlist)
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
        
        let prevSong = playlist[currentIndex]
        playTrack(prevSong, from: playlist)
    }
    
    /// Cierra y descarta el mini-reproductor y los metadatos de bloqueo
    public func dismissPlayer() {
        pause()
        teardownAVPlayer()
        stopSilentFallback()
        currentTrack = nil
        isFullScreenPresented = false
        #if os(iOS)
        MPNowPlayingInfoCenter.default().playbackState = .stopped
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        deactivateAudioSessionAsync()
        #endif
    }
    
    /// Alterna la velocidad entre 0.75x, 1x, 1.25x, 1.5x, 2x
    public func togglePlaybackSpeed() {
        playbackSpeed.toggleNext()
        if isPlaying {
            avPlayer?.rate = Float(playbackSpeed.rawValue)
        }
        playbackAnchorTime = Date()
        playbackAnchorPosition = currentTime
        updateNowPlayingInfo()
    }
    
    // MARK: - Gestión de AVPlayer para Streaming
    
    private func setupAVPlayer(url: URL) {
        teardownAVPlayer()
        
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.avPlayer = player
        
        // Notificación de fin de pista
        playerItemEndObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTrackCompletion()
            }
        }
        
        // Observador periódico del progreso real
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            let seconds = CMTimeGetSeconds(time)
            Task { @MainActor [weak self] in
                guard let self = self, self.isPlaying else { return }
                if seconds.isFinite && !seconds.isNaN {
                    self.currentTime = seconds
                }
            }
        }
        
        player.rate = Float(playbackSpeed.rawValue)
        player.play()
    }
    
    private func teardownAVPlayer() {
        if let token = timeObserverToken {
            avPlayer?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = playerItemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            playerItemEndObserver = nil
        }
        avPlayer?.pause()
        avPlayer = nil
    }
    
    // MARK: - Motor Silencioso para Pistas Locales / Simuladas
    
    private func setupSilentPlayer() {
        guard silentAudioPlayer == nil else { return }
        let silentData = Self.createSilentWavData(durationSeconds: 1.0, sampleRate: 22050)
        do {
            let player = try AVAudioPlayer(data: silentData)
            player.numberOfLoops = -1 // Bucle infinito
            player.volume = 0.05 // Provee flujo audible a CoreAudio sin perturbar al usuario (silencio PCM)
            player.prepareToPlay()
            self.silentAudioPlayer = player
        } catch {
            print("[UnderBro Audio] Error preparando silent fallback player: \(error.localizedDescription)")
        }
    }
    
    private func startSilentFallback() {
        if silentAudioPlayer == nil {
            setupSilentPlayer()
        }
        silentAudioPlayer?.play()
    }
    
    private func stopSilentFallback() {
        silentAudioPlayer?.stop()
        silentAudioPlayer = nil
    }
    
    /// Genera en memoria un archivo WAV PCM canónico de 1 segundo de silencio
    private static func createSilentWavData(durationSeconds: Double = 1.0, sampleRate: Int = 22050) -> Data {
        let numChannels: Int = 1
        let bitsPerSample: Int = 16
        let numSamples = Int(Double(sampleRate) * durationSeconds)
        let dataSize = numSamples * numChannels * (bitsPerSample / 8)
        let fileSize = 44 + dataSize
        
        var data = Data()
        data.reserveCapacity(fileSize)
        
        // "RIFF"
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
        var riffSize = UInt32(fileSize - 8).littleEndian
        data.append(Data(bytes: &riffSize, count: 4))
        
        // "WAVE"
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])
        
        // "fmt "
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
        var subchunk1Size = UInt32(16).littleEndian
        data.append(Data(bytes: &subchunk1Size, count: 4))
        
        var audioFormat = UInt16(1).littleEndian // PCM
        data.append(Data(bytes: &audioFormat, count: 2))
        
        var channels = UInt16(numChannels).littleEndian
        data.append(Data(bytes: &channels, count: 2))
        
        var sRate = UInt32(sampleRate).littleEndian
        data.append(Data(bytes: &sRate, count: 4))
        
        let byteRate = UInt32(sampleRate * numChannels * (bitsPerSample / 8)).littleEndian
        var bRate = byteRate
        data.append(Data(bytes: &bRate, count: 4))
        
        var blockAlign = UInt16(numChannels * (bitsPerSample / 8)).littleEndian
        data.append(Data(bytes: &blockAlign, count: 2))
        
        var bPerSample = UInt16(bitsPerSample).littleEndian
        data.append(Data(bytes: &bPerSample, count: 2))
        
        // "data"
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
        var dSize = UInt32(dataSize).littleEndian
        data.append(Data(bytes: &dSize, count: 4))
        
        // Muestras de silencio (ceros PCM)
        data.append(Data(repeating: 0, count: dataSize))
        
        return data
    }
    
    // MARK: - Temporizador y Sincronización
    
    private func startProgressTimer() {
        stopProgressTimer()
        
        playbackTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isPlaying else { return }
                
                // Si AVPlayer está activo con streaming real, el periodicTimeObserver actualiza currentTime
                if self.avPlayer != nil {
                    if self.currentTime >= self.duration && self.duration > 0 {
                        self.handleTrackCompletion()
                    }
                    return
                }
                
                // Modo simulado / local
                let step = 0.25 * self.playbackSpeed.rawValue
                let nextTime = self.currentTime + step
                
                if nextTime >= self.duration {
                    self.handleTrackCompletion()
                } else {
                    self.currentTime = nextTime
                }
            }
    }
    
    private func stopProgressTimer() {
        playbackTimer?.cancel()
        playbackTimer = nil
    }
    
    private func syncElapsedPositionIfNeeded() {
        guard avPlayer == nil, isPlaying, let anchorTime = playbackAnchorTime else { return }
        let elapsedReal = Date().timeIntervalSince(anchorTime) * playbackSpeed.rawValue
        let calculated = playbackAnchorPosition + elapsedReal
        if calculated >= duration {
            handleTrackCompletion()
        } else {
            currentTime = calculated
        }
    }
    
    private func handleTrackCompletion() {
        if isRepeatEnabled {
            seek(to: 0.0)
            resume()
        } else {
            nextTrack()
        }
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
