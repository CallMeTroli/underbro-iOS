//
//  UnderBroRootView.swift
//  UnderBro iOS
//
//  Vista raíz que adopta la barra de navegación nativa de cristal líquido (Liquid Glass TabView)
//  de iOS 26+, con mini-reproductor integrado vía safeAreaInset y modales fluidos.
//

import SwiftUI

public struct UnderBroRootView: View {
    @State private var selectedTab: MainTab = .stream
    @State private var isUploadPresented: Bool = false
    @ObservedObject var player: AudioPlayerService = .shared
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Stream", systemImage: "play.circle.fill", value: .stream) {
                UnderBroTrendingView()
            }
            Tab("Fotos", systemImage: "camera.fill", value: .fotos) {
                PhotosFeedView()
            }
            Tab("Yo", systemImage: "person.circle.fill", value: .yo) {
                ProfileView()
            }
            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill", value: .chat) {
                ChatListView()
            }
            Tab("Subir", systemImage: "plus", value: .subir) {
                UnderBroTrendingView()
            }
        }
        .tint(UBTheme.accentEnd)
        // Mini reproductor anclado sobre la barra de pestañas nativa con margen superior
        .safeAreaInset(edge: .bottom) {
            if player.currentTrack != nil {
                MiniPlayerView()
                    .padding(.bottom, 58)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: player.currentTrack != nil)
        .onChange(of: selectedTab) {
            if selectedTab == .subir {
                isUploadPresented = true
                selectedTab = .stream
            }
        }
        .preferredColorScheme(.dark)
        // Hoja modal para el reproductor expandido (Captura 3)
        .sheet(isPresented: $player.isFullScreenPresented) {
            FullScreenPlayerView()
        }
        // Hoja modal para subir pistas
        .sheet(isPresented: $isUploadPresented) {
            UploadTrackSheet()
        }
    }
}

struct UnderBroRootView_Previews: PreviewProvider {
    static var previews: some View {
        UnderBroRootView()
    }
}
