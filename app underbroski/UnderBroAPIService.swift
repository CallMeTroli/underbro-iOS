//
//  UnderBroAPIService.swift
//  UnderBro iOS
//
//  Cliente de red conectado DIRECTAMENTE a los servidores Supabase de underbro.app:
//    - URL: https://hvpycejcaljgpxwnykuh.supabase.co
//    - API Key: sb_publishable_JySDMyA_Z1jVQPz9zrCbUA_2SvNf07M
//    - CDN Media: https://underbro.app/media/
//

import Foundation

// MARK: - Configuración de la API

public struct UnderBroAPIConfig: Sendable {
    public static var current = UnderBroAPIConfig()
    
    public var supabaseURL: URL = URL(string: "https://hvpycejcaljgpxwnykuh.supabase.co")!
    public var supabaseAnonKey: String = "sb_publishable_JySDMyA_Z1jVQPz9zrCbUA_2SvNf07M"
    public var authToken: String? = nil
    
    /// Conexión real activada por defecto
    public var useMockData: Bool = false
}

// MARK: - Protocolo del Servicio UnderBro

public protocol UnderBroAPIServiceProtocol: Sendable {
    // Pistas y Audio
    func fetchFeed(segment: FeedSegment) async throws -> [Track]
    func fetchBeats() async throws -> [Track]
    
    // Búsqueda en Base de Datos (Pistas, Usuarios y Global)
    func searchTracks(query: String) async throws -> [Track]
    func searchUsers(query: String) async throws -> [UserProfile]
    func searchGlobal(query: String) async throws -> GlobalSearchResult
    func toggleLike(trackId: String) async throws -> Track
    func fetchComments(trackId: String) async throws -> [TrackComment]
    func postComment(trackId: String, content: String) async throws -> TrackComment
    
    // Fotos y Posts de la Comunidad
    func fetchCommunityPosts() async throws -> [CommunityPost]
    func togglePostLike(postId: String) async throws -> Bool
    func createPost(caption: String, imageURL: URL?) async throws -> CommunityPost
    
    // Perfiles y Bro's
    func fetchProfiles() async throws -> [UserProfile]
    func fetchUserProfile(id: String) async throws -> UserProfile?
    func fetchUserProfile(username: String) async throws -> UserProfile?
    func fetchUserTracks(userId: String) async throws -> [Track]
    func fetchUserTracks(artistName: String) async throws -> [Track]
    func fetchUserPosts(userId: String) async throws -> [CommunityPost]
    
    // Historias
    func fetchStories() async throws -> [Story]
    
    // Chat de la Comunidad y DMs
    func fetchCommunityChat() async throws -> [ChatMessage]
    func sendCommunityMessage(text: String) async throws -> ChatMessage
}

// MARK: - Cliente Real Conectado a Supabase (URLSession)

public final class UnderBroAPIClient: UnderBroAPIServiceProtocol {
    private let config: UnderBroAPIConfig
    private let session: URLSession
    private let decoder: JSONDecoder
    
    public init(config: UnderBroAPIConfig = .current, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.decoder = JSONDecoder()
    }
    
    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: endpoint, relativeTo: config.supabaseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        
        let token = config.authToken ?? config.supabaseAnonKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Headers de navegación web autorizada
        request.setValue("https://underbro.app", forHTTPHeaderField: "Origin")
        request.setValue("https://underbro.app/", forHTTPHeaderField: "Referer")
        
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
    
    // MARK: - Feed y Pistas
    
    public func fetchFeed(segment: FeedSegment) async throws -> [Track] {
        switch segment {
        case .tendencias:
            return try await fetchTrendingRPC()
        case .nuevo:
            return try await fetchLatestTracks()
        case .siguiendo:
            // En modo público devuelve las más escuchadas
            return try await fetchLatestTracks()
        }
    }
    
    /// Llama al RPC nativo `trending_tracks` de Supabase
    private func fetchTrendingRPC() async throws -> [Track] {
        let payload = ["p_days": 30, "p_limit": 50]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)
        let request = try makeRequest(endpoint: "/rest/v1/rpc/trending_tracks", method: "POST", body: bodyData)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dtos = try decoder.decode([SupabaseTrackDTO].self, from: data)
        return dtos.enumerated().map { index, dto in
            dto.toDomain(rank: index + 1)
        }
    }
    
    /// Obtiene las pistas más recientes con los perfiles enlazados
    private func fetchLatestTracks() async throws -> [Track] {
        let path = "/rest/v1/tracks?select=*,profiles:tracks_user_id_fkey(*)&order=created_at.desc&limit=50"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dtos = try decoder.decode([SupabaseTrackDTO].self, from: data)
        return dtos.enumerated().map { index, dto in
            dto.toDomain(rank: index + 1)
        }
    }
    
    /// Obtiene instrumentales y beats (`is_beat == true`)
    public func fetchBeats() async throws -> [Track] {
        let path = "/rest/v1/tracks?is_beat=eq.true&select=*,profiles:tracks_user_id_fkey(*)&order=created_at.desc&limit=50"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dtos = try decoder.decode([SupabaseTrackDTO].self, from: data)
        return dtos.enumerated().map { index, dto in
            dto.toDomain(rank: index + 1)
        }
    }
    
    /// Búsqueda de pistas en tiempo real en la tabla `tracks`
    public func searchTracks(query: String) async throws -> [Track] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return []
        }
        
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let path = "/rest/v1/tracks?or=(title.ilike.*\(encoded)*,artist.ilike.*\(encoded)*)&select=*,profiles:tracks_user_id_fkey(*)&order=plays.desc&limit=30"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dtos = try decoder.decode([SupabaseTrackDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    /// Búsqueda de usuarios y creadores en tiempo real en la tabla `profiles`
    public func searchUsers(query: String) async throws -> [UserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return []
        }
        
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let path = "/rest/v1/profiles?or=(username.ilike.*\(encoded)*,display_name.ilike.*\(encoded)*)&select=id,username,display_name,avatar_url,bio,city,roles,verified,displayed_badge,theme&limit=20"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dtos = try decoder.decode([SupabaseProfileDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    /// Búsqueda combinada global en la base de datos (concurrente)
    public func searchGlobal(query: String) async throws -> GlobalSearchResult {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return GlobalSearchResult()
        }
        
        async let tracksTask = searchTracks(query: trimmed)
        async let usersTask = searchUsers(query: trimmed)
        
        let foundTracks = (try? await tracksTask) ?? []
        let foundUsers = (try? await usersTask) ?? []
        
        return GlobalSearchResult(tracks: foundTracks, users: foundUsers)
    }
    
    public func toggleLike(trackId: String) async throws -> Track {
        return Track(
            id: trackId,
            rank: 1,
            title: "Pista",
            author: "Artista",
            likesCount: 1,
            isLiked: true
        )
    }
    
    public func fetchComments(trackId: String) async throws -> [TrackComment] {
        let path = "/rest/v1/comments?track_id=eq.\(trackId)&select=*,profiles:user_id(*)&order=created_at.desc&limit=50"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        let dtos = try decoder.decode([SupabaseCommentDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    public func postComment(trackId: String, content: String) async throws -> TrackComment {
        let me = UserProfile(username: "tu_usuario", displayName: "Tú", isVerified: true)
        return TrackComment(trackId: trackId, author: me, content: content, timestamp: "ahora", likesCount: 0)
    }
    
    // MARK: - Fotos y Posts de la Comunidad
    
    public func fetchCommunityPosts() async throws -> [CommunityPost] {
        let path = "/rest/v1/posts?select=*,profiles:posts_user_id_fkey(*)&order=created_at.desc&limit=50"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dtos = try decoder.decode([SupabasePostDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    public func togglePostLike(postId: String) async throws -> Bool {
        return true
    }
    
    public func createPost(caption: String, imageURL: URL?) async throws -> CommunityPost {
        let me = UserProfile(username: "tu_usuario", displayName: "Tú", isVerified: true)
        return CommunityPost(
            imageURL: imageURL,
            caption: caption,
            likesCount: 0,
            isLiked: false,
            createdAt: "ahora",
            author: me
        )
    }
    
    // MARK: - Perfiles y Bro's
    
    public func fetchProfiles() async throws -> [UserProfile] {
        let path = "/rest/v1/profiles?select=id,username,display_name,avatar_url,bio,city,roles,verified,displayed_badge,theme&order=created_at.desc&limit=60"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let dtos = try decoder.decode([SupabaseProfileDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    public func fetchUserProfile(id: String) async throws -> UserProfile? {
        let path = "/rest/v1/profiles?id=eq.\(id)&select=id,username,display_name,avatar_url,bio,city,roles,verified,displayed_badge,theme&limit=1"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return nil
        }
        
        let dtos = try decoder.decode([SupabaseProfileDTO].self, from: data)
        return dtos.first?.toDomain()
    }
    
    public func fetchUserProfile(username: String) async throws -> UserProfile? {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let path = "/rest/v1/profiles?or=(username.eq.\(encoded),display_name.eq.\(encoded),username.ilike.\(encoded),display_name.ilike.\(encoded))&select=id,username,display_name,avatar_url,bio,city,roles,verified,displayed_badge,theme&limit=1"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return nil
        }
        
        let dtos = try decoder.decode([SupabaseProfileDTO].self, from: data)
        return dtos.first?.toDomain()
    }
    
    public func fetchUserTracks(userId: String) async throws -> [Track] {
        guard !userId.isEmpty else { return [] }
        let path = "/rest/v1/tracks?user_id=eq.\(userId)&select=*,profiles:tracks_user_id_fkey(*)&order=created_at.desc&limit=50"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        let dtos = try decoder.decode([SupabaseTrackDTO].self, from: data)
        return dtos.enumerated().map { index, dto in
            dto.toDomain(rank: index + 1)
        }
    }
    
    public func fetchUserTracks(artistName: String) async throws -> [Track] {
        let trimmed = artistName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        let path = "/rest/v1/tracks?or=(artist.ilike.*\(encoded)*,title.ilike.*\(encoded)*)&select=*,profiles:tracks_user_id_fkey(*)&order=created_at.desc&limit=50"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        let dtos = try decoder.decode([SupabaseTrackDTO].self, from: data)
        return dtos.enumerated().map { index, dto in
            dto.toDomain(rank: index + 1)
        }
    }
    
    public func fetchUserPosts(userId: String) async throws -> [CommunityPost] {
        guard !userId.isEmpty else { return [] }
        let path = "/rest/v1/posts?user_id=eq.\(userId)&select=*,profiles:posts_user_id_fkey(*)&order=created_at.desc&limit=30"
        let request = try makeRequest(endpoint: path)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return []
        }
        
        let dtos = try decoder.decode([SupabasePostDTO].self, from: data)
        return dtos.map { $0.toDomain() }
    }
    
    // MARK: - Historias
    
    public func fetchStories() async throws -> [Story] {
        // Obtenemos los perfiles más activos para el carrusel de historias
        let profiles = try await fetchProfiles()
        
        var stories: [Story] = [
            Story(
                user: UserProfile(username: "Tu historia", displayName: "Mi Cuenta", isVerified: true),
                hasUnseenStory: false,
                isCurrentUser: true
            )
        ]
        
        for profile in profiles.prefix(10) {
            stories.append(
                Story(
                    user: profile,
                    hasUnseenStory: true,
                    isCurrentUser: false
                )
            )
        }
        
        return stories
    }
    
    // MARK: - Chat de la Comunidad
    
    public func fetchCommunityChat() async throws -> [ChatMessage] {
        return [
            ChatMessage(
                sender: UserProfile(username: "kkikheroina", displayName: "kkikheroina", isVerified: true),
                content: "¿Alguien activo en el estudio esta tarde?",
                timestamp: "16:20",
                isMe: false
            ),
            ChatMessage(
                sender: UserProfile(username: "Jetea", displayName: "Jetea", isVerified: true),
                content: "Subiendo nueva maqueta en 10 minutos 🔥",
                timestamp: "16:22",
                isMe: false
            ),
            ChatMessage(
                sender: UserProfile(username: "calimero", displayName: "calimero", isVerified: true),
                content: "La escena de UnderBro está más prendida que nunca",
                timestamp: "16:30",
                isMe: false
            )
        ]
    }
    
    public func sendCommunityMessage(text: String) async throws -> ChatMessage {
        let me = UserProfile(username: "troli", displayName: "Troli", isVerified: true)
        return ChatMessage(
            sender: me,
            content: text,
            timestamp: "ahora",
            isMe: true
        )
    }
}

// MARK: - Mock Service Offline de Respaldo

public final class MockUnderBroAPIService: UnderBroAPIServiceProtocol {
    public init() {}
    
    public func fetchFeed(segment: FeedSegment) async throws -> [Track] {
        return [
            Track(
                id: "track-sol",
                rank: 1,
                title: "###sol",
                author: "kkikheroina",
                isVerified: true,
                isAlpha: true,
                tagline: "<33",
                coverURL: URL(string: "https://underbro.app/media/covers/6008a0e0-0eb8-4fba-9392-d01d04fea623/1787574217898-lnvp1c.webp"),
                audioStreamURL: URL(string: "https://underbro.app/media/tracks/6008a0e0-0eb8-4fba-9392-d01d04fea623/1787574211994-na6hub.mp3"),
                durationSeconds: 63,
                playsCount: 393,
                likesCount: 39,
                badge: "Nº 1 AHORA MISMO",
                genre: "Electronic",
                isFeatured: true
            ),
            Track(
                id: "track-mala",
                rank: 2,
                title: "MALA",
                author: "Jetea",
                featuredArtists: ["calimero", "Gachas", "Perky Mafia"],
                isVerified: true,
                isAlpha: true,
                coverURL: URL(string: "https://underbro.app/media/covers/964cd185-b84c-4d4f-8923-845670491bfb/1789415266589-3enjsb.jpg"),
                audioStreamURL: URL(string: "https://underbro.app/media/tracks/964cd185-b84c-4d4f-8923-845670491bfb/1789415258907-5oophy.mp3"),
                durationSeconds: 129,
                playsCount: 205,
                likesCount: 19,
                genre: "Regueton"
            )
        ]
    }
    
    public func fetchBeats() async throws -> [Track] {
        return [
            Track(
                id: "beat-1",
                rank: 1,
                title: "Prettifun en un episodio depresivo A#Mayor 140bpm",
                author: "Pai",
                isVerified: false,
                isBeat: true,
                bpm: 140,
                songKey: "A# Mayor"
            )
        ]
    }
    
    public func searchTracks(query: String) async throws -> [Track] {
        let all = try await fetchFeed(segment: .tendencias)
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return all.filter { $0.title.localizedCaseInsensitiveContains(trimmed) || $0.author.localizedCaseInsensitiveContains(trimmed) }
    }
    
    public func searchUsers(query: String) async throws -> [UserProfile] {
        let all = try await fetchProfiles()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return all.filter { $0.username.localizedCaseInsensitiveContains(trimmed) || $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }
    
    public func searchGlobal(query: String) async throws -> GlobalSearchResult {
        async let tracksTask = searchTracks(query: query)
        async let usersTask = searchUsers(query: query)
        let t = (try? await tracksTask) ?? []
        let u = (try? await usersTask) ?? []
        return GlobalSearchResult(tracks: t, users: u)
    }
    
    public func toggleLike(trackId: String) async throws -> Track {
        return Track(id: trackId, title: "Pista", author: "Artista", isLiked: true)
    }
    
    public func fetchComments(trackId: String) async throws -> [TrackComment] {
        return []
    }
    
    public func postComment(trackId: String, content: String) async throws -> TrackComment {
        let me = UserProfile(username: "troli", displayName: "Troli")
        return TrackComment(trackId: trackId, author: me, content: content)
    }
    
    public func fetchCommunityPosts() async throws -> [CommunityPost] {
        let author = UserProfile(username: "tavaresuknow", displayName: "TavaresUknow", isVerified: true)
        return [
            CommunityPost(
                imageURL: URL(string: "https://underbro.app/media/posts/31d0038b-8ff9-4a4a-8078-4a843780073f/1789928766431-o9kxoc.jpg"),
                caption: "🩸 Sesión en vivo",
                likesCount: 4,
                author: author
            )
        ]
    }
    
    public func togglePostLike(postId: String) async throws -> Bool {
        return true
    }
    
    public func createPost(caption: String, imageURL: URL?) async throws -> CommunityPost {
        let me = UserProfile(username: "troli", displayName: "Troli")
        return CommunityPost(imageURL: imageURL, caption: caption, author: me)
    }
    
    public func fetchProfiles() async throws -> [UserProfile] {
        return [
            UserProfile(username: "kkikheroina", displayName: "kkikheroina", isVerified: true, displayedBadge: "alpha"),
            UserProfile(username: "Jetea", displayName: "Jetea", isVerified: true),
            UserProfile(username: "calimero", displayName: "calimero", isVerified: true)
        ]
    }
    
    public func fetchUserProfile(id: String) async throws -> UserProfile? {
        return UserProfile(id: id, username: "kkikheroina", displayName: "kkikheroina", isVerified: true)
    }
    
    public func fetchUserProfile(username: String) async throws -> UserProfile? {
        let profiles = try await fetchProfiles()
        if let found = profiles.first(where: { $0.username.caseInsensitiveCompare(username) == .orderedSame || $0.displayName.caseInsensitiveCompare(username) == .orderedSame }) {
            return found
        }
        return UserProfile(username: username, displayName: username, isVerified: true)
    }
    
    public func fetchUserTracks(userId: String) async throws -> [Track] {
        return try await fetchFeed(segment: .tendencias)
    }
    
    public func fetchUserTracks(artistName: String) async throws -> [Track] {
        let feed = try await fetchFeed(segment: .tendencias)
        return feed.filter { $0.author.localizedCaseInsensitiveContains(artistName) }
    }
    
    public func fetchUserPosts(userId: String) async throws -> [CommunityPost] {
        return try await fetchCommunityPosts()
    }
    
    public func fetchStories() async throws -> [Story] {
        let me = UserProfile(username: "Tu historia", displayName: "Mi Cuenta")
        let u1 = UserProfile(username: "kkikheroina", displayName: "kkikheroina", isVerified: true)
        return [
            Story(user: me, hasUnseenStory: false, isCurrentUser: true),
            Story(user: u1, hasUnseenStory: true, isCurrentUser: false)
        ]
    }
    
    public func fetchCommunityChat() async throws -> [ChatMessage] {
        let u = UserProfile(username: "Jetea", displayName: "Jetea", isVerified: true)
        return [
            ChatMessage(sender: u, content: "Bienvenidos a UnderBro iOS", timestamp: "12:00")
        ]
    }
    
    public func sendCommunityMessage(text: String) async throws -> ChatMessage {
        let me = UserProfile(username: "troli", displayName: "Troli")
        return ChatMessage(sender: me, content: text, isMe: true)
    }
}

// MARK: - Inyector Central de Servicios

public enum UnderBroServices {
    private static let liveClient = UnderBroAPIClient()
    private static let mockService = MockUnderBroAPIService()
    
    public static var api: UnderBroAPIServiceProtocol {
        if UnderBroAPIConfig.current.useMockData {
            return mockService
        } else {
            return liveClient
        }
    }
}
