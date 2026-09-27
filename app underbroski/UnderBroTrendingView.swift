//
//  UnderBroTrendingView.swift
//  UnderBro iOS
//
//  Pantalla principal "Stream": Incluye los apartados de la aplicación web:
//    - Selector de feed: Tendencias, Nuevo, Siguiendo
//    - Sub-secciones de descubrimiento: Todo, Radio en vivo, Beats (con BPM/Escala), Bro's (Artistas)
//    - Barra de búsqueda interactiva
//    - Carrusel de historias efímeras
//    - Reproducción de pistas conectadas a Supabase con audio streaming real
//

import SwiftUI

public struct UnderBroTrendingView: View {
    @State private var selectedSegment: FeedSegment = .tendencias
    @State private var selectedDiscoverFilter: DiscoverFilter = .todos
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    
    @State private var stories: [Story] = []
    @State private var tracks: [Track] = []
    @State private var artists: [UserProfile] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    @ObservedObject var player: AudioPlayerService = .shared
    private let apiService: UnderBroAPIServiceProtocol = UnderBroServices.api
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Cabecera superior con logotipo y acciones
                    FeedHeaderView(
                        onSearchTapped: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isSearching.toggle()
                            }
                        },
                        onNotificationsTapped: {},
                        onProfileTapped: {}
                    )
                    
                    // Barra de búsqueda expandible
                    if isSearching {
                        searchBarView
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Segmentos principales (Tendencias / Nuevo / Siguiendo)
                    SegmentedPillBar(selectedSegment: $selectedSegment)
                        .onChange(of: selectedSegment) {
                            loadFeedData()
                        }
                    
                    // Píldoras de descubrimiento secundarias (Todo / Radio / Beats / Bro's)
                    discoverPillsView
                        .padding(.horizontal, 16)
                    
                    // Carrusel de historias efímeras
                    if !stories.isEmpty && selectedDiscoverFilter == .todos {
                        StoriesCarouselView(
                            stories: stories,
                            onSelectStory: { _ in },
                            onAddStory: {}
                        )
                    }
                    
                    // Contenido según el filtro activo
                    switch selectedDiscoverFilter {
                    case .todos:
                        standardFeedView
                    case .radio:
                        radioStreamSection
                    case .beats:
                        beatsSectionView
                    case .eventos:
                        eventsSectionView
                    case .bros:
                        brosSectionView
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .refreshable {
                await refreshData()
            }
            .task {
                loadInitialData()
            }
        }
    }
    
    // MARK: - Barra de Búsqueda
    
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(UBTheme.textSecondary)
            
            TextField("Buscar en UnderBro…", text: $searchQuery)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .onSubmit {
                    performSearch()
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    loadFeedData()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(UBTheme.textTertiary)
                }
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Filtros de Descubrimiento (Discover Pills)
    
    private var discoverPillsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DiscoverFilter.allCases) { filter in
                    let isSelected = selectedDiscoverFilter == filter
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedDiscoverFilter = filter
                        }
                        handleDiscoverFilterChange(filter)
                    } label: {
                        Text(filter.rawValue)
                            .font(.caption.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .white : UBTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .glassEffect(.regular.tint(UBTheme.accentEnd).interactive(), in: .capsule)
                                } else {
                                    Capsule()
                                        .glassEffect(.regular.interactive(), in: .capsule)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Feed Estándar de Pistas
    
    private var standardFeedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Encabezado
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSegment.rawValue)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(UBTheme.textPrimary)
                
                Text(selectedSegment == .tendencias ? "Lo que está pegando estos días" : "Lo último que se ha subido")
                    .font(.subheadline)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            
            if isLoading && tracks.isEmpty {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else if let error = errorMessage {
                errorStateView(error)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(tracks) { track in
                        if track.rank == 1 || track.isFeatured {
                            FeaturedTrackCard(track: track)
                        } else {
                            CompactTrackCard(track: track)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Sub-sección: Radio en Vivo
    
    private var radioStreamSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("UnderBro Radio")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(UBTheme.textPrimary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(UBTheme.brandGradient)
                            .frame(width: 64, height: 64)
                        Image(systemName: "radio.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text("EN DIRECTO")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.red)
                        }
                        
                        Text("Transmisión Comunitaria 24/7")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("Sesión non-stop de música underground y remixes exclusivos.")
                            .font(.caption)
                            .foregroundStyle(UBTheme.textSecondary)
                    }
                }
                
                Button {
                    if let firstTrack = tracks.first {
                        player.playTrack(firstTrack, from: tracks)
                    }
                } label: {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("Sintonizar Radio")
                    }
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.glassProminent)
                .tint(UBTheme.accentEnd)
            }
            .padding(18)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Sub-sección: Beats e Instrumentales
    
    private var beatsSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Beats & Instrumentales")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(UBTheme.textPrimary)
                Text("Bases para productores, cantantes y freestyle con BPM y escala.")
                    .font(.subheadline)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(tracks.filter { $0.isBeat }) { beat in
                    CompactTrackCard(track: beat)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Sub-sección: Eventos
    
    private var eventsSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Eventos & Directos")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(UBTheme.textPrimary)
                Text("Conciertos, showcases y fiestas underground de la escena.")
                    .font(.subheadline)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                eventCard(
                    title: "UnderBro Showcase #03",
                    date: "Próximo Viernes · 23:00",
                    venue: "Sala Cadavra, Madrid",
                    artists: "kkikheroina, Jetea, Perky Mafia"
                )
                
                eventCard(
                    title: "Rave Subterránea Plugg & Wave",
                    date: "14 Octubre · 01:00",
                    venue: "Razzmatazz 3, Barcelona",
                    artists: "calimero, Gachas, Pai"
                )
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func eventCard(title: String, date: String, venue: String, artists: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(date)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(UBTheme.accentCyan)
                Spacer()
                Text("Entradas")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassEffect(.regular, in: .capsule)
            }
            
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            
            Text(venue)
                .font(.caption)
                .foregroundStyle(UBTheme.textSecondary)
            
            Text("Lineup: \(artists)")
                .font(.caption2)
                .foregroundStyle(UBTheme.textTertiary)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Sub-sección: Bro's (Artistas y Productores)
    
    private var brosSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bro's de la Escena")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(UBTheme.textPrimary)
                Text("Descubre productores, cantantes y creadores registrados en UnderBro.")
                    .font(.subheadline)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            
            LazyVStack(spacing: 12) {
                ForEach(artists) { artist in
                    HStack(spacing: 14) {
                        PlaceholderAvatarView(
                            username: artist.username,
                            size: 52,
                            hasNewStory: false,
                            isVerified: artist.isVerified
                        )
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(artist.displayName)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                if artist.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(UBTheme.accentEnd)
                                }
                            }
                            
                            Text("@\(artist.username)\(artist.city != nil ? " · \(artist.city!)" : "")")
                                .font(.caption)
                                .foregroundStyle(UBTheme.textSecondary)
                            
                            if !artist.roles.isEmpty {
                                Text(artist.roles.joined(separator: " • ").capitalized)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(UBTheme.accentCyan)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            // Seguir
                        } label: {
                            Text("Seguir")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glass)
                    }
                    .padding(12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func errorStateView(_ error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(UBTheme.accentPink)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(UBTheme.textSecondary)
            Button("Reintentar") {
                loadFeedData()
            }
            .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    // MARK: - Carga de Datos
    
    private func handleDiscoverFilterChange(_ filter: DiscoverFilter) {
        switch filter {
        case .todos:
            loadFeedData()
        case .beats:
            Task {
                isLoading = true
                if let beats = try? await apiService.fetchBeats() {
                    await MainActor.run {
                        self.tracks = beats
                        self.isLoading = false
                    }
                }
            }
        case .bros:
            Task {
                if let fetchedProfiles = try? await apiService.fetchProfiles() {
                    await MainActor.run {
                        self.artists = fetchedProfiles
                    }
                }
            }
        case .radio, .eventos:
            break
        }
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        Task {
            isLoading = true
            if let results = try? await apiService.searchTracks(query: searchQuery) {
                await MainActor.run {
                    self.tracks = results
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadInitialData() {
        Task {
            isLoading = true
            async let storiesTask = apiService.fetchStories()
            async let feedTask = apiService.fetchFeed(segment: selectedSegment)
            async let profilesTask = apiService.fetchProfiles()
            
            do {
                let (fetchedStories, fetchedTracks, fetchedProfiles) = try await (storiesTask, feedTask, profilesTask)
                await MainActor.run {
                    self.stories = fetchedStories
                    self.tracks = fetchedTracks
                    self.artists = fetchedProfiles
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadFeedData() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let fetchedTracks = try await apiService.fetchFeed(segment: selectedSegment)
                await MainActor.run {
                    self.tracks = fetchedTracks
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func refreshData() async {
        do {
            async let storiesTask = apiService.fetchStories()
            async let feedTask = apiService.fetchFeed(segment: selectedSegment)
            let (fetchedStories, fetchedTracks) = try await (storiesTask, feedTask)
            self.stories = fetchedStories
            self.tracks = fetchedTracks
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
