//
//  Models.swift
//  UnderBro iOS
//
//  Estructuras de datos y modelos Codable para la conexión directa
//  con la base de datos Supabase de underbro.app.
//

import Foundation

// MARK: - Segmentos del Feed Principal

public enum FeedSegment: String, CaseIterable, Identifiable, Codable {
    case tendencias = "Tendencias"
    case nuevo = "Nuevo"
    case siguiendo = "Siguiendo"
    
    public var id: String { rawValue }
    
    public var apiParameter: String {
        switch self {
        case .siguiendo: return "following"
        case .tendencias: return "trending"
        case .nuevo: return "new"
        }
    }
}

// MARK: - Filtros de Descubrimiento (Discover Pills)

public enum DiscoverFilter: String, CaseIterable, Identifiable {
    case todos = "🔥 Todo"
    case radio = "📻 Radio"
    case beats = "🎹 Beats"
    case eventos = "🎟️ Eventos"
    case bros = "🎤 Bro's"
    
    public var id: String { rawValue }
}

// MARK: - Perfil de Usuario (profiles en Supabase)

public struct UserProfile: Identifiable, Hashable, Codable {
    public let id: String
    public let username: String
    public let displayName: String
    public let avatarURL: URL?
    public let bannerURL: URL?
    public let bio: String?
    public let city: String?
    public let roles: [String]
    public let isVerified: Bool
    public let displayedBadge: String?
    public var followersCount: Int
    public var followingCount: Int
    public var tracksCount: Int
    public var totalPlays: Int
    public let socialLinks: [SocialLink]
    
    public struct SocialLink: Hashable, Codable, Identifiable {
        public var id: String { url }
        public let label: String
        public let url: String
        
        public init(label: String, url: String) {
            self.label = label
            self.url = url
        }
    }
    
    public init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        avatarURL: URL? = nil,
        bannerURL: URL? = nil,
        bio: String? = nil,
        city: String? = nil,
        roles: [String] = [],
        isVerified: Bool = false,
        displayedBadge: String? = nil,
        followersCount: Int = 0,
        followingCount: Int = 0,
        tracksCount: Int = 0,
        totalPlays: Int = 0,
        socialLinks: [SocialLink] = []
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bannerURL = bannerURL
        self.bio = bio
        self.city = city
        self.roles = roles
        self.isVerified = isVerified
        self.displayedBadge = displayedBadge
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.tracksCount = tracksCount
        self.totalPlays = totalPlays
        self.socialLinks = socialLinks
    }
}

// MARK: - Historia (Story)

public struct Story: Identifiable, Hashable, Codable {
    public let id: String
    public let user: UserProfile
    public var hasUnseenStory: Bool
    public let isCurrentUser: Bool
    public let mediaURL: URL?
    public let trackId: String?
    public let createdAt: Date?
    
    public init(
        id: String = UUID().uuidString,
        user: UserProfile,
        hasUnseenStory: Bool = true,
        isCurrentUser: Bool = false,
        mediaURL: URL? = nil,
        trackId: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.user = user
        self.hasUnseenStory = hasUnseenStory
        self.isCurrentUser = isCurrentUser
        self.mediaURL = mediaURL
        self.trackId = trackId
        self.createdAt = createdAt
    }
}

// MARK: - Pista de Audio (tracks en Supabase)

public struct Track: Identifiable, Hashable, Codable {
    public let id: String
    public var rank: Int?
    public let title: String
    public let author: String
    public let featuredArtists: [String]?
    public let isVerified: Bool
    public let isAlpha: Bool
    public let tagline: String?
    public let coverURL: URL?
    public let audioStreamURL: URL?
    public let durationSeconds: Int
    public var playsCount: Int
    public var likesCount: Int
    public var commentsCount: Int
    public var repostsCount: Int
    public var isLiked: Bool
    public var isReposted: Bool
    public let badge: String?
    public let genre: String?
    public let isFeatured: Bool
    public let isBeat: Bool
    public let bpm: Int?
    public let songKey: String?
    public var waveformSamples: [Double]?
    
    public init(
        id: String = UUID().uuidString,
        rank: Int? = nil,
        title: String,
        author: String,
        featuredArtists: [String]? = nil,
        isVerified: Bool = false,
        isAlpha: Bool = false,
        tagline: String? = nil,
        coverURL: URL? = nil,
        audioStreamURL: URL? = nil,
        durationSeconds: Int = 63,
        playsCount: Int = 0,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        repostsCount: Int = 0,
        isLiked: Bool = false,
        isReposted: Bool = false,
        badge: String? = nil,
        genre: String? = nil,
        isFeatured: Bool = false,
        isBeat: Bool = false,
        bpm: Int? = nil,
        songKey: String? = nil,
        waveformSamples: [Double]? = nil
    ) {
        self.id = id
        self.rank = rank
        self.title = title
        self.author = author
        self.featuredArtists = featuredArtists
        self.isVerified = isVerified
        self.isAlpha = isAlpha
        self.tagline = tagline
        self.coverURL = coverURL
        self.audioStreamURL = audioStreamURL
        self.durationSeconds = durationSeconds
        self.playsCount = playsCount
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.repostsCount = repostsCount
        self.isLiked = isLiked
        self.isReposted = isReposted
        self.badge = badge
        self.genre = genre
        self.isFeatured = isFeatured
        self.isBeat = isBeat
        self.bpm = bpm
        self.songKey = songKey
        self.waveformSamples = waveformSamples
    }
    
    public var formattedDuration: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    public var fullAuthorDisplay: String {
        if let feat = featuredArtists, !feat.isEmpty {
            return "\(author) ft. \(feat.joined(separator: ", "))"
        }
        return author
    }
}

// MARK: - Post de la pestaña "Fotos" (posts en Supabase)

public struct CommunityPost: Identifiable, Hashable, Codable {
    public let id: String
    public let userId: String
    public let imageURL: URL?
    public let caption: String?
    public var likesCount: Int
    public var isLiked: Bool
    public let createdAt: String
    public let author: UserProfile
    
    public init(
        id: String = UUID().uuidString,
        userId: String = "",
        imageURL: URL?,
        caption: String?,
        likesCount: Int = 0,
        isLiked: Bool = false,
        createdAt: String = "",
        author: UserProfile
    ) {
        self.id = id
        self.userId = userId
        self.imageURL = imageURL
        self.caption = caption
        self.likesCount = likesCount
        self.isLiked = isLiked
        self.createdAt = createdAt
        self.author = author
    }
}

// MARK: - Comentarios de Pistas (comments en Supabase)

public struct TrackComment: Identifiable, Hashable, Codable {
    public let id: String
    public let trackId: String
    public let author: UserProfile
    public let content: String
    public let timestamp: String
    public var likesCount: Int
    public var isLiked: Bool
    
    public init(
        id: String = UUID().uuidString,
        trackId: String,
        author: UserProfile,
        content: String,
        timestamp: String = "ahora",
        likesCount: Int = 0,
        isLiked: Bool = false
    ) {
        self.id = id
        self.trackId = trackId
        self.author = author
        self.content = content
        self.timestamp = timestamp
        self.likesCount = likesCount
        self.isLiked = isLiked
    }
}

// MARK: - Mensaje de Chat (Community & DMs)

public struct ChatMessage: Identifiable, Hashable, Codable {
    public let id: String
    public let sender: UserProfile
    public let content: String
    public let timestamp: String
    public let isMe: Bool
    public let attachmentURL: URL?
    
    public init(
        id: String = UUID().uuidString,
        sender: UserProfile,
        content: String,
        timestamp: String = "ahora",
        isMe: Bool = false,
        attachmentURL: URL? = nil
    ) {
        self.id = id
        self.sender = sender
        self.content = content
        self.timestamp = timestamp
        self.isMe = isMe
        self.attachmentURL = attachmentURL
    }
}

// MARK: - Eventos (events en Supabase)

public struct UnderBroEvent: Identifiable, Hashable, Codable {
    public let id: String
    public let title: String
    public let venue: String
    public let city: String
    public let dateDisplay: String
    public let ticketURL: URL?
    public let creator: UserProfile
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        venue: String,
        city: String,
        dateDisplay: String,
        ticketURL: URL? = nil,
        creator: UserProfile
    ) {
        self.id = id
        self.title = title
        self.venue = venue
        self.city = city
        self.dateDisplay = dateDisplay
        self.ticketURL = ticketURL
        self.creator = creator
    }
}

// MARK: - Velocidades de Reproducción

public enum PlaybackSpeed: Double, CaseIterable, Identifiable {
    case slow = 0.75
    case normal = 1.0
    case fast = 1.25
    case veryFast = 1.5
    case double = 2.0
    
    public var id: Double { rawValue }
    
    public var title: String {
        switch self {
        case .normal: return "1x"
        case .slow: return "0.75x"
        case .fast: return "1.25x"
        case .veryFast: return "1.5x"
        case .double: return "2x"
        }
    }
    
    public mutating func toggleNext() {
        switch self {
        case .normal: self = .fast
        case .fast: self = .veryFast
        case .veryFast: self = .double
        case .double: self = .slow
        case .slow: self = .normal
        }
    }
}

// MARK: - DTOs para Decodificación directa desde Supabase

public struct SupabaseTrackDTO: Codable {
    public let id: String
    public let user_id: String?
    public let title: String
    public let artist: String?
    public let genre: String?
    public let audio_url: String?
    public let cover_url: String?
    public let cover_thumb: String?
    public let duration: Int?
    public let plays: Int?
    public let likes_count: Int?
    public let reposts_count: Int?
    public let is_beat: Bool?
    public let bpm: Int?
    public let song_key: String?
    public let featured: Bool?
    public let description: String?
    public let waveform: [Int]?
    public let collaborators: [CollaboratorDTO]?
    public let profiles: SupabaseProfileDTO?
    
    public struct CollaboratorDTO: Codable {
        public let id: String?
        public let username: String?
        public let display_name: String?
    }
    
    public func toDomain(rank: Int? = nil) -> Track {
        let artists = collaborators?.compactMap { $0.display_name ?? $0.username }
        let normWaveform = waveform?.map { Double($0) / 100.0 }
        
        let authorName = artist ?? profiles?.display_name ?? profiles?.username ?? "UnderBro Artist"
        let cover = cover_thumb ?? cover_url
        
        return Track(
            id: id,
            rank: rank,
            title: title,
            author: authorName,
            featuredArtists: artists,
            isVerified: profiles?.verified ?? false,
            isAlpha: (profiles?.displayed_badge == "alpha"),
            tagline: description,
            coverURL: cover != nil ? URL(string: cover!) : nil,
            audioStreamURL: audio_url != nil ? URL(string: audio_url!) : nil,
            durationSeconds: duration ?? 60,
            playsCount: plays ?? 0,
            likesCount: likes_count ?? 0,
            commentsCount: 0,
            repostsCount: reposts_count ?? 0,
            badge: rank == 1 ? "Nº 1 AHORA MISMO" : (featured == true ? "DESTACADO" : nil),
            genre: genre,
            isFeatured: featured ?? (rank == 1),
            isBeat: is_beat ?? false,
            bpm: bpm,
            songKey: song_key,
            waveformSamples: normWaveform
        )
    }
}

public struct SupabasePostDTO: Codable {
    public let id: String
    public let user_id: String
    public let image_url: String?
    public let caption: String?
    public let likes_count: Int?
    public let created_at: String?
    public let profiles: SupabaseProfileDTO?
    
    public func toDomain() -> CommunityPost {
        let author = profiles?.toDomain() ?? UserProfile(id: user_id, username: "anónimo", displayName: "Anónimo")
        return CommunityPost(
            id: id,
            userId: user_id,
            imageURL: image_url != nil ? URL(string: image_url!) : nil,
            caption: caption,
            likesCount: likes_count ?? 0,
            isLiked: false,
            createdAt: created_at ?? "",
            author: author
        )
    }
}

public struct SupabaseProfileDTO: Codable {
    public let id: String
    public let username: String?
    public let display_name: String?
    public let avatar_url: String?
    public let bio: String?
    public let city: String?
    public let roles: [String]?
    public let verified: Bool?
    public let displayed_badge: String?
    public let theme: SupabaseThemeDTO?
    
    public struct SupabaseThemeDTO: Codable {
        public let banner: String?
        public let links: [LinkDTO]?
        public struct LinkDTO: Codable {
            public let label: String?
            public let url: String?
        }
    }
    
    public func toDomain() -> UserProfile {
        let links = theme?.links?.compactMap { link -> UserProfile.SocialLink? in
            guard let url = link.url, let label = link.label else { return nil }
            return UserProfile.SocialLink(label: label, url: url)
        } ?? []
        
        return UserProfile(
            id: id,
            username: username ?? "usuario",
            displayName: display_name ?? username ?? "Artista",
            avatarURL: avatar_url != nil ? URL(string: avatar_url!) : nil,
            bannerURL: theme?.banner != nil ? URL(string: theme!.banner!) : nil,
            bio: bio,
            city: city,
            roles: roles ?? [],
            isVerified: verified ?? false,
            displayedBadge: displayed_badge,
            socialLinks: links
        )
    }
}

public struct SupabaseCommentDTO: Codable {
    public let id: String
    public let track_id: String
    public let body: String
    public let created_at: String
    public let profiles: SupabaseProfileDTO?
    
    public func toDomain() -> TrackComment {
        let author = profiles?.toDomain() ?? UserProfile(username: "anónimo", displayName: "Anónimo")
        return TrackComment(
            id: id,
            trackId: track_id,
            author: author,
            content: body,
            timestamp: "reciente",
            likesCount: 0,
            isLiked: false
        )
    }
}
