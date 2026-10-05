//
//  UnderBroLoginView.swift
//  UnderBro iOS
//
//  Pantalla de inicio de sesión y registro de UnderBro.
//  Adaptada con estética moderna de iOS 26/27:
//    - Botones limpios sin fondos de cristal esmerilado que estorben
//    - Márgenes y espaciados equilibrados respecto a los bordes de la pantalla
//    - Autenticación con Google mediante ASWebAuthenticationSession con redirección a la app
//    - Conexión DIRECTA en tiempo real con Supabase Auth (GoTrue API de underbro.app)
//

import SwiftUI

public struct UnderBroLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var auth: AuthenticationManager = .shared
    
    // MARK: - Modos de la Pantalla
    public enum AuthMode: String, CaseIterable, Identifiable {
        case login = "Iniciar sesión"
        case register = "Registrarse"
        
        public var id: String { rawValue }
    }
    
    @State private var selectedMode: AuthMode = .login
    
    // MARK: - Campos de Formulario
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    
    // Campos adicionales para Registro
    @State private var username: String = ""
    @State private var displayName: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var selectedRole: String = "Productor"
    @State private var acceptedTerms: Bool = false
    
    // Modales y Recuperación
    @State private var isForgotPasswordPresented: Bool = false
    @State private var forgotPasswordEmail: String = ""
    @State private var forgotPasswordSuccessMessage: String? = nil
    @State private var isSendingResetEmail: Bool = false
    
    // Estado de Error / Éxito
    @State private var errorMessage: String? = nil
    
    // Roles disponibles en UnderBro
    private let availableRoles: [String] = ["Cantante", "Productor", "Beatmaker", "DJ", "Diseñador", "Oyente"]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Fondo espacial oscuro con orbes de neón atmosféricos
                ambientBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. Cabecera con Logotipo y Lema Oficial
                        headerLogoSection
                            .padding(.top, 16)
                        
                        // 2. Formulario Principal con gap y margen limpio respecto a los bordes
                        authCardView
                            .frame(maxWidth: 390)
                            .padding(.horizontal, 36)
                        
                        // 3. Botón para continuar como invitado
                        guestModeButton
                            .padding(.top, 6)
                        
                        // 4. Pie de página legal
                        footerLegalSection
                            .padding(.top, 8)
                            .padding(.bottom, 36)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                }
            }
            .sheet(isPresented: $isForgotPasswordPresented) {
                forgotPasswordSheet
            }
        }
    }
    
    // MARK: - Fondo Ambiental
    
    private var ambientBackground: some View {
        ZStack {
            UBTheme.backgroundDark.ignoresSafeArea()
            
            // Resplandor superior Cian
            Circle()
                .fill(
                    RadialGradient(
                        colors: [UBTheme.accentCyan.opacity(0.18), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 260
                    )
                )
                .frame(width: 460, height: 460)
                .offset(x: -110, y: -210)
                .blur(radius: 50)
            
            // Resplandor inferior Rosa/Violeta
            Circle()
                .fill(
                    RadialGradient(
                        colors: [UBTheme.accentPink.opacity(0.16), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 240
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: 130, y: 250)
                .blur(radius: 50)
        }
    }
    
    
    // MARK: - Logotipo y Lema Oficial
    
    private var headerLogoSection: some View {
        VStack(spacing: 6) {
            // Logotipo tipográfico con degradado
            HStack(spacing: 0) {
                Text("Under")
                    .foregroundStyle(.white)
                Text("Bro")
                    .foregroundStyle(UBTheme.brandGradient)
            }
            .font(.system(size: 36, weight: .black, design: .rounded))
            .shadow(color: UBTheme.accentEnd.opacity(0.35), radius: 14, x: 0, y: 3)
            
            // Lema oficial extraído de underbro.app
            Text("upload. share. connect.")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(
                    LinearGradient(
                        colors: [UBTheme.accentCyan, UBTheme.accentPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("La red social de la música underground")
                .font(.footnote)
                .foregroundStyle(UBTheme.textSecondary)
        }
    }
    
    // MARK: - Formulario de Autenticación Principal (Sin recuadro contenedor)
    
    private var authCardView: some View {
        VStack(spacing: 18) {
            // Selector de pestaña (Iniciar sesión / Registrarse)
            segmentedModePicker
            
            // Botón de Google OAuth
            googleAuthButton
            
            // Separador "o"
            dividerOrView
            
            // Banner de error (si existe)
            if let err = errorMessage {
                errorMessageBanner(err)
            }
            
            // Formulario según modo seleccionado
            if selectedMode == .login {
                loginFormView
            } else {
                registerFormView
            }
        }
    }
    
    // MARK: - Selector de Pestaña Limpio
    
    private var segmentedModePicker: some View {
        HStack(spacing: 4) {
            ForEach(AuthMode.allCases) { mode in
                let isSelected = selectedMode == mode
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedMode = mode
                        errorMessage = nil
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? .white : UBTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            isSelected ?
                            AnyView(UBTheme.brandGradient) :
                            AnyView(Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Botón de Google OAuth (Sin Glass de Fondo)
    
    private var googleAuthButton: some View {
        Button {
            executeGoogleSignIn()
        } label: {
            HStack(spacing: 12) {
                if auth.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    googleIconView
                    Text("Continuar con Google")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color(white: 0.13))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
    }
    
    // Icono multicolor oficial de Google
    private var googleIconView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
            
            OfficialGoogleLogoView(size: 13)
        }
    }
    
    // MARK: - Separador "o con tu correo"
    
    private var dividerOrView: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
            
            Text("o con tu correo")
                .font(.caption2.weight(.medium))
                .foregroundStyle(UBTheme.textTertiary)
            
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Mensaje de Error
    
    private func errorMessageBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(UBTheme.accentPink)
                .font(.system(size: 14))
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
    }
    
    // MARK: - Formulario de Inicio de Sesión (Login)
    
    private var loginFormView: some View {
        VStack(spacing: 16) {
            // Campo de Correo Electrónico
            VStack(alignment: .leading, spacing: 6) {
                Label("Correo electrónico", systemImage: "envelope.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                HStack(spacing: 10) {
                    TextField("tu@correo.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.white)
                    
                    if !email.isEmpty {
                        Button {
                            email = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(UBTheme.textTertiary)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            // Campo de Contraseña
            VStack(alignment: .leading, spacing: 6) {
                Label("Contraseña", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                HStack(spacing: 10) {
                    if isPasswordVisible {
                        TextField("••••••••", text: $password)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("••••••••", text: $password)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(UBTheme.textTertiary)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            // Enlace de "¿Has olvidado tu contraseña?"
            HStack {
                Spacer()
                Button {
                    forgotPasswordEmail = email
                    isForgotPasswordPresented = true
                } label: {
                    Text("¿Has olvidado tu contraseña?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(UBTheme.accentCyan)
                }
            }
            .padding(.top, -2)
            
            // Botón Principal de Enviar (Entrar) - SIN glass de fondo, degradado sólido y márgenes limpios
            Button {
                executeLogin()
            } label: {
                HStack(spacing: 8) {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text("Entrar a UnderBro")
                            .font(.headline.weight(.bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(UBTheme.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: UBTheme.accentEnd.opacity(0.4), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(auth.isLoading)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Formulario de Registro (Register)
    
    private var registerFormView: some View {
        VStack(spacing: 16) {
            // Nombre de Usuario (@alias)
            VStack(alignment: .leading, spacing: 6) {
                Label("Nombre de usuario (alias único)", systemImage: "at")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                HStack(spacing: 6) {
                    Text("@")
                        .foregroundStyle(UBTheme.accentCyan)
                        .font(.subheadline.weight(.bold))
                    
                    TextField("tu_alias", text: $username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .foregroundStyle(.white)
                        .onChange(of: username) { _, newValue in
                            username = newValue.lowercased().replacingOccurrences(of: " ", with: "")
                        }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            // Nombre Artístico / Visible
            VStack(alignment: .leading, spacing: 6) {
                Label("Nombre artístico o visible", systemImage: "person.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                TextField("Ej: DJ Neon, María Beatmaker", text: $displayName)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            // Correo Electrónico
            VStack(alignment: .leading, spacing: 6) {
                Label("Correo electrónico", systemImage: "envelope.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                TextField("tu@correo.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            // Contraseña + Medidor de Fuerza
            VStack(alignment: .leading, spacing: 6) {
                Label("Contraseña", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                HStack(spacing: 10) {
                    if isPasswordVisible {
                        TextField("Mínimo 6 caracteres", text: $password)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("Mínimo 6 caracteres", text: $password)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(UBTheme.textTertiary)
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Medidor visual de fuerza de contraseña
                if !password.isEmpty {
                    passwordStrengthView
                }
            }
            
            // Rol en la comunidad
            VStack(alignment: .leading, spacing: 8) {
                Label("¿Cuál es tu rol principal?", systemImage: "waveform.badge.magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableRoles, id: \.self) { role in
                            let isSelected = selectedRole == role
                            Button {
                                selectedRole = role
                            } label: {
                                Text(role)
                                    .font(.caption.weight(isSelected ? .bold : .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(isSelected ? .white : UBTheme.textSecondary)
                                    .background(isSelected ? UBTheme.accentCyan : Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // Fecha de Nacimiento
            VStack(alignment: .leading, spacing: 6) {
                Label("Fecha de nacimiento", systemImage: "calendar")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(UBTheme.textSecondary)
                
                HStack {
                    DatePicker(
                        "",
                        selection: $birthDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .colorScheme(.dark)
                    
                    Spacer()
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                Text("Hay que tener 14 años o más. No se muestra en tu perfil: solo la ves tú.")
                    .font(.system(size: 11))
                    .foregroundStyle(UBTheme.textTertiary)
            }
            
            // Términos y Condiciones
            Button {
                acceptedTerms.toggle()
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundStyle(acceptedTerms ? UBTheme.accentEnd : UBTheme.textTertiary)
                        .padding(.top, 2)
                    
                    Text("Acepto los Términos de uso y la Política de privacidad de UnderBro.")
                        .font(.caption)
                        .foregroundStyle(UBTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
            
            // Botón de Enviar (Crear Cuenta) - SIN glass de fondo, degradado sólido y márgenes limpios
            Button {
                executeRegister()
            } label: {
                HStack(spacing: 8) {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text("Crear cuenta en UnderBro")
                            .font(.headline.weight(.bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(acceptedTerms ? AnyView(UBTheme.brandGradient) : AnyView(Color.white.opacity(0.15)))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: acceptedTerms ? UBTheme.accentEnd.opacity(0.4) : Color.clear, radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(auth.isLoading || !acceptedTerms)
            .padding(.top, 4)
        }
    }
    
    // MARK: - Medidor de Fuerza de Contraseña
    
    private var passwordStrengthView: some View {
        let (strengthLabel, color, progress) = calculatePasswordStrength(password)
        
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Fuerza:")
                    .font(.system(size: 11))
                    .foregroundStyle(UBTheme.textTertiary)
                Text(strengthLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Spacer()
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 4)
        }
    }
    
    private func calculatePasswordStrength(_ pass: String) -> (String, Color, CGFloat) {
        if pass.count < 6 {
            return ("Débil (mínimo 6 caracteres)", Color.red, 0.25)
        } else if pass.count < 8 {
            return ("Media", Color.yellow, 0.6)
        } else {
            let hasNumbers = pass.rangeOfCharacter(from: .decimalDigits) != nil
            let hasSpecial = pass.rangeOfCharacter(from: .punctuationCharacters) != nil || pass.rangeOfCharacter(from: .symbols) != nil
            if hasNumbers && hasSpecial {
                return ("Muy Segura ✨", Color.green, 1.0)
            }
            return ("Segura", Color.green, 0.85)
        }
    }
    
    // MARK: - Botón de Modo Invitado (Sin Glass de Fondo)
    
    private var guestModeButton: some View {
        Button {
            auth.continueAsGuest()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 14))
                Text("Explorar como invitado")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(UBTheme.textSecondary)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Pie de Página Legal
    
    private var footerLegalSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Link("Términos", destination: URL(string: "https://underbro.app/terminos")!)
                Text("•")
                Link("Privacidad", destination: URL(string: "https://underbro.app/privacidad")!)
                Text("•")
                Link("Cookies", destination: URL(string: "https://underbro.app/cookies")!)
            }
            .font(.caption2)
            .foregroundStyle(UBTheme.textTertiary)
            
            Text("UnderBro © 2026 · Todos los derechos reservados")
                .font(.system(size: 10))
                .foregroundStyle(UBTheme.textTertiary.opacity(0.8))
        }
    }
    
    // MARK: - Hoja de Recuperar Contraseña
    
    private var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                UBTheme.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(UBTheme.accentCyan)
                            .padding(.top, 10)
                        
                        Text("Recuperar Contraseña")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        
                        Text("Introduce tu correo electrónico y te enviaremos un enlace seguro para restablecerla.")
                            .font(.subheadline)
                            .foregroundStyle(UBTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Correo electrónico", systemImage: "envelope.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(UBTheme.textSecondary)
                        
                        TextField("tu@correo.com", text: $forgotPasswordEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    
                    if let success = forgotPasswordSuccessMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                            Text(success)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                        .background(Color.green.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                    }
                    
                    Button {
                        executeResetPassword()
                    } label: {
                        HStack(spacing: 8) {
                            if isSendingResetEmail {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Enviar enlace de recuperación")
                                    .font(.headline.weight(.bold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(UBTheme.accentCyan)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSendingResetEmail || forgotPasswordEmail.isEmpty)
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") {
                        isForgotPasswordPresented = false
                        forgotPasswordSuccessMessage = nil
                    }
                    .foregroundStyle(UBTheme.accentEnd)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Lógica de Acción
    
    private func executeLogin() {
        errorMessage = nil
        Task {
            do {
                _ = try await auth.signIn(email: email, password: password)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                dismiss()
            } catch {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func executeRegister() {
        errorMessage = nil
        Task {
            do {
                _ = try await auth.signUp(
                    email: email,
                    password: password,
                    username: username,
                    displayName: displayName.isEmpty ? username : displayName,
                    birthDate: birthDate,
                    roles: [selectedRole]
                )
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                dismiss()
            } catch {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func executeResetPassword() {
        isSendingResetEmail = true
        Task {
            do {
                try await auth.resetPassword(email: forgotPasswordEmail)
                isSendingResetEmail = false
                forgotPasswordSuccessMessage = "Enlace enviado. Comprueba tu bandeja de entrada o spam."
            } catch {
                isSendingResetEmail = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func executeGoogleSignIn() {
        errorMessage = nil
        Task {
            do {
                _ = try await auth.signInWithGoogle()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                dismiss()
            } catch {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Logo Oficial Vectorial de Google (Google "G" multicolor)

public struct OfficialGoogleLogoView: View {
    public var size: CGFloat = 18
    
    public init(size: CGFloat = 18) {
        self.size = size
    }
    
    public var body: some View {
        Canvas { context, canvasSize in
            let scaleX = canvasSize.width / 24.0
            let scaleY = canvasSize.height / 24.0
            
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * scaleX, y: y * scaleY)
            }
            
            // 1. Azul Google (#4285F4)
            var blue = Path()
            blue.move(to: p(22.56, 12.25))
            blue.addCurve(to: p(22.36, 10.0), control1: p(22.56, 11.47), control2: p(22.49, 10.72))
            blue.addLine(to: p(12.0, 10.0))
            blue.addLine(to: p(12.0, 14.26))
            blue.addLine(to: p(17.92, 14.26))
            blue.addCurve(to: p(15.71, 17.57), control1: p(17.66, 15.63), control2: p(16.88, 16.79))
            blue.addLine(to: p(15.71, 20.34))
            blue.addLine(to: p(19.28, 20.34))
            blue.addCurve(to: p(22.56, 12.25), control1: p(21.36, 18.42), control2: p(22.56, 15.60))
            blue.closeSubpath()
            context.fill(blue, with: .color(Color(red: 66/255, green: 133/255, blue: 244/255)))
            
            // 2. Verde Google (#34A853)
            var green = Path()
            green.move(to: p(12.0, 23.0))
            green.addCurve(to: p(19.28, 20.34), control1: p(14.97, 23.0), control2: p(17.46, 22.02))
            green.addLine(to: p(15.71, 17.57))
            green.addCurve(to: p(12.0, 18.63), control1: p(14.73, 18.23), control2: p(13.48, 18.63))
            green.addCurve(to: p(5.84, 14.10), control1: p(9.14, 18.63), control2: p(6.71, 16.70))
            green.addLine(to: p(2.18, 14.10))
            green.addLine(to: p(2.18, 16.94))
            green.addCurve(to: p(12.0, 23.0), control1: p(3.99, 20.53), control2: p(7.70, 23.0))
            green.closeSubpath()
            context.fill(green, with: .color(Color(red: 52/255, green: 168/255, blue: 83/255)))
            
            // 3. Amarillo Google (#FBBC05)
            var yellow = Path()
            yellow.move(to: p(5.84, 14.09))
            yellow.addCurve(to: p(5.49, 12.0), control1: p(5.62, 13.43), control2: p(5.49, 12.73))
            yellow.addCurve(to: p(5.84, 9.91), control1: p(5.49, 11.27), control2: p(5.62, 10.57))
            yellow.addLine(to: p(5.84, 7.06))
            yellow.addLine(to: p(2.18, 7.06))
            yellow.addCurve(to: p(1.0, 12.0), control1: p(1.43, 8.55), control2: p(1.0, 10.22))
            yellow.addCurve(to: p(2.18, 16.94), control1: p(1.0, 13.78), control2: p(1.43, 15.45))
            yellow.addLine(to: p(5.03, 14.72))
            yellow.addLine(to: p(5.84, 14.09))
            yellow.closeSubpath()
            context.fill(yellow, with: .color(Color(red: 251/255, green: 188/255, blue: 5/255)))
            
            // 4. Rojo Google (#EA4335)
            var red = Path()
            red.move(to: p(12.0, 5.38))
            red.addCurve(to: p(16.21, 7.02), control1: p(13.62, 5.38), control2: p(15.06, 5.94))
            red.addLine(to: p(19.36, 3.87))
            red.addCurve(to: p(12.0, 1.0), control1: p(17.45, 2.09), control2: p(14.97, 1.0))
            red.addCurve(to: p(2.18, 7.06), control1: p(7.70, 1.0), control2: p(3.99, 3.47))
            red.addLine(to: p(5.84, 9.90))
            red.addCurve(to: p(12.0, 5.38), control1: p(6.71, 7.30), control2: p(9.14, 5.38))
            red.closeSubpath()
            context.fill(red, with: .color(Color(red: 234/255, green: 67/255, blue: 53/255)))
        }
        .frame(width: size, height: size)
    }
}
