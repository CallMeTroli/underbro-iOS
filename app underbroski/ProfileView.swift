//
//  ProfileView.swift
//  UnderBro iOS
//
//  Vista de la pestaña "Yo": Perfil de artista y creador
//  Incluye todos los apartados de la versión web de underbro.app:
//    1. Banner y Avatar con insignia verificada y estado de conexión
//    2. Biografía, enlaces a redes (Spotify, Instagram, YouTube) y roles
//    3. Métricas de reproducciones, pistas y seguidores
//    4. Sub-pestañas:
//       - "Pistas": Tracks subidos con reproductor
//       - "Fotos": Galería visual propia
//       - "Favoritos": Pistas guardadas
//       - "Playlists": Colecciones y mixtapes
//       - "Estudio": Herramientas de artista (Press Kit, Smart Links, Split Sheets)
//       - "Ajustes": Configuración del servidor Supabase y calidad de audio
//

import SwiftUI

public struct ProfileView: View {
    public enum ProfileSubTab: String, CaseIterable, Identifiable {
        case pistas = "Pistas"
        case fotos = "Fotos"
        case favoritos = "Favoritos"
        case playlists = "Playlists"
        case estudio = "Estudio"
        case ajustes = "Ajustes"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .pistas: return "music.note"
            case .fotos: return "photo.stack"
            case .favoritos: return "heart.fill"
            case .playlists: return "music.note.list"
            case .estudio: return "slider.horizontal.3"
            case .ajustes: return "gearshape.fill"
            }
        }
    }
    
    @State private var selectedSubTab: ProfileSubTab = .pistas
    @State private var isEditingProfile: Bool = false
    
    // Pistas del usuario
    @State private var userTracks: [Track] = [
        Track(
            id: "my-track-1",
            rank: 1,
            title: "NOCTURNO // 01",
            author: "Troli (Tú)",
            durationSeconds: 154,
            playsCount: 420,
            likesCount: 52,
            commentsCount: 6,
            genre: "Ambient Wave"
        ),
        Track(
            id: "my-track-2",
            rank: 2,
            title: "ECOS DEL SUBTERRÁNEO",
            author: "Troli (Tú)",
            durationSeconds: 98,
            playsCount: 290,
            likesCount: 31,
            commentsCount: 2,
            genre: "Drill",
            isBeat: true,
            bpm: 142,
            songKey: "F Minor"
        )
    ]
    
    // Fotos del usuario
    @State private var userPhotos: [CommunityPost] = []
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Banner superior y Foto de Perfil
                    profileHeaderView
                    
                    // 2. Roles y Enlaces a redes
                    rolesAndSocialsView
                        .padding(.horizontal, 16)
                    
                    // 3. Métricas en Cristal
                    metricsRow
                        .padding(.horizontal, 16)
                    
                    // 4. Botones de Acción (Editar / Compartir)
                    actionButtonsRow
                        .padding(.horizontal, 16)
                    
                    // 5. Sub-pestañas horizontales Liquid Glass
                    subTabsPicker
                        .padding(.horizontal, 16)
                    
                    // 6. Contenido del sub-apartado seleccionado
                    selectedSubTabContent
                        .padding(.horizontal, 16)
                    
                    Spacer(minLength: 140) // Margen de tab bar y miniplayer
                }
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .task {
                await loadUserData()
            }
            .sheet(isPresented: $isEditingProfile) {
                EditProfileSheet()
            }
        }
    }
    
    // MARK: - 1. Cabecera con Banner y Avatar
    
    private var profileHeaderView: some View {
        VStack(spacing: 0) {
            // Banner de estudio con Liquid Glass
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [UBTheme.accentStart.opacity(0.8), UBTheme.accentEnd.opacity(0.6), UBTheme.surfaceElevated],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 140)
                
                // Efecto de cristal esmerilado en la base del banner
                Rectangle()
                    .fill(.clear)
                    .glassEffect(.regular, in: Rectangle())
                    .frame(height: 40)
            }
            
            // Avatar superpuesto
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    PlaceholderAvatarView(
                        username: "Tu historia",
                        size: 92,
                        hasNewStory: true,
                        isMe: true,
                        isVerified: true
                    )
                    .offset(y: -46)
                    .padding(.bottom, -46)
                }
                
                // Nombre, badge y usuario
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Troli Under")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(UBTheme.textPrimary)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(UBTheme.accentEnd)
                        
                        Text("ALPHA")
                            .font(.system(size: 9, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundStyle(UBTheme.accentGold)
                            .glassEffect(.regular.tint(UBTheme.accentGold.opacity(0.2)), in: .capsule)
                    }
                    
                    Text("@troli · Madrid, ES")
                        .font(.subheadline)
                        .foregroundStyle(UBTheme.textSecondary)
                    
                    Text("Productor & Beatmaker underground. Experimentando con síntesis analógica, pluggnb y ambient wave.")
                        .font(.footnote)
                        .foregroundStyle(UBTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                }
            }
        }
    }
    
    // MARK: - 2. Roles y Redes Sociales
    
    private var rolesAndSocialsView: some View {
        VStack(spacing: 12) {
            // Etiquetas de rol
            HStack(spacing: 8) {
                roleBadge("Productor", icon: "waveform")
                roleBadge("Beatmaker", icon: "pianokeys")
                roleBadge("Sound Designer", icon: "speaker.wave.3")
            }
            
            // Enlaces de redes sociales
            HStack(spacing: 12) {
                socialLinkButton(title: "Spotify", icon: "music.note", url: "https://spotify.com")
                socialLinkButton(title: "Instagram", icon: "camera", url: "https://instagram.com")
                socialLinkButton(title: "YouTube", icon: "play.rectangle", url: "https://youtube.com")
            }
        }
    }
    
    private func roleBadge(_ title: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular, in: .capsule)
        .foregroundStyle(UBTheme.textSecondary)
    }
    
    private func socialLinkButton(title: String, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(UBTheme.textPrimary)
        }
    }
    
    // MARK: - 3. Fila de Métricas
    
    private var metricsRow: some View {
        HStack(spacing: 10) {
            metricItem(title: "Pistas", value: "\(userTracks.count)")
            metricItem(title: "Seguidores", value: "1.4k")
            metricItem(title: "Siguiendo", value: "328")
            metricItem(title: "Plays", value: "7.1k")
        }
    }
    
    private func metricItem(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(UBTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(UBTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - 4. Botones de Acción
    
    private var actionButtonsRow: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    isEditingProfile = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                        Text("Editar Perfil")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                
                ShareLink(item: URL(string: "https://underbro.app/@troli")!) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.glass)
            }
        }
    }
    
    // MARK: - 5. Selector de Sub-pestañas
    
    private var subTabsPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProfileSubTab.allCases) { tab in
                    let isSelected = selectedSubTab == tab
                    
                    if isSelected {
                        Button {
                            selectedSubTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                Text(tab.rawValue)
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(UBTheme.accentStart)
                    } else {
                        Button {
                            selectedSubTab = tab
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                Text(tab.rawValue)
                            }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
    }
    
    // MARK: - 6. Contenido según Sub-pestaña
    
    @ViewBuilder
    private var selectedSubTabContent: some View {
        switch selectedSubTab {
        case .pistas:
            pistasTabContent
        case .fotos:
            fotosTabContent
        case .favoritos:
            favoritosTabContent
        case .playlists:
            playlistsTabContent
        case .estudio:
            estudioTabContent
        case .ajustes:
            ajustesTabContent
        }
    }
    
    // MARK: Contenidos de las Sub-pestañas
    
    private var pistasTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(userTracks) { track in
                TrackRow(track: track, allTracks: userTracks)
            }
        }
    }
    
    private var fotosTabContent: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(0..<4, id: \.self) { idx in
                    PlaceholderArtworkView(
                        style: idx % 2 == 0 ? .vibrantGold : .deepIndigo,
                        titleHint: "Visual #\(idx + 1)",
                        systemIcon: "camera.fill",
                        cornerRadius: 14
                    )
                    .frame(height: 150)
                }
            }
        }
    }
    
    private var favoritosTabContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pistas que te inspiran en UnderBro")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UBTheme.textSecondary)
            
            let favoriteTrack = Track(
                id: "fav-1",
                rank: 1,
                title: "###sol",
                author: "kkikheroina",
                durationSeconds: 63,
                playsCount: 393,
                likesCount: 39,
                isLiked: true,
                genre: "Electronic"
            )
            
            TrackRow(track: favoriteTrack)
        }
    }
    
    private var playlistsTabContent: some View {
        VStack(spacing: 10) {
            playlistRow(title: "Late Night Beats 🌙", count: "12 pistas", duration: "34 min")
            playlistRow(title: "Underground Madrid Essentials", count: "24 pistas", duration: "1h 12 min")
            playlistRow(title: "Synthesizer Moods", count: "8 pistas", duration: "22 min")
        }
    }
    
    private func playlistRow(title: String, count: String, duration: String) -> some View {
        HStack(spacing: 14) {
            PlaceholderArtworkView(style: .emeraldDark, titleHint: title, systemIcon: "music.note.list", cornerRadius: 10)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(UBTheme.textPrimary)
                
                Text("\(count) · \(duration)")
                    .font(.caption2)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(UBTheme.textTertiary)
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    // MARK: - Sub-sección: Estudio (Herramientas de Creadores)
    
    private var estudioTabContent: some View {
        VStack(spacing: 12) {
            studioToolCard(
                title: "Press Kit Digital (EPK)",
                subtitle: "Genera tu kit de prensa interactivo con biografía, fotos y enlaces para sellos y festivales.",
                icon: "doc.text.image.fill",
                actionTitle: "Ver Kit"
            )
            
            studioToolCard(
                title: "Smart Links UnderBro",
                subtitle: "Un único link para que tus oyentes elijan Spotify, Apple Music o UnderBro.",
                icon: "link.badge.plus",
                actionTitle: "Crear Link"
            )
            
            studioToolCard(
                title: "Split Sheets & Regalías",
                subtitle: "Registra los porcentajes de autoría y producción entre colaboradores de tus temas.",
                icon: "percent",
                actionTitle: "Gestionar"
            )
        }
    }
    
    private func studioToolCard(title: String, subtitle: String, icon: String, actionTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(UBTheme.accentCyan)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.tint(UBTheme.accentCyan.opacity(0.2)), in: .circle)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(UBTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(UBTheme.textSecondary)
                }
            }
            
            HStack {
                Spacer()
                Button(actionTitle) {}
                    .buttonStyle(.glass)
                    .font(.caption.weight(.bold))
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Sub-sección: Ajustes y Conexión de Servidor
    
    private var ajustesTabContent: some View {
        VStack(spacing: 14) {
            // Estado de Conexión a Servidor
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                    Text("Servidor Supabase Conectado")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(UBTheme.textPrimary)
                }
                
                Text("Endpoint: https://hvpycejcaljgpxwnykuh.supabase.co")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(UBTheme.accentCyan)
                
                Text("CDN Media: https://underbro.app/media/")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(UBTheme.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Preferencias de Audio
            VStack(alignment: .leading, spacing: 10) {
                Text("Reproducción & Audio")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                Toggle("Streaming en Calidad Máxima (Lossless)", isOn: .constant(true))
                    .tint(UBTheme.accentStart)
                    .foregroundStyle(UBTheme.textPrimary)
                
                Toggle("Normalización de Volumen", isOn: .constant(true))
                    .tint(UBTheme.accentStart)
                    .foregroundStyle(UBTheme.textPrimary)
                
                Toggle("Efectos táctiles hápticos en reproductor", isOn: .constant(true))
                    .tint(UBTheme.accentStart)
                    .foregroundStyle(UBTheme.textPrimary)
            }
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Versión de la App
            VStack(spacing: 4) {
                Text("UnderBro iOS · Edición Liquid Glass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                Text("Diseñado para iOS 26 / 27 · v2.4.0")
                    .font(.caption2)
                    .foregroundStyle(UBTheme.textTertiary)
            }
            .padding(.top, 10)
        }
    }
    
    private func loadUserData() async {
        // Carga posts y pistas si procede
    }
}

// MARK: - Hoja de Edición de Perfil

public struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String = "Troli Under"
    @State private var bio: String = "Productor & Beatmaker underground. Experimentando con síntesis analógica, pluggnb y ambient wave."
    @State private var city: String = "Madrid, ES"
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Información Básica") {
                    TextField("Nombre artístico", text: $displayName)
                    TextField("Ciudad", text: $city)
                    TextField("Biografía", text: $bio, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section("Redes Sociales") {
                    TextField("Instagram (@usuario)", text: .constant("troli_sound"))
                    TextField("Spotify URL", text: .constant("https://open.spotify.com/artist/..."))
                    TextField("YouTube", text: .constant("https://youtube.com/@troli"))
                }
            }
            .scrollContentBackground(.hidden)
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .navigationTitle("Editar Perfil")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .buttonStyle(.glass)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { dismiss() }
                        .buttonStyle(.glassProminent)
                        .tint(UBTheme.accentStart)
                }
            }
        }
    }
}
