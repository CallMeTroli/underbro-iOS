//
//  UnderBroTrendingView.swift
//  UnderBro iOS
//
//  Pantalla principal "Stream": Incluye los apartados de la aplicación web:
//    - Selector de feed: Tendencias, Nuevo, Siguiendo
//    - Sub-secciones de descubrimiento: Todo, Radio en vivo, Beats (con BPM/Escala), Bro's (Artistas)
//    - Barra de búsqueda global en tiempo real conectada a la base de datos (Usuarios + Canciones)
//    - Carrusel de historias efímeras
//    - Reproducción de pistas conectadas a Supabase con audio streaming real
//

import SwiftUI

public struct UnderBroTrendingView: View {
    public enum SearchScope: String, CaseIterable, Identifiable {
        case todos = "Todo"
        case creadores = "Bro's"
        case canciones = "Canciones"
        
        public var id: String { rawValue }
    }
    
    public enum ProfileDestination: Identifiable {
        case user(UserProfile)
        case artistName(String)
        
        public var id: String {
            switch self {
            case .user(let user): return "user-\(user.id)"
            case .artistName(let name): return "artist-\(name)"
            }
        }
    }
    
    @State private var selectedSegment: FeedSegment = .tendencias
    @State private var selectedDiscoverFilter: DiscoverFilter = .todos
    
    // Dirección del desplazamiento para la transición fluida de menús
    private enum SlideDirection {
        case forward
        case backward
    }
    @State private var slideDirection: SlideDirection = .forward
    
    private var filterTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: slideDirection == .forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: slideDirection == .forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
    
    // Destino para ver Perfil de Usuario / Artista
    @State private var profileDestination: ProfileDestination? = nil
    
    // Estado de Búsqueda Global en Base de Datos
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: GlobalSearchResult = GlobalSearchResult()
    @State private var isSearchingDatabase: Bool = false
    @State private var selectedSearchScope: SearchScope = .todos
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @FocusState private var isSearchFieldFocused: Bool
    
    // Estado de Contenido
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
                VStack(alignment: .leading, spacing: 18) {
                    // Cabecera superior con logotipo y acciones
                    FeedHeaderView(
                        onSearchTapped: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isSearching.toggle()
                                if !isSearching {
                                    searchQuery = ""
                                    searchResults = GlobalSearchResult()
                                    isSearchFieldFocused = false
                                } else {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isSearchFieldFocused = true
                                    }
                                }
                            }
                        },
                        onNotificationsTapped: {},
                        onProfileTapped: {
                            if AuthenticationManager.shared.isAuthenticated, let user = AuthenticationManager.shared.currentUser {
                                profileDestination = .user(user)
                            } else {
                                AuthenticationManager.shared.isLoginSheetPresented = true
                            }
                        }
                    )
                    
                    // Barra de búsqueda expandible
                    if isSearching {
                        searchBarView
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        
                        // Resultados de la búsqueda global en base de datos (Usuarios + Canciones)
                        databaseSearchResultsView
                    } else {
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
                        
                        // Contenido según el filtro activo con soporte de deslizamiento lateral (swipe)
                        filterContentView
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.always, axes: .vertical)
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .refreshable {
                await refreshData()
            }
            .task {
                loadInitialData()
            }
            .sheet(item: $profileDestination) { destination in
                switch destination {
                case .user(let user):
                    ArtistProfileView(user: user)
                case .artistName(let artistName):
                    ArtistProfileView(artistName: artistName)
                }
            }
        }
    }
    
    // MARK: - Barra de Búsqueda Global
    
    private var searchBarView: some View {
        HStack(spacing: 10) {
            if isSearchingDatabase {
                ProgressView()
                    .tint(UBTheme.accentCyan)
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(UBTheme.textSecondary)
            }
            
            TextField("Buscar artistas, productores o canciones...", text: $searchQuery)
                .focused($isSearchFieldFocused)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .onSubmit {
                    performDatabaseSearch(query: searchQuery, immediate: true)
                }
                .onChange(of: searchQuery) { _, newValue in
                    performDatabaseSearch(query: newValue)
                }
            
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = GlobalSearchResult()
                    isSearchingDatabase = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(UBTheme.textTertiary)
                }
            }
            
            Button("Cancelar") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isSearching = false
                    searchQuery = ""
                    searchResults = GlobalSearchResult()
                    isSearchingDatabase = false
                    isSearchFieldFocused = false
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(UBTheme.accentEnd)
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Resultados de Búsqueda Global en Base de Datos
    
    private var databaseSearchResultsView: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Selector de ámbito (Todo / Bro's / Canciones)
            if !searchQuery.isEmpty {
                searchScopeBar
                    .padding(.horizontal, 16)
            }
            
            if isSearchingDatabase {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(UBTheme.accentCyan)
                    Text("Buscando en la base de datos de UnderBro...")
                        .font(.caption)
                        .foregroundStyle(UBTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 16)
            } else if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                // Sugerencias de búsqueda al abrir
                searchSuggestionsView
                    .padding(.horizontal, 16)
            } else if searchResults.isEmpty {
                // Estado vacío de búsqueda
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 38))
                        .foregroundStyle(UBTheme.textTertiary)
                    Text("Sin resultados para \"\(searchQuery)\"")
                        .font(.headline)
                        .foregroundStyle(UBTheme.textPrimary)
                    Text("No se encontraron usuarios ni pistas en la base de datos de UnderBro.")
                        .font(.caption)
                        .foregroundStyle(UBTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 16)
            } else {
                // Resultados agrupados según el ámbito
                VStack(alignment: .leading, spacing: 20) {
                    // Sección: Bro's y Artistas
                    if (selectedSearchScope == .todos || selectedSearchScope == .creadores) && !searchResults.users.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Bro's & Artistas")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(UBTheme.textPrimary)
                                Spacer()
                                Text("\(searchResults.users.count)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(UBTheme.accentEnd)
                                    .glassEffect(.regular.tint(UBTheme.accentEnd.opacity(0.2)), in: .capsule)
                            }
                            
                            VStack(spacing: 10) {
                                ForEach(searchResults.users) { user in
                                    searchedUserCard(user)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Sección: Canciones y Beats
                    if (selectedSearchScope == .todos || selectedSearchScope == .canciones) && !searchResults.tracks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Canciones & Beats")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(UBTheme.textPrimary)
                                Spacer()
                                Text("\(searchResults.tracks.count)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(UBTheme.accentCyan)
                                    .glassEffect(.regular.tint(UBTheme.accentCyan.opacity(0.2)), in: .capsule)
                            }
                            
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults.tracks) { track in
                                    TrackRow(
                                        track: track,
                                        allTracks: searchResults.tracks,
                                        onAuthorTapped: {
                                            profileDestination = .artistName(track.author)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
    
    private var searchScopeBar: some View {
        HStack(spacing: 8) {
            ForEach(SearchScope.allCases) { scope in
                let isSelected = selectedSearchScope == scope
                let count: Int = {
                    switch scope {
                    case .todos: return searchResults.users.count + searchResults.tracks.count
                    case .creadores: return searchResults.users.count
                    case .canciones: return searchResults.tracks.count
                    }
                }()
                
                if isSelected {
                    Button {
                        selectedSearchScope = scope
                    } label: {
                        Text("\(scope.rawValue) (\(count))")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentStart)
                } else {
                    Button {
                        selectedSearchScope = scope
                    } label: {
                        Text("\(scope.rawValue) (\(count))")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                }
            }
            Spacer()
        }
    }
    
    private func searchedUserCard(_ user: UserProfile) -> some View {
        HStack(spacing: 12) {
            if let avatar = user.avatarURL {
                AsyncImage(url: avatar) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        PlaceholderAvatarView(username: user.username, size: 44, hasNewStory: false)
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            } else {
                PlaceholderAvatarView(username: user.username, size: 44, hasNewStory: false)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(user.displayName.isEmpty ? user.username : user.displayName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(UBTheme.textPrimary)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(UBTheme.accentEnd)
                    }
                    
                    if let badge = user.displayedBadge, !badge.isEmpty {
                        Text(badge.uppercased())
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .foregroundStyle(UBTheme.accentGold)
                            .glassEffect(.regular.tint(UBTheme.accentGold.opacity(0.2)), in: .capsule)
                    }
                }
                
                HStack(spacing: 4) {
                    Text("@\(user.username)")
                        .font(.caption2)
                        .foregroundStyle(UBTheme.textSecondary)
                    
                    if let city = user.city, !city.isEmpty {
                        Text("· \(city)")
                            .font(.caption2)
                            .foregroundStyle(UBTheme.textTertiary)
                    }
                }
                
                if !user.roles.isEmpty {
                    Text(user.roles.joined(separator: " • ").capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(UBTheme.accentCyan)
                }
            }
            
            Spacer()
            
            Button("Ver") {
                profileDestination = .user(user)
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .buttonStyle(.glass)
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            profileDestination = .user(user)
        }
    }
    
    private var searchSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Búsqueda Global en Tiempo Real")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(UBTheme.textPrimary)
            
            Text("Busca directamente en la base de datos de UnderBro tanto creadores como temas musicales.")
                .font(.caption)
                .foregroundStyle(UBTheme.textSecondary)
            
            Text("Sugerencias populares:")
                .font(.caption2.weight(.bold))
                .foregroundStyle(UBTheme.textTertiary)
                .padding(.top, 4)
            
            let suggestions = ["kkikheroina", "akuma", "eighteen", "###sol", "MALA", "drill", "reggaeton", "ambient"]
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { term in
                        Button {
                            searchQuery = term
                            performDatabaseSearch(query: term, immediate: true)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 10))
                                Text(term)
                                    .font(.caption.weight(.medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Filtros de Descubrimiento (Discover Pills)
    
    private var discoverPillsView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscoverFilter.allCases) { filter in
                        let isSelected = selectedDiscoverFilter == filter
                        
                        Button {
                            let all = DiscoverFilter.allCases
                            if let currIdx = all.firstIndex(of: selectedDiscoverFilter),
                               let newIdx = all.firstIndex(of: filter) {
                                slideDirection = newIdx >= currIdx ? .forward : .backward
                            }
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedDiscoverFilter = filter
                            }
                            handleDiscoverFilterChange(filter)
                        } label: {
                            Text(filter.rawValue)
                                .font(.subheadline.weight(isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .white : UBTheme.textSecondary)
                                .padding(.horizontal, 16)
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
                        .id(filter)
                    }
                }
            }
            .onChange(of: selectedDiscoverFilter) { _, newFilter in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newFilter, anchor: .center)
                }
            }
        }
    }
    
    // MARK: - Contenedor con Deslizamiento Táctil (Swipe Gestures)
    
    private var filterContentView: some View {
        Group {
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
        .id(selectedDiscoverFilter)
        .transition(filterTransition)
        .frame(maxWidth: .infinity, minHeight: 450, alignment: .topLeading)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    handleHorizontalSwipe(value)
                }
        )
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
                            FeaturedTrackCard(
                                track: track,
                                allTracks: tracks,
                                onAuthorTapped: {
                                    profileDestination = .artistName(track.author)
                                }
                            )
                        } else {
                            TrackRow(
                                track: track,
                                allTracks: tracks,
                                onAuthorTapped: {
                                    profileDestination = .artistName(track.author)
                                }
                            )
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
                    TrackRow(
                        track: beat,
                        allTracks: tracks,
                        onAuthorTapped: {
                            profileDestination = .artistName(beat.author)
                        }
                    )
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
                    .foregroundStyle(UBTheme.accentPink)
                Spacer()
                Text("Entradas disponibles")
                    .font(.caption2)
                    .foregroundStyle(Color.green)
            }
            
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(UBTheme.textPrimary)
            
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(UBTheme.accentEnd)
                Text(venue)
                    .font(.caption)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            
            Text("Artistas: \(artists)")
                .font(.caption2)
                .foregroundStyle(UBTheme.textTertiary)
                .padding(.top, 2)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    
    // MARK: - Sub-sección: Bro's (Artistas y Creadores)
    
    private var brosSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bro's & Creadores")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(UBTheme.textPrimary)
                Text("Productores, cantantes y diseñadores activos en la comunidad.")
                    .font(.subheadline)
                    .foregroundStyle(UBTheme.textSecondary)
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                ForEach(artists) { artist in
                    HStack(spacing: 12) {
                        PlaceholderAvatarView(
                            username: artist.username,
                            size: 46,
                            hasNewStory: true,
                            isVerified: artist.isVerified
                        )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(artist.displayName.isEmpty ? artist.username : artist.displayName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(UBTheme.textPrimary)
                                
                                if artist.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption2)
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
                    .contentShape(Rectangle())
                    .onTapGesture {
                        profileDestination = .user(artist)
                    }
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
    
    // MARK: - Carga de Datos y Búsqueda en Base de Datos
    
    private func performDatabaseSearch(query: String, immediate: Bool = false) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = GlobalSearchResult()
            isSearchingDatabase = false
            searchDebounceTask?.cancel()
            return
        }
        
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
            }
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.isSearchingDatabase = true
            }
            
            do {
                let results = try await apiService.searchGlobal(query: trimmed)
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.searchResults = results
                    self.isSearchingDatabase = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.isSearchingDatabase = false
                }
            }
        }
    }
    
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
    
    // MARK: - Navegación y Gestos entre Menús de Descubrimiento (Swipe)
    
    private func handleHorizontalSwipe(_ value: DragGesture.Value) {
        let horizontalAmount = value.translation.width
        let verticalAmount = value.translation.height
        
        // Comprobar que el gesto sea predominantemente horizontal para preservar el scroll vertical
        guard abs(horizontalAmount) > abs(verticalAmount) * 1.25 else { return }
        
        let threshold: CGFloat = 35
        let predictedThreshold: CGFloat = 80
        
        if horizontalAmount < -threshold || value.predictedEndTranslation.width < -predictedThreshold {
            // Deslizar hacia la izquierda (dedo de derecha a izquierda) -> siguiente menú
            selectNextDiscoverFilter()
        } else if horizontalAmount > threshold || value.predictedEndTranslation.width > predictedThreshold {
            // Deslizar hacia la derecha (dedo de izquierda a derecha) -> menú anterior
            selectPreviousDiscoverFilter()
        }
    }
    
    private func selectNextDiscoverFilter() {
        let all = DiscoverFilter.allCases
        guard let currentIndex = all.firstIndex(of: selectedDiscoverFilter),
              currentIndex < all.count - 1 else { return }
        let nextFilter = all[currentIndex + 1]
        slideDirection = .forward
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            selectedDiscoverFilter = nextFilter
        }
        handleDiscoverFilterChange(nextFilter)
    }
    
    private func selectPreviousDiscoverFilter() {
        let all = DiscoverFilter.allCases
        guard let currentIndex = all.firstIndex(of: selectedDiscoverFilter),
              currentIndex > 0 else { return }
        let prevFilter = all[currentIndex - 1]
        slideDirection = .backward
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            selectedDiscoverFilter = prevFilter
        }
        handleDiscoverFilterChange(prevFilter)
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
    
    // MARK: - Pull to Refresh
    
    private func refreshData() async {
        do {
            // Esto se dispara al deslizar hacia abajo (Pull-to-refresh)
            let updatedTracks = try await UnderBroServices.api.fetchFeed(segment: selectedSegment)
            let updatedStories = (try? await UnderBroServices.api.fetchStories()) ?? stories
            await MainActor.run {
                self.tracks = updatedTracks
                self.stories = updatedStories
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
