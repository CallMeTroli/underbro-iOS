//
//  AuthenticationManager.swift
//  UnderBro iOS
//
//  Gestor central de autenticación y sesiones de usuario conectado en directo
//  con el backend Supabase Auth (GoTrue) de underbro.app:
//    - URL: https://hvpycejcaljgpxwnykuh.supabase.co/auth/v1
//    - Endpoints: /token?grant_type=password, /signup, /recover, /logout
//  Provee persistencia de sesión segura, gestión reactiva de estado y
//  soporte tanto para cuentas reales de UnderBro como para navegación en modo invitado.
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices

// MARK: - Errores de Autenticación Personalizados

public enum UnderBroAuthError: LocalizedError {
    case invalidInput(String)
    case serverError(String)
    case networkError(String)
    case sessionExpired
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .serverError(let message):
            return message
        case .networkError(let message):
            return "Error de red: \(message)"
        case .sessionExpired:
            return "Tu sesión ha expirado. Por favor, vuelve a iniciar sesión."
        }
    }
}

// MARK: - Gestor de Autenticación (AuthenticationManager)

@MainActor
public final class AuthenticationManager: ObservableObject {
    public static let shared = AuthenticationManager()
    
    // MARK: - Claves de Almacenamiento Local
    private let kAuthTokenKey = "underbro_auth_token"
    private let kRefreshTokenKey = "underbro_refresh_token"
    private let kUserDataKey = "underbro_user_profile"
    private let kIsGuestKey = "underbro_is_guest"
    
    // MARK: - Estados Publicados
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: UserProfile? = nil
    @Published public var authToken: String? = nil
    @Published public var isGuest: Bool = false
    @Published public var isLoginSheetPresented: Bool = false
    @Published public var isLoading: Bool = false
    
    private let config: UnderBroAPIConfig = .current
    private let session: URLSession = .shared
    private let decoder: JSONDecoder = JSONDecoder()
    
    private init() {
        loadPersistedSession()
    }
    
    // MARK: - Iniciar Sesión (Login con Correo y Contraseña)
    
    /// Conecta con Supabase Auth `POST /auth/v1/token?grant_type=password`
    public func signIn(email: String, password: String) async throws -> UserProfile {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else {
            throw UnderBroAuthError.invalidInput("Por favor introduce tu correo electrónico.")
        }
        guard !password.isEmpty else {
            throw UnderBroAuthError.invalidInput("Por favor introduce tu contraseña.")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "auth/v1/token?grant_type=password", relativeTo: config.supabaseURL) else {
            throw UnderBroAuthError.networkError("URL de autenticación inválida")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("https://underbro.app", forHTTPHeaderField: "Origin")
        request.setValue("https://underbro.app/", forHTTPHeaderField: "Referer")
        
        let payload: [String: String] = [
            "email": trimmedEmail,
            "password": password
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnderBroAuthError.networkError("Respuesta inesperada del servidor")
        }
        
        // Manejo de errores de Supabase Auth
        if httpResponse.statusCode >= 400 {
            if let errorDto = try? decoder.decode(SupabaseAuthErrorDTO.self, from: data) {
                throw UnderBroAuthError.serverError(errorDto.localizedDescriptionMessage)
            } else {
                throw UnderBroAuthError.serverError("Credenciales incorrectas o error en el servidor (\(httpResponse.statusCode)).")
            }
        }
        
        // Decodificación de sesión exitosa
        let authResponse = try decoder.decode(SupabaseAuthResponseDTO.self, from: data)
        let token = authResponse.access_token
        let userId = authResponse.user.id
        
        // Actualizar token global de red
        UnderBroAPIConfig.current.authToken = token
        
        // Obtener el perfil completo del usuario desde la tabla profiles
        var profile: UserProfile
        if let fetchedProfile = try? await UnderBroServices.api.fetchUserProfile(id: userId) {
            profile = fetchedProfile
        } else {
            // Perfil fallback con metadatos del usuario
            let username = authResponse.user.username ?? trimmedEmail.components(separatedBy: "@").first ?? "usuario"
            let displayName = authResponse.user.displayName ?? username
            profile = UserProfile(
                id: userId,
                username: username,
                displayName: displayName,
                isVerified: false,
                displayedBadge: "MIEMBRO"
            )
        }
        
        // Guardar en sesión
        saveSession(token: token, refreshToken: authResponse.refresh_token, profile: profile)
        
        self.authToken = token
        self.currentUser = profile
        self.isAuthenticated = true
        self.isGuest = false
        self.isLoginSheetPresented = false
        
        return profile
    }
    
    // MARK: - Registro de Nuevo Usuario (SignUp)
    
    /// Conecta con Supabase Auth `POST /auth/v1/signup`
    public func signUp(
        email: String,
        password: String,
        username: String,
        displayName: String,
        birthDate: Date? = nil,
        roles: [String] = []
    ) async throws -> UserProfile {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedUser = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedUser.isEmpty else {
            throw UnderBroAuthError.invalidInput("Por favor elige un nombre de usuario.")
        }
        guard !trimmedEmail.isEmpty else {
            throw UnderBroAuthError.invalidInput("Por favor introduce tu correo electrónico.")
        }
        guard password.count >= 6 else {
            throw UnderBroAuthError.invalidInput("La contraseña debe tener al menos 6 caracteres.")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "auth/v1/signup", relativeTo: config.supabaseURL) else {
            throw UnderBroAuthError.networkError("URL de registro inválida")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("https://underbro.app", forHTTPHeaderField: "Origin")
        request.setValue("https://underbro.app/", forHTTPHeaderField: "Referer")
        
        var metadata: [String: Any] = [
            "username": trimmedUser,
            "display_name": trimmedName.isEmpty ? trimmedUser : trimmedName
        ]
        
        if let birth = birthDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            metadata["birthdate"] = formatter.string(from: birth)
        }
        
        if !roles.isEmpty {
            metadata["roles"] = roles
        }
        
        let payload: [String: Any] = [
            "email": trimmedEmail,
            "password": password,
            "data": metadata
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnderBroAuthError.networkError("Respuesta inesperada del servidor")
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorDto = try? decoder.decode(SupabaseAuthErrorDTO.self, from: data) {
                throw UnderBroAuthError.serverError(errorDto.localizedDescriptionMessage)
            } else {
                throw UnderBroAuthError.serverError("Error al crear la cuenta en UnderBro (\(httpResponse.statusCode)).")
            }
        }
        
        // Supabase Auth puede devolver la sesión de inmediato o requerir confirmación por email
        if let authResponse = try? decoder.decode(SupabaseAuthResponseDTO.self, from: data) {
            let token = authResponse.access_token
            UnderBroAPIConfig.current.authToken = token
            
            let profile = UserProfile(
                id: authResponse.user.id,
                username: trimmedUser,
                displayName: trimmedName.isEmpty ? trimmedUser : trimmedName,
                roles: roles,
                isVerified: false,
                displayedBadge: "NUEVO"
            )
            
            saveSession(token: token, refreshToken: authResponse.refresh_token, profile: profile)
            
            self.authToken = token
            self.currentUser = profile
            self.isAuthenticated = true
            self.isGuest = false
            self.isLoginSheetPresented = false
            
            return profile
        } else {
            // Confirmación requerida
            throw UnderBroAuthError.serverError("Te hemos enviado un correo de confirmación. Por favor verifícalo para activar tu cuenta.")
        }
    }
    
    // MARK: - Recuperación de Contraseña
    
    /// Conecta con Supabase Auth `POST /auth/v1/recover`
    public func resetPassword(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else {
            throw UnderBroAuthError.invalidInput("Introduce tu correo electrónico para recuperar la contraseña.")
        }
        
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: "auth/v1/recover", relativeTo: config.supabaseURL) else {
            throw UnderBroAuthError.networkError("URL inválida")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("https://underbro.app", forHTTPHeaderField: "Origin")
        request.setValue("https://underbro.app/", forHTTPHeaderField: "Referer")
        
        let payload: [String: String] = ["email": trimmedEmail]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UnderBroAuthError.networkError("Respuesta inesperada")
        }
        
        if httpResponse.statusCode >= 400 {
            if let errorDto = try? decoder.decode(SupabaseAuthErrorDTO.self, from: data) {
                throw UnderBroAuthError.serverError(errorDto.localizedDescriptionMessage)
            } else {
                throw UnderBroAuthError.serverError("No se pudo enviar el correo de recuperación.")
            }
        }
    }
    
    // MARK: - Autenticación con Google (OAuth con ASWebAuthenticationSession)
    
    /// Inicia el flujo oficial de Google OAuth en ventana segura y gestiona la redirección directa a la app
    public func signInWithGoogle() async throws -> UserProfile {
        isLoading = true
        defer { isLoading = false }
        
        let callbackScheme = "underbro"
        let redirectURLString = "underbro://auth/callback"
        guard let encodedRedirect = redirectURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let authURL = URL(string: "auth/v1/authorize?provider=google&redirect_to=\(encodedRedirect)", relativeTo: config.supabaseURL) else {
            throw UnderBroAuthError.networkError("URL de Google OAuth inválida")
        }
        
        do {
            let callbackURL = try await WebAuthSessionManager.shared.startOAuth(authURL: authURL, callbackScheme: callbackScheme)
            return try await handleAuthCallback(url: callbackURL)
        } catch let asError as ASWebAuthenticationSessionError where asError.code == .canceledLogin {
            throw UnderBroAuthError.invalidInput("Has cancelado el inicio de sesión con Google.")
        }
    }
    
    /// Procesa el callback URL de Supabase (tanto de fragmento con tokens como de PKCE)
    @discardableResult
    public func handleAuthCallback(url: URL) async throws -> UserProfile {
        var token: String? = nil
        var refreshToken: String? = nil
        
        // 1. Extraer del fragmento (#access_token=...&refresh_token=...)
        if let fragment = url.fragment {
            let params = parseQueryString(fragment)
            token = params["access_token"]
            refreshToken = params["refresh_token"]
        }
        
        // 2. Extraer de los query parameters (?access_token=... o ?code=...)
        if token == nil, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            let items = components.queryItems ?? []
            token = items.first(where: { $0.name == "access_token" })?.value
            refreshToken = items.first(where: { $0.name == "refresh_token" })?.value
            
            // Si devuelve code (PKCE)
            if token == nil, let code = items.first(where: { $0.name == "code" })?.value {
                return try await exchangeCodeForSession(code: code)
            }
        }
        
        guard let validToken = token else {
            throw UnderBroAuthError.serverError("No se recibieron credenciales en la respuesta de Google.")
        }
        
        return try await completeSessionWithToken(token: validToken, refreshToken: refreshToken)
    }
    
    private func completeSessionWithToken(token: String, refreshToken: String?) async throws -> UserProfile {
        UnderBroAPIConfig.current.authToken = token
        
        // Obtener usuario desde /auth/v1/user
        guard let url = URL(string: "auth/v1/user", relativeTo: config.supabaseURL) else {
            throw UnderBroAuthError.networkError("URL inválida")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("https://underbro.app", forHTTPHeaderField: "Origin")
        request.setValue("https://underbro.app/", forHTTPHeaderField: "Referer")
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UnderBroAuthError.serverError("No se pudo verificar la sesión con Google en Supabase.")
        }
        
        let userDto = try decoder.decode(SupabaseAuthUserDTO.self, from: data)
        let userId = userDto.id
        
        var profile: UserProfile
        if let fetchedProfile = try? await UnderBroServices.api.fetchUserProfile(id: userId) {
            profile = fetchedProfile
        } else {
            let username = userDto.username ?? userDto.email?.components(separatedBy: "@").first ?? "usuario"
            let displayName = userDto.displayName ?? username
            profile = UserProfile(
                id: userId,
                username: username,
                displayName: displayName,
                isVerified: false,
                displayedBadge: "GOOGLE"
            )
        }
        
        saveSession(token: token, refreshToken: refreshToken, profile: profile)
        
        self.authToken = token
        self.currentUser = profile
        self.isAuthenticated = true
        self.isGuest = false
        self.isLoginSheetPresented = false
        
        return profile
    }
    
    private func exchangeCodeForSession(code: String) async throws -> UserProfile {
        guard let url = URL(string: "auth/v1/token?grant_type=authorization_code", relativeTo: config.supabaseURL) else {
            throw UnderBroAuthError.networkError("URL inválida")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("https://underbro.app", forHTTPHeaderField: "Origin")
        request.setValue("https://underbro.app/", forHTTPHeaderField: "Referer")
        let payload: [String: String] = ["code": code]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UnderBroAuthError.serverError("Error al validar el código de autorización de Google.")
        }
        let authResponse = try decoder.decode(SupabaseAuthResponseDTO.self, from: data)
        return try await completeSessionWithToken(token: authResponse.access_token, refreshToken: authResponse.refresh_token)
    }
    
    private func parseQueryString(_ query: String) -> [String: String] {
        var dict: [String: String] = [:]
        let pairs = query.components(separatedBy: "&")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2,
               let key = parts[0].removingPercentEncoding,
               let val = parts[1].removingPercentEncoding {
                dict[key] = val
            }
        }
        return dict
    }
    
    // MARK: - Modo Invitado
    
    public func continueAsGuest() {
        self.isGuest = true
        self.isLoginSheetPresented = false
        UserDefaults.standard.set(true, forKey: kIsGuestKey)
    }
    
    // MARK: - Cerrar Sesión
    
    public func signOut() {
        self.isAuthenticated = false
        self.currentUser = nil
        self.authToken = nil
        self.isGuest = false
        
        UnderBroAPIConfig.current.authToken = nil
        
        UserDefaults.standard.removeObject(forKey: kAuthTokenKey)
        UserDefaults.standard.removeObject(forKey: kRefreshTokenKey)
        UserDefaults.standard.removeObject(forKey: kUserDataKey)
        UserDefaults.standard.removeObject(forKey: kIsGuestKey)
    }
    
    // MARK: - Persistencia Local
    
    private func saveSession(token: String, refreshToken: String?, profile: UserProfile) {
        UserDefaults.standard.set(token, forKey: kAuthTokenKey)
        if let ref = refreshToken {
            UserDefaults.standard.set(ref, forKey: kRefreshTokenKey)
        }
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: kUserDataKey)
        }
        UserDefaults.standard.set(false, forKey: kIsGuestKey)
    }
    
    private func loadPersistedSession() {
        if let token = UserDefaults.standard.string(forKey: kAuthTokenKey),
           let profileData = UserDefaults.standard.data(forKey: kUserDataKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
            self.authToken = token
            self.currentUser = profile
            self.isAuthenticated = true
            self.isGuest = false
            UnderBroAPIConfig.current.authToken = token
        } else if UserDefaults.standard.bool(forKey: kIsGuestKey) {
            self.isGuest = true
            self.isAuthenticated = false
        }
    }
}

// MARK: - Manejador de Sesión Web ASWebAuthenticationSession

@MainActor
public final class WebAuthSessionManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = WebAuthSessionManager()
    
    private var currentSession: ASWebAuthenticationSession?
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) {
            return keyWindow
        }
        if let window = scenes.flatMap({ $0.windows }).first {
            return window
        }
        if let firstScene = scenes.first {
            return UIWindow(windowScene: firstScene)
        }
        fatalError("No active window scene found for authentication anchor")
    }
    
    public func startOAuth(authURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: UnderBroAuthError.serverError("Autenticación cancelada"))
                }
            }
            
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.currentSession = session
            
            if !session.start() {
                continuation.resume(throwing: UnderBroAuthError.serverError("No se pudo iniciar la ventana de autenticación."))
            }
        }
    }
}

