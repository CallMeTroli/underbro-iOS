//
//  ChatListView.swift
//  UnderBro iOS
//
//  Vista de la pestaña "Chat":
//  Incluye las 3 sub-secciones completas de la web app:
//    1. "Comunidad": Chat general en vivo de la escena con contador de conectados
//    2. "Directos": Mensajes privados (DMs) entre artistas y productores
//    3. "Bro's Online": Directorio de creadores activos en vivo para colaborar
//  Diseño nativo iOS 26+ con Liquid Glass y celdas translúcidas.
//

import SwiftUI

public struct ChatListView: View {
    public enum ChatSection: String, CaseIterable, Identifiable {
        case comunidad = "Comunidad"
        case directos = "Directos (DMs)"
        case online = "Bro's Online"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .comunidad: return "bubble.left.and.bubble.right.fill"
            case .directos: return "envelope.badge.fill"
            case .online: return "person.2.wave.2.fill"
            }
        }
    }
    
    @State private var selectedSection: ChatSection = .comunidad
    
    // Estado de la comunidad
    @State private var communityMessages: [ChatMessage] = []
    @State private var newCommunityText: String = ""
    @State private var isLoadingCommunity: Bool = true
    
    // Estado de DMs
    public struct DMChatItem: Identifiable {
        public let id = UUID()
        public let user: UserProfile
        public var lastMessage: String
        public var time: String
        public var unreadCount: Int
        public var isOnline: Bool
    }
    
    @State private var directChats: [DMChatItem] = [
        DMChatItem(
            user: UserProfile(username: "kkikheroina", displayName: "kkikheroina", city: "Madrid", isVerified: true),
            lastMessage: "¿Te mola la mezcla que subí hoy con el beat de 140bpm?",
            time: "16:20",
            unreadCount: 2,
            isOnline: true
        ),
        DMChatItem(
            user: UserProfile(username: "Jetea", displayName: "Jetea", city: "Barcelona", isVerified: true),
            lastMessage: "Mándame el archivo .wav del verso sin compresión",
            time: "Ayer",
            unreadCount: 0,
            isOnline: true
        ),
        DMChatItem(
            user: UserProfile(username: "calimero", displayName: "calimero", city: "Valencia", isVerified: true),
            lastMessage: "Nos vemos en el estudio el viernes para cerrar la colabo 🎙️",
            time: "Mar",
            unreadCount: 0,
            isOnline: false
        ),
        DMChatItem(
            user: UserProfile(username: "Pai", displayName: "Pai Beats", city: "Madrid", isVerified: false),
            lastMessage: "Te pasé la instrumental de Drill en el drive",
            time: "18 Sep",
            unreadCount: 1,
            isOnline: false
        )
    ]
    
    @State private var selectedDM: DMChatItem? = nil
    
    // Estado de Bro's Online
    @State private var onlineProfiles: [UserProfile] = []
    @State private var isLoadingProfiles: Bool = true
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Cabecera superior
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                
                // Segmented Switcher Liquid Glass
                segmentedPillBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                
                // Contenido dinámico según la sección seleccionada
                ZStack {
                    switch selectedSection {
                    case .comunidad:
                        communityChatView
                    case .directos:
                        directMessagesView
                    case .online:
                        onlineBrosView
                    }
                }
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .task {
                await loadCommunityMessages()
                await loadOnlineProfiles()
            }
            .sheet(item: $selectedDM) { dm in
                DirectChatThreadSheet(dm: dm)
            }
        }
    }
    
    // MARK: - Barra de Cabecera
    
    private var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Chat & Colabos")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(UBTheme.textPrimary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text("18 creadores underground conectados")
                        .font(.caption)
                        .foregroundStyle(UBTheme.textSecondary)
                }
            }
            
            Spacer()
            
            // Botón nuevo chat
            Button {
                selectedSection = .online
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.semibold))
                    .padding(10)
            }
            .buttonStyle(.glass)
        }
    }
    
    // MARK: - Segmented Selector
    
    private var segmentedPillBar: some View {
        HStack(spacing: 8) {
            ForEach(ChatSection.allCases) { section in
                let isSelected = selectedSection == section
                
                if isSelected {
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                            Text(section.rawValue)
                        }
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentStart)
                } else {
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                            Text(section.rawValue)
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
    
    // MARK: - 1. Vista Chat de la Comunidad (Live Scene Chat)
    
    private var communityChatView: some View {
        VStack(spacing: 0) {
            // Banner de la sala de comunidad
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(UBTheme.accentPink)
                Text("Sala General UnderBro · Habla con toda la escena en tiempo real")
                    .font(.caption)
                    .foregroundStyle(UBTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(UBTheme.surfaceElevated.opacity(0.3))
            
            // Mensajes
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(communityMessages) { message in
                            CommunityMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                }
                .onChange(of: communityMessages.count) { _, _ in
                    if let last = communityMessages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Barra de entrada de texto inferior
            HStack(spacing: 10) {
                TextField("Escribe un mensaje a los bro's...", text: $newCommunityText)
                    .padding(12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                
                Button {
                    sendCommunityMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.glassProminent)
                .tint(UBTheme.accentStart)
                .disabled(newCommunityText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120) // Margen de tab bar y miniplayer
            .glassEffect(.regular, in: Rectangle())
        }
    }
    
    // MARK: - 2. Vista de Mensajes Directos (DMs)
    
    private var directMessagesView: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(directChats) { chat in
                    Button {
                        selectedDM = chat
                    } label: {
                        HStack(spacing: 14) {
                            ZStack(alignment: .bottomTrailing) {
                                PlaceholderAvatarView(username: chat.user.username, size: 50, hasNewStory: false)
                                
                                if chat.isOnline {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(UBTheme.backgroundDark, lineWidth: 2))
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    HStack(spacing: 4) {
                                        Text(chat.user.displayName)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(UBTheme.textPrimary)
                                        
                                        if chat.user.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption2)
                                                .foregroundStyle(UBTheme.accentEnd)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Text(chat.time)
                                        .font(.caption2)
                                        .foregroundStyle(UBTheme.textTertiary)
                                }
                                
                                HStack {
                                    Text(chat.lastMessage)
                                        .font(.subheadline)
                                        .foregroundStyle(chat.unreadCount > 0 ? UBTheme.textPrimary : UBTheme.textSecondary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if chat.unreadCount > 0 {
                                        Text("\(chat.unreadCount)")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 20, height: 20)
                                            .glassEffect(.regular.tint(UBTheme.accentEnd), in: .circle)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 140)
        }
    }
    
    // MARK: - 3. Vista de Bro's Online (Directorio de Creadores)
    
    private var onlineBrosView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Artistas y Productores activos ahora")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                    .padding(.horizontal, 16)
                
                if isLoadingProfiles {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(onlineProfiles) { profile in
                            HStack(spacing: 14) {
                                ZStack(alignment: .bottomTrailing) {
                                    PlaceholderAvatarView(username: profile.username, size: 50, hasNewStory: true)
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(UBTheme.backgroundDark, lineWidth: 2))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 4) {
                                        Text(profile.displayName.isEmpty ? profile.username : profile.displayName)
                                            .font(.headline.weight(.semibold))
                                            .foregroundStyle(UBTheme.textPrimary)
                                        
                                        if profile.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption2)
                                                .foregroundStyle(UBTheme.accentEnd)
                                        }
                                    }
                                    
                                    Text("@\(profile.username)")
                                        .font(.caption)
                                        .foregroundStyle(UBTheme.textSecondary)
                                    
                                    if let bio = profile.bio, !bio.isEmpty {
                                        Text(bio)
                                            .font(.caption2)
                                            .foregroundStyle(UBTheme.textTertiary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Button {
                                    startDM(with: profile)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "message.fill")
                                        Text("DM")
                                    }
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.glassProminent)
                                .tint(UBTheme.accentStart)
                            }
                            .padding(12)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 140)
        }
    }
    
    // MARK: - Métodos de API y Datos
    
    private func loadCommunityMessages() async {
        do {
            let messages = try await UnderBroServices.api.fetchCommunityChat()
            await MainActor.run {
                self.communityMessages = messages
                self.isLoadingCommunity = false
            }
        } catch {
            print("Error cargando chat comunitario: \(error)")
            await MainActor.run { self.isLoadingCommunity = false }
        }
    }
    
    private func loadOnlineProfiles() async {
        do {
            let profiles = try await UnderBroServices.api.fetchProfiles()
            await MainActor.run {
                self.onlineProfiles = profiles
                self.isLoadingProfiles = false
            }
        } catch {
            print("Error cargando perfiles: \(error)")
            await MainActor.run { self.isLoadingProfiles = false }
        }
    }
    
    private func sendCommunityMessage() {
        let text = newCommunityText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        newCommunityText = ""
        
        Task {
            let msg = try? await UnderBroServices.api.sendCommunityMessage(text: text)
            await MainActor.run {
                if let msg = msg {
                    communityMessages.append(msg)
                }
            }
        }
    }
    
    private func startDM(with profile: UserProfile) {
        let newDM = DMChatItem(
            user: profile,
            lastMessage: "Hola, me mola mucho tu música. ¿Colaboramos?",
            time: "ahora",
            unreadCount: 0,
            isOnline: true
        )
        selectedDM = newDM
    }
}

// MARK: - Burbuja de Mensaje del Chat Comunitario

public struct CommunityMessageRow: View {
    public let message: ChatMessage
    
    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if !message.isMe {
                PlaceholderAvatarView(username: message.sender.username, size: 34, hasNewStory: false)
            } else {
                Spacer()
            }
            
            VStack(alignment: message.isMe ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(message.sender.displayName)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(message.isMe ? UBTheme.accentEnd : UBTheme.textPrimary)
                    
                    if message.sender.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(UBTheme.accentEnd)
                    }
                    
                    Text(message.timestamp)
                        .font(.system(size: 10))
                        .foregroundStyle(UBTheme.textTertiary)
                }
                
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(message.isMe ? UBTheme.accentStart.opacity(0.8) : UBTheme.surfaceElevated.opacity(0.6))
                    )
                    .glassEffect(message.isMe ? .regular.tint(UBTheme.accentStart) : .regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            if message.isMe {
                PlaceholderAvatarView(username: "tú", size: 34, hasNewStory: false, isMe: true)
            }
        }
    }
}

// MARK: - Hoja de Conversación Privada (Direct Chat Thread)

public struct DirectChatThreadSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let dm: ChatListView.DMChatItem
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    
    public init(dm: ChatListView.DMChatItem) {
        self.dm = dm
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mensajes del hilo
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { msg in
                            CommunityMessageRow(message: msg)
                        }
                    }
                    .padding(16)
                }
                
                // Barra de respuesta
                HStack(spacing: 10) {
                    TextField("Escribir a @\(dm.user.username)...", text: $inputText)
                        .padding(12)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                    
                    Button {
                        guard !inputText.isEmpty else { return }
                        let myMsg = ChatMessage(
                            sender: UserProfile(username: "yo", displayName: "Tú"),
                            content: inputText,
                            timestamp: "ahora",
                            isMe: true
                        )
                        messages.append(myMsg)
                        inputText = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.body.weight(.bold))
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentStart)
                }
                .padding(16)
                .glassEffect(.regular, in: Rectangle())
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .navigationTitle(dm.user.displayName)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .buttonStyle(.glass)
                }
            }
            .onAppear {
                messages = [
                    ChatMessage(sender: dm.user, content: dm.lastMessage, timestamp: dm.time, isMe: false)
                ]
            }
        }
    }
}
