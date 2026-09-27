//
//  ArtistProfileView.swift
//  UnderBro iOS
//
//  Interfaz de usuario para perfiles de artistas y creadores de UnderBro.
//  Aparece en:
//    1. FullScreenPlayerView: al pulsar sobre el nombre del artista en el reproductor
//    2. Buscador: al pulsar sobre cualquier usuario en los resultados de búsqueda
//    3. Menú principal: al pulsar sobre el nombre del artista en tarjetas o en Bro's
//  Diseño nativo iOS 26+ Liquid Glass, conectado en directo a Supabase.
//

import SwiftUI

public struct ArtistProfileView: View {
    @Environment(\.dismiss) private var dismiss
    
    public enum ArtistSubTab: String, CaseIterable, Identifiable {
        case pistas = "Pistas"
        case fotos = "Fotos"
        case info = "Información"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .pistas: return "music.note"
            case .fotos: return "camera.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    private let initialUser: UserProfile?
    private let initialArtistName: String?
    private let initialUserId: String?
    
    @State private var profile: UserProfile?
    @State private var artistTracks: [Track] = []
    @State private var artistPosts: [CommunityPost] = []
    @State private var isLoading: Bool = true
    @State private var isFollowing: Bool = false
    @State private var selectedSubTab: ArtistSubTab = .pistas
    @State private var selectedPostForDetail: CommunityPost? = nil
    @State private var isShowingDirectChat: Bool = false
    
    // MARK: - Inicializadores
    
    public init(user: UserProfile) {
        self.initialUser = user
        self.initialArtistName = user.displayName.isEmpty ? user.username : user.displayName
        self.initialUserId = user.id
        self._profile = State(initialValue: user)
    }
    
    public init(artistName: String) {
        self.initialUser = nil
        self.initialArtistName = artistName
        self.initialUserId = nil
    }
    
    public init(userId: String) {
        self.initialUser = nil
        self.initialArtistName = nil
        self.initialUserId = userId
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Cabecera: Banner, Avatar e Insignias
                    headerBannerSection
                    
                    // Nombres, Biografía y Roles
                    authorIdentitySection
                        .padding(.horizontal, 20)
                    
                    // Redes Sociales (Spotify, Instagram, YouTube, SoundCloud)
                    if let user = profile, !user.socialLinks.isEmpty {
                        socialLinksRow(user.socialLinks)
                            .padding(.horizontal, 20)
                    }
                    
                    // Fila de Métricas en Cristal
                    metricsRow
                        .padding(.horizontal, 20)
                    
                    // Botones de Acción (Seguir, Mensaje, Compartir)
                    actionButtonsRow
                        .padding(.horizontal, 20)
                    
                    // Sub-pestañas (Pistas / Fotos / Información)
                    subTabsPicker
                        .padding(.horizontal, 20)
                    
                    // Contenido de la sub-pestaña seleccionada
                    if isLoading && artistTracks.isEmpty {
                        ProgressView()
                            .tint(UBTheme.accentCyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        selectedSubTabContent
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 60)
                }
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if let profile = profile {
                        ShareLink(item: URL(string: "https://underbro.app/@\(profile.username)")!) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .task {
                await loadArtistData()
            }
            .fullScreenCover(item: $selectedPostForDetail) { post in
                PhotoLightboxView(post: post)
            }
            .sheet(isPresented: $isShowingDirectChat) {
                if let user = profile {
                    let dm = ChatListView.DMChatItem(
                        user: user,
                        lastMessage: "¡Hola! He visto tu perfil en UnderBro.",
                        time: "ahora",
                        unreadCount: 0,
                        isOnline: true
                    )
                    DirectChatThreadSheet(dm: dm)
                }
            }
        }
    }
    
    // MARK: - 1. Banner y Avatar con Liquid Glass
    
    private var headerBannerSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if let bannerURL = profile?.bannerURL {
                    AsyncImage(url: bannerURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipped()
                        default:
                            fallbackBannerGradient
                        }
                    }
                } else {
                    fallbackBannerGradient
                }
                
                // Bisel inferior de cristal
                LinearGradient(
                    colors: [.clear, UBTheme.backgroundDark.opacity(0.85), UBTheme.backgroundDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
            }
            
            // Avatar superpuesto
            ZStack(alignment: .bottomTrailing) {
                if let avatarURL = profile?.avatarURL {
                    AsyncImage(url: avatarURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            PlaceholderAvatarView(
                                username: profile?.username ?? initialArtistName ?? "artista",
                                size: 92,
                                hasNewStory: true,
                                isVerified: profile?.isVerified ?? false
                            )
                        }
                    }
                    .frame(width: 92, height: 92)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(UBTheme.backgroundDark, lineWidth: 4))
                    .shadow(color: UBTheme.accentStart.opacity(0.4), radius: 16, x: 0, y: 8)
                } else {
                    PlaceholderAvatarView(
                        username: profile?.username ?? initialArtistName ?? "artista",
                        size: 92,
                        hasNewStory: true,
                        isVerified: profile?.isVerified ?? false
                    )
                }
            }
            .offset(y: -46)
            .padding(.bottom, -40)
        }
    }
    
    private var fallbackBannerGradient: some View {
        LinearGradient(
            colors: [UBTheme.accentStart.opacity(0.85), UBTheme.accentEnd.opacity(0.6), UBTheme.surfaceElevated],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 160)
    }
    
    // MARK: - 2. Identidad del Artista
    
    private var authorIdentitySection: some View {
        VStack(spacing: 6) {
            // Nombre y sellos de verificación
            HStack(spacing: 6) {
                Text(profile?.displayName.isEmpty == false ? profile!.displayName : (profile?.username ?? initialArtistName ?? "Artista"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(UBTheme.textPrimary)
                
                if profile?.isVerified == true {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(UBTheme.accentEnd)
                }
                
                if let badge = profile?.displayedBadge, !badge.isEmpty {
                    Text(badge.uppercased())
                        .font(.system(size: 9, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(UBTheme.accentGold)
                        .glassEffect(.regular.tint(UBTheme.accentGold.opacity(0.2)), in: .capsule)
                }
            }
            
            // @username y Ciudad
            HStack(spacing: 4) {
                Text("@\(profile?.username ?? (initialArtistName?.lowercased().replacingOccurrences(of: " ", with: "") ?? "creador"))")
                    .font(.subheadline)
                    .foregroundStyle(UBTheme.textSecondary)
                
                if let city = profile?.city, !city.isEmpty {
                    Text("· \(city)")
                        .font(.subheadline)
                        .foregroundStyle(UBTheme.textTertiary)
                }
            }
            
            // Biografía
            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.footnote)
                    .foregroundStyle(UBTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            
            // Roles y Etiquetas del creador
            if let roles = profile?.roles, !roles.isEmpty {
                HStack(spacing: 6) {
                    ForEach(roles, id: \.self) { role in
                        Text(role.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(UBTheme.accentCyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .glassEffect(.regular.tint(UBTheme.accentCyan.opacity(0.15)), in: .capsule)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - 3. Fila de Redes Sociales
    
    private func socialLinksRow(_ links: [UserProfile.SocialLink]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(links) { link in
                    if let url = URL(string: link.url) {
                        Link(destination: url) {
                            HStack(spacing: 5) {
                                Image(systemName: iconForSocial(link.label))
                                    .font(.caption2)
                                Text(link.label)
                                    .font(.caption2.weight(.semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(UBTheme.textPrimary)
                        }
                    }
                }
            }
        }
    }
    
    private func iconForSocial(_ label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("spotify") { return "music.note" }
        if lower.contains("instagram") { return "camera" }
        if lower.contains("youtube") { return "play.rectangle" }
        if lower.contains("sound") { return "waveform" }
        return "link"
    }
    
    // MARK: - 4. Métricas en Cristal
    
    private var metricsRow: some View {
        HStack(spacing: 12) {
            metricItem(title: "Pistas", value: "\(artistTracks.count)")
            metricItem(title: "Seguidores", value: formatCount(profile?.followersCount ?? 420))
            metricItem(title: "Siguiendo", value: "\(profile?.followingCount ?? 68)")
            metricItem(title: "Plays", value: formatCount(profile?.totalPlays ?? artistTracks.reduce(0) { $0 + $1.playsCount }))
        }
    }
    
    private func metricItem(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(UBTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(UBTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    // MARK: - 5. Botones de Acción
    
    private var actionButtonsRow: some View {
        HStack(spacing: 10) {
            // Botón Seguir / Siguiendo
            if isFollowing {
                Button {
                    isFollowing.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                        Text("Siguiendo")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
            } else {
                Button {
                    isFollowing.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.badge.plus.fill")
                            .font(.caption.weight(.bold))
                        Text("Seguir")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(UBTheme.accentStart)
            }
            
            // Botón Mensaje / DM
            Button {
                isShowingDirectChat = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "message.fill")
                    Text("Mensaje")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.glass)
        }
    }
    
    // MARK: - 6. Selector de Sub-pestañas
    
    private var subTabsPicker: some View {
        HStack(spacing: 8) {
            ForEach(ArtistSubTab.allCases) { tab in
                let isSelected = selectedSubTab == tab
                let countTitle: String = {
                    switch tab {
                    case .pistas: return "\(tab.rawValue) (\(artistTracks.count))"
                    case .fotos: return "\(tab.rawValue) (\(artistPosts.count))"
                    case .info: return tab.rawValue
                    }
                }()
                
                if isSelected {
                    Button {
                        selectedSubTab = tab
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                            Text(countTitle)
                        }
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentStart)
                } else {
                    Button {
                        selectedSubTab = tab
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                            Text(countTitle)
                        }
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
    
    // MARK: - 7. Contenido según Sub-pestaña
    
    @ViewBuilder
    private var selectedSubTabContent: some View {
        switch selectedSubTab {
        case .pistas:
            pistasContent
        case .fotos:
            fotosContent
        case .info:
            infoContent
        }
    }
    
    private var pistasContent: some View {
        VStack(spacing: 12) {
            if artistTracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(UBTheme.textTertiary)
                    Text("Aún no ha subido pistas a UnderBro")
                        .font(.caption)
                        .foregroundStyle(UBTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(artistTracks) { track in
                        TrackRow(track: track)
                    }
                }
            }
        }
    }
    
    private var fotosContent: some View {
        VStack(spacing: 12) {
            if artistPosts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.title2)
                        .foregroundStyle(UBTheme.textTertiary)
                    Text("No hay fotos comunitarias publicadas")
                        .font(.caption)
                        .foregroundStyle(UBTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(artistPosts) { post in
                        ZStack(alignment: .bottomLeading) {
                            if let url = post.imageURL {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        PlaceholderArtworkView(style: .deepIndigo, cornerRadius: 14)
                                    }
                                }
                            } else {
                                PlaceholderArtworkView(style: .deepIndigo, cornerRadius: 14)
                            }
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onTapGesture {
                            selectedPostForDetail = post
                        }
                    }
                }
            }
        }
    }
    
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Ficha técnica del artista
            VStack(alignment: .leading, spacing: 10) {
                Text("Detalles de la Cuenta")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(UBTheme.textPrimary)
                
                infoRow(label: "Nombre de usuario", value: "@\(profile?.username ?? "usuario")")
                if let city = profile?.city, !city.isEmpty {
                    infoRow(label: "Ubicación", value: city)
                }
                infoRow(label: "Estado", value: profile?.isVerified == true ? "Verificado Oficial" : "Miembro de la Escena")
                if let badge = profile?.displayedBadge, !badge.isEmpty {
                    infoRow(label: "Insignia", value: badge.uppercased())
                }
                infoRow(label: "Plataforma", value: "UnderBro Underground Network")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(UBTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(UBTheme.textPrimary)
        }
    }
    
    // MARK: - Carga de Datos desde Supabase
    
    private func loadArtistData() async {
        isLoading = true
        
        // 1. Obtener perfil
        var loadedProfile = profile
        if loadedProfile == nil {
            if let id = initialUserId {
                loadedProfile = try? await UnderBroServices.api.fetchUserProfile(id: id)
            } else if let name = initialArtistName {
                loadedProfile = try? await UnderBroServices.api.fetchUserProfile(username: name)
            }
        }
        
        let targetProfile = loadedProfile ?? UserProfile(
            id: initialUserId ?? UUID().uuidString,
            username: initialArtistName?.lowercased().replacingOccurrences(of: " ", with: "") ?? "artista",
            displayName: initialArtistName ?? "Artista",
            isVerified: true
        )
        
        let profileId = targetProfile.id
        let artistName = initialArtistName
        
        // 2. Obtener pistas y fotos en paralelo
        async let tracksTask: [Track] = {
            if !profileId.isEmpty {
                let tracksById = (try? await UnderBroServices.api.fetchUserTracks(userId: profileId)) ?? []
                if !tracksById.isEmpty { return tracksById }
            }
            if let name = artistName {
                return (try? await UnderBroServices.api.fetchUserTracks(artistName: name)) ?? []
            }
            return []
        }()
        
        async let postsTask: [CommunityPost] = {
            if !profileId.isEmpty {
                return (try? await UnderBroServices.api.fetchUserPosts(userId: profileId)) ?? []
            }
            return []
        }()
        
        let (fetchedTracks, fetchedPosts) = await (tracksTask, postsTask)
        
        await MainActor.run {
            self.profile = targetProfile
            self.artistTracks = fetchedTracks
            self.artistPosts = fetchedPosts
            self.isLoading = false
        }
    }
}
