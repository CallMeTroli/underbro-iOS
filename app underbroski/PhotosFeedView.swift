//
//  PhotosFeedView.swift
//  UnderBro iOS
//
//  Vista de la pestaña "Fotos": Feed visual y comunidad de UnderBro
//  Conectado en directo a la API de Supabase (`posts` y `profiles`)
//  Diseño nativo iOS 26+ con Liquid Glass, Lightbox y publicación.
//

import SwiftUI

public struct PhotosFeedView: View {
    @State private var posts: [CommunityPost] = []
    @State private var isLoading: Bool = true
    @State private var selectedFilter: PhotoFilter = .recientes
    @State private var selectedPostForDetail: CommunityPost? = nil
    @State private var isShowingUploadSheet: Bool = false
    @State private var activeCommentPost: CommunityPost? = nil
    
    public enum PhotoFilter: String, CaseIterable, Identifiable {
        case recientes = "Recientes"
        case populares = "Destacadas"
        case visuales = "Arte & Visuales"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .recientes: return "clock.fill"
            case .populares: return "flame.fill"
            case .visuales: return "camera.macro"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Cabecera con botón de acción directa
                    headerSection
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // Selector de filtros en píldoras Liquid Glass
                    filtersBar
                        .padding(.horizontal, 16)
                    
                    // Contenido del Feed
                    if isLoading {
                        loadingShimmerGrid
                            .padding(.horizontal, 16)
                    } else if filteredPosts.isEmpty {
                        emptyStateView
                            .padding(.horizontal, 16)
                    } else {
                        // Feed dinámico tipo comunidad
                        LazyVStack(spacing: 20) {
                            ForEach(filteredPosts) { post in
                                CommunityPostCard(
                                    post: post,
                                    onTapImage: {
                                        selectedPostForDetail = post
                                    },
                                    onToggleLike: {
                                        toggleLike(for: post)
                                    },
                                    onOpenComments: {
                                        activeCommentPost = post
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer(minLength: 140) // Margen para el mini-player flotante y tab bar
                }
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .refreshable {
                await loadPosts()
            }
            .task {
                await loadPosts()
            }
            .sheet(isPresented: $isShowingUploadSheet) {
                UploadPhotoSheet { newPost in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        posts.insert(newPost, at: 0)
                    }
                }
            }
            .sheet(item: $activeCommentPost) { post in
                PostCommentsSheet(post: post)
            }
            #if os(iOS)
            .fullScreenCover(item: $selectedPostForDetail) { post in
                PhotoLightboxView(post: post)
            }
            #else
            .sheet(item: $selectedPostForDetail) { post in
                PhotoLightboxView(post: post)
            }
            #endif
        }
    }
    
    // MARK: - Componentes de la Vista
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Fotos & Escena")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(UBTheme.textPrimary)
                    
                    Circle()
                        .fill(UBTheme.accentPink)
                        .frame(width: 8, height: 8)
                }
                
                Text("Capturas, directos y visuales underground")
                    .font(.subheadline)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            
            Spacer()
            
            Button {
                isShowingUploadSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                    Text("Publicar")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(UBTheme.accentStart)
        }
    }
    
    private var filtersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PhotoFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    
                    if isSelected {
                        Button {
                            selectedFilter = filter
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.icon)
                                Text(filter.rawValue)
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(UBTheme.accentStart)
                    } else {
                        Button {
                            selectedFilter = filter
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: filter.icon)
                                Text(filter.rawValue)
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
    
    private var filteredPosts: [CommunityPost] {
        switch selectedFilter {
        case .recientes:
            return posts
        case .populares:
            return posts.sorted { $0.likesCount > $1.likesCount }
        case .visuales:
            return posts.filter { $0.caption?.contains("#") == true || $0.imageURL != nil }
        }
    }
    
    private var loadingShimmerGrid: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(UBTheme.surfaceElevated.opacity(0.6))
                    .frame(height: 320)
                    .overlay(ProgressView().tint(UBTheme.accentStart))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(UBTheme.textTertiary)
            
            Text("No hay fotos en esta sección")
                .font(.headline)
                .foregroundStyle(UBTheme.textPrimary)
            
            Text("Sé el primero en compartir un momento de tu sesión.")
                .font(.subheadline)
                .foregroundStyle(UBTheme.textSecondary)
                .multilineTextAlignment(.center)
            
            Button("Subir una foto") {
                isShowingUploadSheet = true
            }
            .buttonStyle(.glassProminent)
            .tint(UBTheme.accentStart)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    
    // MARK: - Acciones y API
    
    private func loadPosts() async {
        isLoading = true
        do {
            let fetched = try await UnderBroServices.api.fetchCommunityPosts()
            await MainActor.run {
                self.posts = fetched
                self.isLoading = false
            }
        } catch {
            print("Error cargando fotos de UnderBro: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func toggleLike(for targetPost: CommunityPost) {
        guard let index = posts.firstIndex(where: { $0.id == targetPost.id }) else { return }
        let currentStatus = posts[index].isLiked
        posts[index].isLiked.toggle()
        posts[index].likesCount += currentStatus ? -1 : 1
        
        Task {
            _ = try? await UnderBroServices.api.togglePostLike(postId: targetPost.id)
        }
    }
}

// MARK: - Tarjeta de Publicación con Liquid Glass

public struct CommunityPostCard: View {
    public let post: CommunityPost
    public let onTapImage: () -> Void
    public let onToggleLike: () -> Void
    public let onOpenComments: () -> Void
    
    public init(
        post: CommunityPost,
        onTapImage: @escaping () -> Void,
        onToggleLike: @escaping () -> Void,
        onOpenComments: @escaping () -> Void
    ) {
        self.post = post
        self.onTapImage = onTapImage
        self.onToggleLike = onToggleLike
        self.onOpenComments = onOpenComments
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cabecera: Autor y fecha
            HStack(spacing: 10) {
                if let avatar = post.author.avatarURL {
                    AsyncImage(url: avatar) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            PlaceholderAvatarView(username: post.author.username, size: 38, hasNewStory: false)
                        }
                    }
                    .frame(width: 38, height: 38)
                    .clipShape(Circle())
                } else {
                    PlaceholderAvatarView(username: post.author.username, size: 38, hasNewStory: false)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.author.displayName.isEmpty ? post.author.username : post.author.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(UBTheme.textPrimary)
                        
                        if post.author.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(UBTheme.accentEnd)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text("@\(post.author.username)")
                            .font(.caption2)
                            .foregroundStyle(UBTheme.textSecondary)
                        
                        if let city = post.author.city, !city.isEmpty {
                            Text("· \(city)")
                                .font(.caption2)
                                .foregroundStyle(UBTheme.textTertiary)
                        }
                    }
                }
                
                Spacer()
                
                // Menú de opciones
                Menu {
                    Button(action: {}) {
                        Label("Compartir post", systemImage: "square.and.arrow.up")
                    }
                    Button(action: {}) {
                        Label("Copiar enlace", systemImage: "link")
                    }
                    Button(role: .destructive, action: {}) {
                        Label("Reportar", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(UBTheme.textSecondary)
                        .padding(8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            
            // Imagen de la publicación
            ZStack {
                if let url = post.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 280)
                                .clipped()
                        case .failure:
                            PlaceholderArtworkView(
                                style: .deepIndigo,
                                titleHint: post.caption ?? "UnderBro Visual",
                                systemIcon: "photo",
                                cornerRadius: 16
                            )
                            .frame(height: 280)
                        case .empty:
                            Rectangle()
                                .fill(UBTheme.surfaceElevated)
                                .frame(height: 280)
                                .overlay(ProgressView().tint(UBTheme.accentStart))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    PlaceholderArtworkView(
                        style: .vibrantGold,
                        titleHint: post.caption ?? "UnderBro Visual",
                        systemIcon: "camera.fill",
                        cornerRadius: 16
                    )
                    .frame(height: 280)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 10)
            .onTapGesture {
                onTapImage()
            }
            
            // Fila de acciones interactivas
            HStack(spacing: 18) {
                // Like
                Button {
                    onToggleLike()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(post.isLiked ? UBTheme.accentPink : UBTheme.textPrimary)
                        
                        Text("\(post.likesCount)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(UBTheme.textPrimary)
                    }
                }
                .buttonStyle(.plain)
                
                // Comentarios
                Button {
                    onOpenComments()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(UBTheme.textPrimary)
                        
                        Text("Comentar")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(UBTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                
                // Compartir
                ShareLink(item: post.imageURL ?? URL(string: "https://underbro.app")!) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(UBTheme.textPrimary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Guardar
                Button(action: {}) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 17))
                        .foregroundStyle(UBTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            
            // Caption y autor
            if let caption = post.caption, !caption.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(post.author.username)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(UBTheme.textPrimary)
                        
                        Text(caption)
                            .font(.subheadline)
                            .foregroundStyle(UBTheme.textSecondary)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(UBTheme.surfaceElevated.opacity(0.45))
        )
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// MARK: - Modal de Subir Foto a la Comunidad

public struct UploadPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let onPostCreated: (CommunityPost) -> Void
    
    @State private var caption: String = ""
    @State private var imageURLString: String = ""
    @State private var isUploading: Bool = false
    
    public init(onPostCreated: @escaping (CommunityPost) -> Void) {
        self.onPostCreated = onPostCreated
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Preview de la foto o selector
                    ZStack {
                        if let url = URL(string: imageURLString), !imageURLString.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().scaledToFill()
                                default:
                                    previewPlaceholder
                                }
                            }
                        } else {
                            previewPlaceholder
                        }
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 16)
                    
                    // URL o Selección
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enlace a la imagen o foto")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(UBTheme.textSecondary)
                        
                        TextField("https://...", text: $imageURLString)
                            .padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    
                    // Pie de foto / Caption
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Descripción / Hashtags")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(UBTheme.textSecondary)
                        
                        TextField("Escribe sobre esta sesión o visual...", text: $caption, axis: .vertical)
                            .lineLimit(3...5)
                            .padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    
                    // Botón publicar
                    Button {
                        publishPost()
                    } label: {
                        HStack(spacing: 8) {
                            if isUploading {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "camera.fill")
                                Text("Compartir con la Escena")
                            }
                        }
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentStart)
                    .disabled(caption.isEmpty || isUploading)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                }
                .padding(.vertical, 16)
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .navigationTitle("Nueva Foto")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
    
    private var previewPlaceholder: some View {
        PlaceholderArtworkView(
            style: .deepIndigo,
            titleHint: "Tu Foto",
            systemIcon: "photo.badge.plus",
            cornerRadius: 18
        )
    }
    
    private func publishPost() {
        isUploading = true
        Task {
            let imgURL = URL(string: imageURLString)
            let newPost = try? await UnderBroServices.api.createPost(caption: caption, imageURL: imgURL)
            await MainActor.run {
                isUploading = false
                if let newPost = newPost {
                    onPostCreated(newPost)
                }
                dismiss()
            }
        }
    }
}

// MARK: - Lightbox para Ver Foto en Detalle

public struct PhotoLightboxView: View {
    @Environment(\.dismiss) private var dismiss
    public let post: CommunityPost
    
    public init(post: CommunityPost) {
        self.post = post
    }
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Barra superior
                HStack {
                    HStack(spacing: 10) {
                        PlaceholderAvatarView(username: post.author.username, size: 32, hasNewStory: false)
                        Text("@\(post.author.username)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                
                Spacer()
                
                // Imagen centrada
                if let url = post.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                        default:
                            PlaceholderArtworkView(
                                style: .vibrantGold,
                                titleHint: post.caption ?? "Foto",
                                systemIcon: "photo",
                                cornerRadius: 0
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Caption en la parte inferior
                if let caption = post.caption {
                    Text(caption)
                        .font(.body)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(20)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(16)
                }
            }
        }
    }
}

// MARK: - Hoja de Comentarios de Publicación

public struct PostCommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let post: CommunityPost
    @State private var commentText: String = ""
    @State private var comments: [String] = [
        "Temazo visual bro 🔥",
        "El estudio se ve épico",
        "Dime qué synth es ese!"
    ]
    
    public init(post: CommunityPost) {
        self.post = post
    }
    
    public var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(comments, id: \.self) { c in
                            HStack(alignment: .top, spacing: 12) {
                                PlaceholderAvatarView(username: "bro", size: 34, hasNewStory: false)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("bro_underground")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(UBTheme.textPrimary)
                                    Text(c)
                                        .font(.subheadline)
                                        .foregroundStyle(UBTheme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(16)
                }
                
                // Barra para escribir comentario
                HStack(spacing: 10) {
                    TextField("Añadir un comentario...", text: $commentText)
                        .padding(12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                    
                    Button {
                        guard !commentText.isEmpty else { return }
                        comments.append(commentText)
                        commentText = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentStart)
                    .disabled(commentText.isEmpty)
                }
                .padding(16)
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .navigationTitle("Comentarios")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .buttonStyle(.glass)
                }
            }
        }
    }
}
