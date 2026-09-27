# UnderBro iOS 🎧✨

> Adaptación nativa en **Swift / SwiftUI** para iOS de la plataforma y comunidad underground [underbro.app](https://underbro.app). Diseñada bajo la filosofía y lenguaje visual oficial **Liquid Glass (iOS 26 / iOS 27)** y conectada directamente a los servidores de producción de UnderBro (Supabase + CDN Media).

---

## 📱 Sub-apartados y Funcionalidades por Pestaña

La aplicación recrea fielmente la totalidad de apartados descubiertos en el análisis de `https://underbro.app` en dispositivo móvil, integrándolos en una experiencia 100% nativa de iOS:

### 1. Pestaña "Stream" (`UnderBroTrendingView.swift`)
* **Cabecera Flotante**: Logotipo con degradado de marca, notificaciones hápticas, avatar y buscador en tiempo real interactivo (`searchTracks`).
* **Selector de Feed Principal**:
  * `Tendencias`: Consume el RPC nativo de Supabase `POST /rest/v1/rpc/trending_tracks`.
  * `Nuevo`: Pistas ordenadas cronológicamente (`order=created_at.desc`).
  * `Siguiendo`: Pistas de artistas a los que sigue el usuario.
* **Píldoras de Descubrimiento (Discover Pills)**:
  * `🔥 Todo`: Vista general de canciones y feed completo.
  * `📻 Radio`: Transmisión continua comunitaria 24/7 con botón de sintonización instantánea.
  * `🎹 Beats`: Instrumentales filtradas por `is_beat = true` con BPM y Tonalidad musical (Key).
  * `🎟️ Eventos`: Agenda de showcases, raves y conciertos de la escena underground.
  * `🎤 Bro's`: Directorio de creadores destacados para descubrir talento nuevo.
* **Riel de Historias (Stories)**: Carrusel horizontal con perfiles de la comunidad y estados visto/no-visto.
* **Tarjetas de Audio**: Tarjetas destacadas (`FeaturedTrackCard`) y compactas (`CompactTrackCard`) con reproducción de audio real (`AVPlayer`), visualizador de formas de onda (`WaveformView`) y contadores de plays, likes y comentarios.

---

### 2. Pestaña "Fotos" (`PhotosFeedView.swift`)
* **Feed Visual Comunitario**: Conexión directa a la tabla `posts` de Supabase con carga asíncrona de imágenes (`AsyncImage`) desde el CDN `https://underbro.app/media/posts/`.
* **Filtros de Galería**: Píldoras de cristal para `Recientes`, `Destacadas` y `Arte & Visuales`.
* **Tarjetas de Publicación Liquid Glass**:
  * Cabecera con avatar, nombre, insignia de verificado, ciudad y menú de opciones.
  * Imagen a alta resolución con gestor de toques para Lightbox a pantalla completa.
  * Barra de interacción: Like con animación y contador, botón de comentarios y botón nativo `ShareLink`.
  * Pie de foto con menciones y etiquetas.
* **Modal "Publicar Foto"**: Formulario con previsualización en cristal para subir nuevas capturas y descripciones a la comunidad.
* **Hoja de Comentarios**: Diálogo interactivo para leer y publicar comentarios en cualquier publicación.

---

### 3. Pestaña "Chat" (`ChatListView.swift`)
* **3 Sub-secciones de la Web App**:
  1. `Comunidad` (Chat de la Escena en Vivo):
     - Sala general pública para todos los creadores y oyentes.
     - Contador de conectados en tiempo real (*"18 creadores underground conectados"*).
     - Burbujas de mensajes translúcidas diferenciadas (usuario actual vs. otros bro's) con avatares e insignias.
     - Barra de entrada de texto inferior anclada con Liquid Glass y botón de envío.
  2. `Directos` (DMs Privados):
     - Bandeja de entrada con hilos de conversación con otros productores o cantantes.
     - Puntos indicadores de estado online (verde), insignias de mensajes no leídos y marcas de tiempo.
     - Al pulsar cualquier conversación se abre el visor `DirectChatThreadSheet` para chatear en privado.
  3. `Bro's Online`:
     - Directorio dinámico de artistas y beatmakers activos en la plataforma en ese instante.
     - Botón de acción directa *"DM"* para proponer colaboraciones al momento.

---

### 4. Pestaña "Yo" (`ProfileView.swift`)
* **Cabecera de Perfil**:
  * Banner de estudio con gradiente atmosférico y avatar con aro de historia.
  * Nombre artístico, nombre de usuario, ciudad e insignia `ALPHA` / `VERIFICADO`.
  * Biografía personalizada y etiquetas de rol (`Productor`, `Beatmaker`, `Sound Designer`).
  * Enlaces sociales a Spotify, Instagram y YouTube con apertura nativa.
* **Métricas en Cristal**: Contadores de Pistas publicadas, Seguidores, Siguiendo y Reproducciones totales.
* **6 Sub-pestañas de Navegación**:
  1. `Pistas`: Catálogo de temas propios con reproductor integrado.
  2. `Fotos`: Cuadrícula asimétrica de fotos y momentos subidos por el artista.
  3. `Favoritos`: Pistas guardadas y preferidas de otros creadores.
  4. `Playlists`: Colecciones temáticas y mixtapes creadas por el usuario.
  5. `Estudio` (Herramientas de Creadores):
     - **Press Kit Digital (EPK)**: Generador interactivo de kit de prensa para sellos discográficos y promotores.
     - **Smart Links UnderBro**: Generador de enlaces inteligentes multidispositivo.
     - **Split Sheets & Regalías**: Herramienta para fijar porcentajes de autoría entre colaboradores.
  6. `Ajustes` (Configuración del Sistema):
     - Tarjeta de diagnóstico de conexión en vivo con Supabase (`https://hvpycejcaljgpxwnykuh.supabase.co`).
     - Toggles de calidad de reproducción (Lossless, normalización de audio, hápticos).
* **Modal de Edición de Perfil**: Hoja para modificar datos biográficos, ciudad y redes sociales.

---

### 5. Pestaña "Subir" (`UploadTrackSheet.swift`)
* **Selector de 4 Canales de Publicación**:
  1. `Pista`: Título, dedicatoria/tagline, colaboradores (ft.), género musical, archivo de audio (.wav/.mp3) y selector de portada.
  2. `Beat`: Instrumental con especificación obligatoria de **BPM (Tempo)**, **Tonalidad musical (Key)** y tipo de **Licencia** (Gratis, Lease o Exclusiva).
  3. `Foto`: Imagen para la comunidad visual con pie de foto y hashtags.
  4. `Evento`: Concierto o showcase con sala, ciudad, fecha y hora, y enlace a venta de entradas (DICE, etc.).

---

### 6. Sistema de Audio Global y Dynamic Island Nativa (`AudioPlayerService.swift`)
* **Reproducción en Segundo Plano y Dynamic Island Nativa de iOS**:
  - Soporte completo de reproducción en background con `UIBackgroundModes: ["audio"]` y categoría `.playback`.
  - Integración nativa con la **Dynamic Island del sistema operativo iOS**: al salir de la aplicación o bloquear la pantalla, iOS presenta automáticamente la reproducción en la Dynamic Island sin necesidad de Live Activities ni extensiones adicionales:
    - **Lateral Izquierdo (Leading)**: Carátula de la pista en alta resolución suministrada mediante `MPMediaItemPropertyArtwork`.
    - **Lateral Derecho (Trailing)**: Animación fluida de barras de sonido / ecualizador nativo del sistema operativo iOS.
    - **Pulsación Larga**: Despliegue del reproductor flotante nativo Now Playing de Apple con scrubber interactivo, volumen, selector de salida AirPlay y controles táctiles completos.
  - Controles remotos en Pantalla de Bloqueo, Control Center, AirPods y Apple Watch vía `MPRemoteCommandCenter` (Play, Pause, Toggle, Next, Previous, Scrubbing y Like).
  - Metadatos enriquecidos con carátula en alta definición vía `MPNowPlayingInfoCenter` (título, artista, duración, scrubber en tiempo real y placeholder temático en caso de ausencia de red).
  - Manejo inteligente de interrupciones del sistema (`AVAudioSession.interruptionNotification`) para llamadas y Siri, y pausa automática ante desconexión de auriculares (`routeChangeNotification`).
  - Motor de bucle silencioso en memoria para garantizar continuidad en segundo plano y presencia en la Dynamic Island incluso en pistas simuladas u offline.
* **Mini-Reproductor Suspendido (`MiniPlayerView.swift`)**:
  - Anclado dinámicamente mediante `.safeAreaInset(edge: .bottom)` sobre el TabBar nativo.
  - Reproduce pistas reales en streaming desde el CDN de UnderBro o locales.
  - Al pulsarlo, abre el reproductor a pantalla completa.
* **Reproductor a Pantalla Completa (`FullScreenPlayerView.swift`)**:
  - Portada con proporción forzada 1:1, bordes continuos y resplandor cromático según la pista.
  - Barra de onda de audio interactiva (`WaveformView`) con scrubbing en tiempo real.
  - Selector de velocidad cíclico (`0.75x`, `1x`, `1.25x`, `1.5x`, `2x`).

---

## 📂 Estructura del Proyecto y Funcionalidad de Cada Archivo

El código base sigue los principios de Clean Architecture y modularidad en SwiftUI. A continuación se detalla la responsabilidad y función de cada archivo del proyecto:

### 1. Núcleo de Aplicación y Navegación Raíz
* **[`MyApp.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/MyApp.swift)**:
  * **Función**: Punto de entrada principal (`@main`) de la aplicación SwiftUI.
  * **Responsabilidad**: Configura la escena inicial `WindowGroup` e inicializa [`ContentView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/ContentView.swift).
* **[`ContentView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/ContentView.swift)**:
  * **Función**: Vista contenedora principal compatible tanto con compilación en Xcode como con Swift Playgrounds (macOS e iPad).
  * **Responsabilidad**: Envuelve y renderiza [`UnderBroRootView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/UnderBroRootView.swift).
* **[`UnderBroRootView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/UnderBroRootView.swift)**:
  * **Función**: Vista raíz orquestadora de toda la navegación de la app.
  * **Responsabilidad**: Declara el `TabView` nativo con los 5 tabs principales (`Stream`, `Fotos`, `Yo`, `Chat`, `Subir`), gestiona el estado del tab activo, ancla dinámicamente el [`MiniPlayerView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/MiniPlayerView.swift) sobre la barra inferior mediante `.safeAreaInset(edge: .bottom)` y orquesta la apertura de las hojas modales del reproductor completo ([`FullScreenPlayerView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/FullScreenPlayerView.swift)) y del formulario de subida ([`UploadTrackSheet`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/UploadTrackSheet.swift)).

---

### 2. Capa de Red, Backend y Modelos de Datos
* **[`UnderBroAPIService.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/UnderBroAPIService.swift)**:
  * **Función**: Cliente de red conectado directamente a la API de Supabase en producción de UnderBro (`https://hvpycejcaljgpxwnykuh.supabase.co`).
  * **Responsabilidad**: Implementa `UnderBroAPIServiceProtocol` con `UnderBroAPIClient` mediante `URLSession` y Swift Concurrency (`async/await`). Ejecuta el RPC `trending_tracks`, consultas REST sobre las tablas `tracks`, `posts`, `profiles`, `comments`, inyecta encabezados de navegación autorizada (`Origin`, `Referer`, `apikey`, `Bearer`), decodifica los DTOs al dominio y proporciona el respaldo offline `MockUnderBroAPIService`.
* **[`Models.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/Models.swift)**:
  * **Función**: Definición de todas las entidades de dominio y DTOs de datos del ecosistema UnderBro.
  * **Responsabilidad**: Declara estructuras `Codable`, `Identifiable` y `Hashable`: `Track` (pistas y beats con BPM/Key), `UserProfile` (perfiles de artistas, roles, enlaces y verificaciones), `Story` (historias efímeras), `CommunityPost` (publicaciones visuales de la comunidad), `TrackComment` (comentarios en pistas), `ChatMessage` (mensajes de chat público y DMs), `UnderBroEvent` (eventos y conciertos), DTOs de autenticación (`SupabaseAuthResponseDTO`, `SupabaseAuthUserDTO`, `SupabaseAuthErrorDTO`), `MainTab`, `FeedSegment` y `DiscoverFilter`.
* **[`AuthenticationManager.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/AuthenticationManager.swift)**:
  * **Función**: Gestor central de sesiones y autenticación conectado en directo a Supabase Auth (`/auth/v1`).
  * **Responsabilidad**: Gestiona el ciclo de vida del usuario (`isAuthenticated`, `currentUser`, `authToken`, `isGuest`), ejecuta inicio de sesión con correo y contraseña (`/token?grant_type=password`), registro de nuevos creadores (`/signup`), recuperación de contraseñas (`/recover`), cierre de sesión (`signOut`) y persistencia local segura de tokens y perfiles en `UserDefaults`.

---

### 3. Motor y Servicios de Audio
* **[`AudioPlayerService.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/AudioPlayerService.swift)**:
  * **Función**: Motor de reproducción de audio global singleton (`AudioPlayerService.shared`).
  * **Responsabilidad**: Gestiona reproducción en segundo plano (`UIBackgroundModes: ["audio"]`), `AVPlayer` con streaming CDN, integración nativa de `MPRemoteCommandCenter` (pantalla de bloqueo y Control Center) y `MPNowPlayingInfoCenter` (carátulas, títulos y scrubbing nativo), activación de la Dynamic Island nativa de iOS al salir de la aplicación, manejo de interrupciones de sistema (`AVAudioSession`), cola de reproducción reactiva (`@Published`), selector de velocidad (`0.75x` a `2x`) y buffer silencioso para pistas simuladas/offline.

---

### 4. Sistema de Diseño Liquid Glass (iOS 26 / 27)
* **[`LiquidGlassTheme.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/LiquidGlassTheme.swift)**:
  * **Función**: Catálogo de tokens visuales y utilidades del sistema de diseño Liquid Glass.
  * **Responsabilidad**: Define `UBTheme` con la paleta de colores espaciales oscuros (`backgroundDark`, `surfaceDark`, `surfaceElevated`), acentos cromáticos neón (`accentStart`, `accentEnd`, `accentCyan`, `accentPink`, `accentOrange`, `accentGold`), gradientes de marca y de bisel especular (`glassBorderGradient`), y extensiones de SwiftUI como `dynamicGlow()` para iluminaciones volumétricas.
* **[`WaveformView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/WaveformView.swift)**:
  * **Función**: Componente de visualización y control interactivo de formas de onda de audio (*Waveform Scrubber*).
  * **Responsabilidad**: Dibuja barras de audio con gradientes y alturas dinámicas, colorea el progreso transcurrido, renderiza animaciones durante la reproducción y permite arrastrar el dedo (*drag gesture*) para saltar instantáneamente a cualquier segundo de la pista.
* **[`PlaceholderComponents.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/PlaceholderComponents.swift)**:
  * **Función**: Componentes gráficos de reemplazo inteligente y estados de carga.
  * **Responsabilidad**: Proporciona [`PlaceholderArtworkView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/PlaceholderComponents.swift) (portadas musicales con gradientes temáticos, biseles ópticos y tipografía de apoyo) y [`PlaceholderAvatarView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/PlaceholderComponents.swift) (avatares con iniciales generativas, aros de historias activas y badges de verificación).
* **[`LiquidGlassTabBar.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/LiquidGlassTabBar.swift)**:
  * **Función**: Barra de navegación flotante personalizada con diseño de dock de cristal líquido.
  * **Responsabilidad**: Implementa botones de navegación táctiles con respuesta háptica, píldora de selección con morphing y soporte para el botón central elevado de publicación.

---

### 5. Pestañas Principales de la Aplicación
* **[`UnderBroTrendingView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/UnderBroTrendingView.swift)**:
  * **Función**: Vista central de la pestaña **"Stream"**.
  * **Responsabilidad**: Coordina la carga de pistas desde Supabase, el buscador reactivo desplegable en tiempo real, el carrusel de historias, el selector de segmentos (`Tendencias`, `Nuevo`, `Siguiendo`), las píldoras de descubrimiento (`Todo`, `Radio 24/7`, `Beats con BPM/Key`, `Eventos`, `Bro's`) y las tarjetas de reproducción destacadas y compactas.
* **[`PhotosFeedView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/PhotosFeedView.swift)**:
  * **Función**: Vista de la pestaña **"Fotos"** (comunidad visual de la escena).
  * **Responsabilidad**: Presenta el feed de imágenes de Supabase (`posts`), selector de filtros (`Recientes`, `Destacadas`, `Visuales`), tarjetas `CommunityPostCard` con likes interactivos y contador, `UploadPhotoSheet` para publicar nuevas fotos, `PostCommentsSheet` para comentarios y `PhotoLightboxView` para inspeccionar capturas a pantalla completa.
* **[`ChatListView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/ChatListView.swift)**:
  * **Función**: Vista de la pestaña **"Chat"**.
  * **Responsabilidad**: Ofrece las 3 secciones clave de la web app: `Comunidad` (sala de chat grupal en tiempo real con contador de creadores conectados y barra de composición), `Directos` (mensajería privada DMs con apertura de hilos en `DirectChatThreadSheet`) y `Bro's Online` (directorio de creadores activos listos para colaborar).
* **[`ProfileView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/ProfileView.swift)**:
  * **Función**: Vista de la pestaña **"Yo"** (perfil de usuario y creador).
  * **Responsabilidad**: Renderiza el banner de estudio en cristal, avatar verificado/ALPHA, bio, roles y enlaces a Spotify/Instagram/YouTube, contadores de estadísticas y 6 sub-pestañas: `Pistas`, `Fotos`, `Favoritos`, `Playlists`, `Estudio` (Press Kit EPK, Smart Links, Split Sheets) y `Ajustes` (diagnóstico de conexión a Supabase y calidad de audio), junto a la hoja de edición `EditProfileSheet`.
* **[`UploadTrackSheet.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/UploadTrackSheet.swift)**:
  * **Función**: Hoja modal multifuncional de la pestaña **"Subir"**.
  * **Responsabilidad**: Permite alternar entre los 4 canales de publicación de la plataforma web: `Pista` (audio, portada, género, colaboradores), `Beat` (con campos para BPM numérico, escala musical Key y tipo de licencia), `Foto` (imagen y pie de foto) y `Evento` (sala, ciudad, fecha y enlace de venta de entradas).

---

### 6. Componentes y Tarjetas Reutilizables
* **[`FeedHeaderView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/FeedHeaderView.swift)**:
  * **Función**: Cabecera superior para el feed principal.
  * **Responsabilidad**: Muestra el logotipo de UnderBro con degradado de marca, avatar de usuario y botones de acción (búsqueda y notificaciones con punto de aviso).
* **[`SegmentedPillBar.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/SegmentedPillBar.swift)**:
  * **Función**: Selector horizontal de segmentos con estilo de cristal líquido.
  * **Responsabilidad**: Proporciona botones con morphing suave y selección háptica para alternar vistas sin recargar la pantalla.
* **[`StoriesCarouselView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/StoriesCarouselView.swift)**:
  * **Función**: Riel de desplazamiento horizontal para historias efímeras.
  * **Responsabilidad**: Renderiza círculos de creadores con aros de gradiente de neón cuando hay contenido no visto y acceso directo para añadir contenido propio (*"Tu historia"*).
* **[`FeaturedTrackCard.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/FeaturedTrackCard.swift)**:
  * **Función**: Tarjeta destacada de gran tamaño para el tema N.º 1 en tendencias (ej. `###sol`).
  * **Responsabilidad**: Presenta la portada de la canción con bisel de cristal reflectante, insignia superior destacada, reproductor integrado con forma de onda interactiva y botones de interacción social (likes, plays, comentarios, reposts).
* **[`CompactTrackCard.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift)**:
  * **Función**: Tarjeta compacta para listados de canciones y catálogo de beats, componente reusable [`TrackRow`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift) y vista de lista [`TrackListView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift).
  * **Responsabilidad**: Muestra posición en ranking, portada en miniatura, título, artista, etiqueta de género o BPM, duración, botones de like y reproducción directa. Incluye [`TrackRow`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift) para su uso en colecciones e implementa la vista de lista [`TrackListView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift) con soporte nativo de **Pull-to-Refresh** (`.refreshable`).
* **[`MiniPlayerView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/MiniPlayerView.swift)**:
  * **Función**: Mini-reproductor flotante anclado en la parte inferior de la pantalla.
  * **Responsabilidad**: Muestra la pista actual en reproducción, portada, título, controles de play/pausa y anterior/siguiente, barra de progreso sutil y gesto de toque para abrir el reproductor completo.
* **[`FullScreenPlayerView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/FullScreenPlayerView.swift)**:
  * **Función**: Reproductor a pantalla completa en hoja modal expandible.
  * **Responsabilidad**: Exhibe la portada en formato squircle gigante con resplandor ambiental adaptativo, onda interactiva completa con scrubbing, botones de transporte con aura neón, píldoras sociales (likes, comentarios, compartir) y selector cíclico de velocidad (`0.75x` a `2.0x`). Al pulsar sobre el nombre del artista con diseño de cristal, presenta modalmente la vista de perfil de usuario [`ArtistProfileView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/ArtistProfileView.swift).
* **[`ArtistProfileView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/ArtistProfileView.swift)**:
  * **Función**: Interfaz de usuario completa para perfiles de artistas y creadores del ecosistema UnderBro.
  * **Responsabilidad**: Se presenta de forma interactiva en las tres situaciones clave de la aplicación:
    1. **Reproductor a Pantalla Completa**: Al pulsar sobre el nombre del artista en [`FullScreenPlayerView`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/FullScreenPlayerView.swift).
    2. **Buscador Global**: Al pulsar sobre cualquier usuario o creador en los resultados de búsqueda en vivo en la base de datos de Supabase.
    3. **Menú Principal / Feed**: Al pulsar sobre el nombre del artista en tarjetas destacadas ([`FeaturedTrackCard`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/FeaturedTrackCard.swift)), tarjetas compactas o listas ([`CompactTrackCard`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift) / [`TrackRow`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift)), beats instrumentales o en las tarjetas de creadores de la sección `Bro's`.
  * **Características**:
    - Cabecera con banner de estudio y avatar con aro de historia interactivo e insignias de verificación / `ALPHA`.
    - Identidad del creador: `@username`, ciudad, biografía y etiquetas de rol (`Productor`, `Beatmaker`, etc.).
    - Enlaces sociales a Spotify, Instagram, YouTube y SoundCloud con apertura nativa.
    - Métricas de creador en cristal: Pistas publicadas, Seguidores, Siguiendo y Reproducciones totales.
    - Botonera de acción: Botón de seguir ("Seguir" / "Siguiendo" con `.buttonStyle(.glassProminent)` / `.buttonStyle(.glass)`), botón para abrir chat privado DM y botón nativo `ShareLink` para compartir el enlace `https://underbro.app/@username`.
    - Sub-pestañas integradas:
      - `Pistas`: Catálogo musical del artista con reproducción en streaming directo mediante [`TrackRow`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/CompactTrackCard.swift).
      - `Fotos`: Galería comunitaria con miniaturas de fotos y visor Lightbox a pantalla completa.
      - `Información`: Ficha técnica de la cuenta (fecha de ingreso, ID de Supabase y estado verificado).
* **[`UnderBroLoginView.swift`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/UnderBroLoginView.swift)**:
  * **Función**: Pantalla de inicio de sesión, registro y recuperación de cuenta adaptada de `underbro.app`.
  * **Responsabilidad**: Permite a los usuarios acceder a su cuenta de UnderBro en la nube o registrarse como nuevos creadores:
    - Selector deslizante limpio para alternar entre **"Iniciar sesión"** y **"Registrarse"**.
    - Acceso rápido oficial con **Google OAuth** mediante `ASWebAuthenticationSession` con captura automática del callback scheme `underbro://auth/callback` para retornar directamente a la app tras seleccionar la cuenta.
    - Botones con diseño limpio, estilizado y sólido sin fondos de cristal esmerilado que estorben, y con márgenes laterales generosos que evitan que queden pegados a los bordes de la pantalla.
    - Separador visual y formulario de correo y contraseña con visualizador interactivo de contraseña (mostrar/ocultar).
    - Modo Registro con campos de `@alias`, nombre artístico, correo, medidor de fuerza de contraseña reactivo (Débil, Media, Segura), selector de fecha de nacimiento con advertencia comunitaria de edad (+14 años), selector de roles underground (Cantante, Productor, Beatmaker, DJ, Diseñador, Oyente) y aceptación de términos legales.
    - Modal de recuperación de contraseña conectada al endpoint `/auth/v1/recover` de Supabase.
    - Botón para **"Explorar como invitado"** sin necesidad de registro inmediato.
    - Banner de errores y confirmaciones con respuesta háptica y animaciones fluidas.

---

### 7. Documentación del Proyecto
* **[`README.md`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/README.md)**:
  * **Función**: Documento principal del repositorio.
  * **Responsabilidad**: Describe la visión general del proyecto, la correspondencia de cada pestaña con la web app de UnderBro, el desglose funcional archivo por archivo, las directrices de compilación y el sistema de diseño.
* **[`BACKEND_INTEGRATION_GUIDE.md`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/BACKEND_INTEGRATION_GUIDE.md)**:
  * **Función**: Manual exhaustivo de arquitectura e integración de backend.
  * **Responsabilidad**: Documenta la configuración de Supabase, URLs, credenciales anónimas, 50 tablas de PostgreSQL, 25 funciones RPC, 7 buckets de Storage, CDN Cloudflare R2, Edge Functions y canales Realtime WebSocket.
* **[`LIQUID_GLASS_DESIGN_SYSTEM.md`](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/LIQUID_GLASS_DESIGN_SYSTEM.md)**:
  * **Función**: Especificación técnica del sistema de diseño Liquid Glass para iOS 26 y iOS 27.
  * **Responsabilidad**: Explica el uso de `GlassEffectContainer`, `.glassEffect()`, `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`, física de materiales translúcidos y ergonomía háptica.

---

## 🎨 Lenguaje de Diseño: Liquid Glass Nativo de iOS 26+

Toda la aplicación utiliza las APIs oficiales de Apple para Liquid Glass:
* `GlassEffectContainer`: Contenedor óptico continuo para barras de navegación y botoneras.
* `.glassEffect(.regular)` y `.glassEffect(.regular.tint(...))`: Superficies refractivas translúcidas.
* `.buttonStyle(.glass)` y `.buttonStyle(.glassProminent)`: Botones táctiles de cristal con físicas de luz y respuesta háptica.
* `.glassEffectID(_:in:)`: Transiciones fluidas entre pestañas.

---

## 🌐 Conexión a Servidores y Base de Datos

* **Supabase REST URL**: `https://hvpycejcaljgpxwnykuh.supabase.co`
* **Supabase Anon Key**: `sb_publishable_JySDMyA_Z1jVQPz9zrCbUA_2SvNf07M`
* **Media CDN**: `https://underbro.app/media/`
* **Cliente de Red**: `UnderBroAPIClient` implementado con `URLSession` moderna (Swift Concurrency `async/await`), mapeo DTO a Dominio y respaldo offline automático.

Para más detalles técnicos de la integración backend, consulta [BACKEND_INTEGRATION_GUIDE.md](file:///Users/troli/Desktop/app%20underbroski/app%20underbroski/BACKEND_INTEGRATION_GUIDE.md).

---

## 🛠️ Verificación y Compilación

El proyecto compila limpiamente para iOS 26/27 Simulator:

```bash
xcrun --sdk iphonesimulator swiftc -target arm64-apple-ios27.0-simulator -typecheck *.swift
```
*(Resultado: 0 errores, 0 avisos).*
