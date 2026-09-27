# 🔌 Guía de Integración con Backend — UnderBro iOS

## Arquitectura del Backend

UnderBro usa **Supabase** como backend principal:

| Componente | Servicio |
|---|---|
| Base de datos | PostgreSQL (Supabase) |
| Autenticación | Supabase Auth (Email + Google OAuth, PKCE) |
| Tiempo real | Supabase Realtime (WebSocket, Presence, Broadcast) |
| Almacenamiento | Supabase Storage + Cloudflare R2 CDN |
| Edge Functions | Supabase Edge Functions (Deno) |
| Pagos | Stripe via rutas `/api/pay/*` |
| Llamadas | WebRTC con señalización via Supabase |
| Analytics | Vercel Web Analytics |

---

## Credenciales de Conexión

```swift
// Valores extraídos de config.js de underbro.app
let supabaseURL = URL(string: "https://hvpycejcaljgpxwnykuh.supabase.co")!
let supabaseAnonKey = "sb_publishable_JySDMyA_Z1jVQPz9zrCbUA_2SvNf07M"
let mediaCDN = "https://pub-7584459257e74c60bbfa65a0f9836d40.r2.dev"
```

> **Nota:** La `anon key` es pública y segura para usar en el cliente. La seguridad
> se gestiona via **Row Level Security (RLS)** en las tablas de Supabase.

---

## Cómo Conectar desde Swift

### 1. Instalar el SDK de Supabase

Añade a tu `Package.swift` o via Xcode > SPM:

```
https://github.com/supabase/supabase-swift
```

### 2. Inicializar el cliente

```swift
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hvpycejcaljgpxwnykuh.supabase.co")!,
    supabaseKey: "sb_publishable_JySDMyA_Z1jVQPz9zrCbUA_2SvNf07M"
)
```

### 3. Autenticación

```swift
// Login con email
let session = try await supabase.auth.signIn(
    email: "usuario@correo.com",
    password: "contraseña"
)

// Login con Google
let session = try await supabase.auth.signInWithOAuth(
    provider: .google,
    redirectTo: URL(string: "underbro://auth/callback")!
)

// Registrarse
let session = try await supabase.auth.signUp(
    email: "nuevo@correo.com",
    password: "contraseña_segura",
    data: [
        "username": .string("mi_usuario"),
        "display_name": .string("Mi Nombre"),
        "birthdate": .string("2000-01-15")
    ]
)
```

### 4. Consultar pistas (trending)

```swift
// Via RPC
let tracks: [Track] = try await supabase.rpc("trending_tracks").execute().value

// Via query directa
let tracks: [Track] = try await supabase
    .from("tracks")
    .select("*, profiles(*)")
    .order("created_at", ascending: false)
    .limit(30)
    .execute()
    .value
```

### 5. Likes

```swift
// Dar like
try await supabase
    .from("likes")
    .insert(["track_id": trackId, "user_id": userId])
    .execute()

// Quitar like
try await supabase
    .from("likes")
    .delete()
    .eq("track_id", value: trackId)
    .eq("user_id", value: userId)
    .execute()

// Comprobar si tiene like
let likes: [Like] = try await supabase
    .from("likes")
    .select("track_id")
    .eq("user_id", value: userId)
    .execute()
    .value
```

### 6. Chat en tiempo real

```swift
// Suscribirse al chat público
let channel = supabase.channel("public:messages")
    .on("postgres_changes", filter: .init(
        event: .insert,
        schema: "public",
        table: "messages"
    )) { payload in
        print("Nuevo mensaje:", payload)
    }
    .subscribe()

// Enviar mensaje
try await supabase
    .from("messages")
    .insert(["user_id": userId, "body": "Hola a todos!"])
    .execute()
```

### 7. Presencia online

```swift
let presenceChannel = supabase.channel("online-users")
presenceChannel.on("presence", event: .sync) { state in
    let online = presenceChannel.presenceState()
    print("Usuarios online:", online.count)
}
try await presenceChannel.subscribe()
try await presenceChannel.track([
    "id": userId,
    "username": username,
    "display_name": displayName,
    "avatar_url": avatarURL ?? "",
    "online_at": ISO8601DateFormatter().string(from: Date())
])
```

### 8. Storage (subir archivos)

```swift
// Subir audio
let audioData = try Data(contentsOf: audioFileURL)
let path = "\(userId)/\(Date().timeIntervalSince1970)-\(UUID().uuidString.prefix(8)).mp3"
try await supabase.storage
    .from("tracks")
    .upload(
        path: path,
        file: audioData,
        options: .init(cacheControl: "31536000", contentType: "audio/mpeg")
    )

// Subir avatar
let imageData = try Data(contentsOf: imageURL)
let avatarPath = "\(userId)/\(Date().timeIntervalSince1970).webp"
try await supabase.storage
    .from("avatars")
    .upload(path: avatarPath, file: imageData)
```

---

## Tablas Principales de la Base de Datos

Ver el archivo `UnderBroAPIService.swift` para la lista completa de **50 tablas**,
**25 funciones RPC**, **7 buckets de Storage**, **4 Edge Functions** y
**11 canales Realtime**.

---

## Edge Functions

| Función | URL | Uso |
|---|---|---|
| `r2-presign` | `/functions/v1/r2-presign` | Generar URLs firmadas para subir archivos grandes a R2 |
| `media-mirror` | `/functions/v1/media-mirror` | Replicar archivos de Storage al CDN |
| `send-email` | `/functions/v1/send-email` | Enviar emails (verificación, reset, difusión) |
| `portero` | `/functions/v1/portero` | Control de acceso y bloqueo de IPs |

```swift
// Ejemplo: llamar a una Edge Function
let url = URL(string: "https://hvpycejcaljgpxwnykuh.supabase.co/functions/v1/send-email")!
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
request.httpBody = try JSONSerialization.data(withJSONObject: [
    "verify_send": [:]
])
let (data, _) = try await URLSession.shared.data(for: request)
```

---

## API Routes del Servidor

Para pagos y WebRTC, el servidor propio expone:

| Ruta | Método | Uso |
|---|---|---|
| `/api/pay/balance` | GET | Saldo del monedero |
| `/api/pay/checkout` | POST | Crear sesión de pago Stripe |
| `/api/pay/connect` | POST | Conectar cuenta Stripe del vendedor |
| `/api/pay/dashboard` | GET | Dashboard de pagos |
| `/api/pay/order` | GET | Consultar pedido |
| `/api/pay/status` | GET | Estado de conexión de pagos |
| `/api/turn` | GET | Credenciales TURN para llamadas WebRTC |

---

## Pasar de Mock a Producción

En `UnderBroAPIConfig`:

```swift
// Para desarrollo (datos falsos)
UnderBroAPIConfig.current.useMockData = true

// Para producción (servidores reales)
UnderBroAPIConfig.current.useMockData = false
```
