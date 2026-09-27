# Sistema de Diseño: Liquid Glass Nativo (iOS 26 / iOS 27) 💎✨

Este documento define la integración con las **APIs oficiales y nativas de Liquid Glass introducidas por Apple en iOS 26+**, utilizadas en toda la interfaz de **UnderBro iOS**.

---

## 1. Principios del Liquid Glass Nativo

A partir de iOS 26, SwiftUI incorpora soporte nativo para superficies ópticas y hápticas avanzadas de cristal líquido:
1. **Agrupación en Contenedores Continuos (`GlassEffectContainer`)**:
   - Cuando varios botones de cristal conviven en una barra o grupo, `GlassEffectContainer` los renderiza como una superficie contigua de cristal líquido, permitiendo refracciones y deformaciones lumínicas coordinadas.
2. **Superficies Ópticas (`.glassEffect()`)**:
   - Aplica el material nativo `Glass.regular` con tintes cromáticos (`.tint(...)`) y respuesta interactiva táctil (`.interactive()`), amoldándose a cualquier forma (`Capsule`, `Circle`, `RoundedRectangle`).
3. **Estilos de Botón Nativos (`.buttonStyle(.glass)` y `.buttonStyle(.glassProminent)`)**:
   - Botones secundarios: `.buttonStyle(.glass)` adopta la translucidez y el rebote físico natural del sistema.
   - Botones primarios de acción: `.buttonStyle(.glassProminent)` con tintes (`.tint(...)`) proyecta un núcleo de energía lumínica con reflejos especulares de alta definición.
4. **Morphing y Continuidad de Cristal (`.glassEffectID(_:in:)`)**:
   - Permite que el selector segmentado (*Siguiendo*, *Tendencias*, *Nuevo*) transfiera la cápsula de cristal líquido con morphing elástico entre pestañas sin cortes visuales.
5. **Adopción Automática en `TabView` y `NavigationStack`**:
   - Al compilar con el SDK 26+, `TabView` adopta de forma nativa la barra flotante de cristal líquido suspendida sobre el contenido.

---

## 2. Tokens de Color & Acentos UnderBro

| Token | Hex / Valor RGB | Uso en el Sistema Nativo |
| :--- | :--- | :--- |
| `UBTheme.backgroundDark` | `#0A0A14` (`rgb(0.04, 0.04, 0.08)`) | Fondo negro índigo espacial sobre el que resalta la refracción del cristal. |
| `UBTheme.surfaceDark` | `#141726` (`rgb(0.08, 0.09, 0.15)`) | Superficies y fondos de contraste. |
| `UBTheme.accentStart` | `#6B5CFA` (`rgb(0.42, 0.36, 0.98)`) | Violeta eléctrico; tinte para `.glassEffect(.regular.tint(...))`. |
| `UBTheme.accentEnd` | `#4794FA` (`rgb(0.28, 0.58, 0.98)`) | Azul brillante; tinte de botones `.glassProminent`. |
| `UBTheme.accentCyan` | `#33D9F2` (`rgb(0.20, 0.85, 0.95)`) | Tinte para badges y cursor del scrubber de audio. |
| `UBTheme.accentPink` | `#F2408C` (`rgb(0.95, 0.25, 0.55)`) | Tinte de Me Gusta (Likes) y estados activos de historias. |

---

## 3. Guía de Uso de las APIs Nativas en el Proyecto

### 3.1 Cabecera y Grupos de Botones
```swift
GlassEffectContainer(spacing: 8) {
    HStack(spacing: 8) {
        Button { ... } label: { Image(systemName: "magnifyingglass") }
            .buttonStyle(.glass)
        
        Button { ... } label: { Image(systemName: "bell") }
            .buttonStyle(.glass)
        
        Button { ... } label: { Image(systemName: "person.fill") }
            .buttonStyle(.glass)
    }
}
```

### 3.2 Segmented Control con Morphing de Cristal
```swift
GlassEffectContainer(spacing: 4) {
    HStack(spacing: 4) {
        ForEach(FeedSegment.allCases) { segment in
            Text(segment.rawValue)
                .background {
                    if selectedSegment == segment {
                        Capsule()
                            .glassEffect(.regular.tint(UBTheme.accentStart).interactive(), in: .capsule)
                            .glassEffectID(segment, in: segmentNamespace)
                    }
                }
        }
    }
}
```

### 3.3 Tarjetas y Paneles
```swift
// Tarjeta compacta o celda de lista
HStack {
    ...
}
.padding(12)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
```

### 3.4 Botón de Reproducción Prominente
```swift
Button {
    player.togglePlayPause()
} label: {
    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
}
.buttonStyle(.glassProminent)
.tint(UBTheme.accentEnd)
```

### 3.5 TabView Nativo de Cristal con Mini-Player
```swift
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
.safeAreaInset(edge: .bottom) {
    if player.currentTrack != nil {
        MiniPlayerView()
            .padding(.bottom, 58)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
.animation(.spring(response: 0.35, dampingFraction: 0.8), value: player.currentTrack != nil)
```
