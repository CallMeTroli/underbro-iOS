//
//  UploadTrackSheet.swift
//  UnderBro iOS
//
//  Hoja modal (Sheet) para subir contenido a UnderBro
//  Permite subir las 4 categorías disponibles en la plataforma web:
//    1. "Pista": Canción completa con audio, portada, género y colaboradores
//    2. "Beat": Instrumental con BPM, tonalidad/key y tipo de licencia
//    3. "Foto": Captura visual para el feed de la comunidad
//    4. "Evento": Concierto o evento de la escena underground con enlace de entradas
//  Controles nativos Liquid Glass de iOS 26+ (`GlassEffectContainer`, `.glassEffect()`, `.buttonStyle(.glass)`).
//

import SwiftUI

public struct UploadTrackSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    public enum UploadCategory: String, CaseIterable, Identifiable {
        case pista = "Pista"
        case beat = "Beat"
        case foto = "Foto"
        case evento = "Evento"
        
        public var id: String { rawValue }
        
        public var icon: String {
            switch self {
            case .pista: return "music.note"
            case .beat: return "pianokeys"
            case .foto: return "camera.fill"
            case .evento: return "ticket.fill"
            }
        }
    }
    
    @State private var selectedCategory: UploadCategory = .pista
    
    // Campos comunes y de Pista
    @State private var trackTitle: String = ""
    @State private var tagline: String = ""
    @State private var featuredArtistsText: String = ""
    @State private var selectedGenre: String = "Electronic"
    @State private var hasSelectedAudioFile: Bool = false
    @State private var selectedAudioFileName: String = ""
    @State private var isUploading: Bool = false
    
    // Campos de Beat
    @State private var bpmText: String = "140"
    @State private var selectedKey: String = "A# Menor"
    @State private var licenseType: String = "Lease / Alquiler"
    
    // Campos de Foto
    @State private var photoCaption: String = ""
    @State private var photoURL: String = ""
    
    // Campos de Evento
    @State private var eventVenue: String = ""
    @State private var eventCity: String = "Madrid"
    @State private var eventDate: Date = Date()
    @State private var eventTicketURL: String = ""
    
    private let availableGenres = ["Electronic", "Regueton", "Trap / Drill", "Ambient Wave", "Pluggnb", "Techno"]
    private let availableKeys = ["C Menor", "C# Menor", "D Menor", "D# Menor", "E Menor", "F Menor", "F# Menor", "G Menor", "G# Menor", "A Menor", "A# Menor", "B Menor", "C Mayor", "A# Mayor"]
    private let licenseOptions = ["Gratis / No Comercial", "Lease / Alquiler", "Exclusiva"]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Selector de Categoría Liquid Glass
                    categoryPicker
                        .padding(.horizontal, 16)
                    
                    // Formulario específico según categoría
                    switch selectedCategory {
                    case .pista:
                        trackUploadForm
                    case .beat:
                        beatUploadForm
                    case .foto:
                        photoUploadForm
                    case .evento:
                        eventUploadForm
                    }
                    
                    // Botón Publicar con estilo .glassProminent nativo
                    publishButton
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 24)
                }
                .padding(.vertical, 16)
            }
            .background(UBTheme.backgroundDark.ignoresSafeArea())
            .navigationTitle("Subir a UnderBro")
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
    
    // MARK: - Selector de Categoría
    
    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(UploadCategory.allCases) { category in
                let isSelected = selectedCategory == category
                
                if isSelected {
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                        }
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(UBTheme.accentStart)
                } else {
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
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
    
    // MARK: - 1. Formulario de Pista
    
    private var trackUploadForm: some View {
        VStack(spacing: 20) {
            // Portada
            coverPickerSection(hint: trackTitle.isEmpty ? "Portada de la Pista" : trackTitle)
            
            // Archivo de audio
            audioFilePickerSection
            
            // Campos de texto
            VStack(spacing: 12) {
                textFieldGroup(label: "Título de la pista", placeholder: "ej: ###sol", text: $trackTitle)
                textFieldGroup(label: "Colaboradores (opcional)", placeholder: "ej: calimero, Gachas", text: $featuredArtistsText)
                textFieldGroup(label: "Dedicatoria o descripción corta", placeholder: "ej: <33 grabada en las 4 torres", text: $tagline)
            }
            .padding(.horizontal, 16)
            
            // Género musical
            genrePickerSection
        }
    }
    
    // MARK: - 2. Formulario de Beat
    
    private var beatUploadForm: some View {
        VStack(spacing: 20) {
            // Portada de Beat
            coverPickerSection(hint: trackTitle.isEmpty ? "Artwork del Beat" : trackTitle)
            
            // Archivo de audio
            audioFilePickerSection
            
            // Título
            VStack(spacing: 12) {
                textFieldGroup(label: "Título del Beat", placeholder: "ej: Prettifun en un episodio depresivo", text: $trackTitle)
                
                // BPM y Key en dos columnas
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BPM (Tempo)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(UBTheme.textSecondary)
                        
                        TextField("140", text: $bpmText)
                            .keyboardType(.numberPad)
                            .padding(14)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tonalidad / Key")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(UBTheme.textSecondary)
                        
                        Picker("Key", selection: $selectedKey) {
                            ForEach(availableKeys, id: \.self) { key in
                                Text(key).tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                
                // Tipo de Licencia
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tipo de Licencia")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(UBTheme.textSecondary)
                    
                    Picker("Licencia", selection: $licenseType) {
                        ForEach(licenseOptions, id: \.self) { lic in
                            Text(lic).tag(lic)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.horizontal, 16)
            
            // Género
            genrePickerSection
        }
    }
    
    // MARK: - 3. Formulario de Foto
    
    private var photoUploadForm: some View {
        VStack(spacing: 18) {
            coverPickerSection(hint: photoCaption.isEmpty ? "Captura Visual" : photoCaption)
            
            VStack(spacing: 12) {
                textFieldGroup(label: "Enlace o archivo de la foto", placeholder: "https://...", text: $photoURL)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pie de foto / Hashtags")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(UBTheme.textSecondary)
                    
                    TextField("Momento en el estudio...", text: $photoCaption, axis: .vertical)
                        .lineLimit(3...5)
                        .padding(14)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 4. Formulario de Evento
    
    private var eventUploadForm: some View {
        VStack(spacing: 18) {
            coverPickerSection(hint: trackTitle.isEmpty ? "Cartel del Evento" : trackTitle)
            
            VStack(spacing: 12) {
                textFieldGroup(label: "Nombre del Evento / Concierto", placeholder: "ej: UnderBro Live Madrid #03", text: $trackTitle)
                
                HStack(spacing: 12) {
                    textFieldGroup(label: "Sala / Club", placeholder: "ej: Sala Specka", text: $eventVenue)
                    textFieldGroup(label: "Ciudad", placeholder: "Madrid", text: $eventCity)
                }
                
                DatePicker("Fecha y Hora", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                    .padding(12)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                
                textFieldGroup(label: "Enlace de Venta de Entradas (opcional)", placeholder: "https://dice.fm/...", text: $eventTicketURL)
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Componentes Auxiliares
    
    private func coverPickerSection(hint: String) -> some View {
        ZStack {
            PlaceholderArtworkView(
                style: selectedCategory == .beat ? .neonCyan : .vibrantGold,
                titleHint: hint,
                systemIcon: selectedCategory.icon,
                cornerRadius: 22
            )
            .frame(height: 190)
            
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 24))
                Text("Elegir Imagen de Portada")
                    .font(.caption.weight(.bold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
    }
    
    private var audioFilePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Archivo de Audio (.wav / .mp3 / .flac)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UBTheme.textSecondary)
            
            Button {
                hasSelectedAudioFile = true
                selectedAudioFileName = selectedCategory == .beat ? "drill_beat_140bpm_master.wav" : "final_mix_master_24bit.wav"
            } label: {
                HStack {
                    Image(systemName: hasSelectedAudioFile ? "checkmark.circle.fill" : "waveform.badge.plus")
                        .foregroundStyle(hasSelectedAudioFile ? UBTheme.accentCyan : UBTheme.accentStart)
                    
                    Text(hasSelectedAudioFile ? selectedAudioFileName : "Seleccionar archivo de audio...")
                        .font(.subheadline)
                        .foregroundStyle(hasSelectedAudioFile ? .white : UBTheme.textSecondary)
                    
                    Spacer()
                    
                    Text(hasSelectedAudioFile ? "Cambiar" : "Explorar")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(UBTheme.accentEnd)
                }
                .padding(14)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, 16)
    }
    
    private func textFieldGroup(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(UBTheme.textSecondary)
            
            TextField(placeholder, text: text)
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
    }
    
    private var genrePickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Género musical")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UBTheme.textSecondary)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableGenres, id: \.self) { genre in
                        let isSelected = selectedGenre == genre
                        
                        if isSelected {
                            Button(genre) {
                                selectedGenre = genre
                            }
                            .buttonStyle(.glassProminent)
                            .tint(UBTheme.accentStart)
                        } else {
                            Button(genre) {
                                selectedGenre = genre
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var isFormValid: Bool {
        switch selectedCategory {
        case .pista:
            return !trackTitle.isEmpty && hasSelectedAudioFile
        case .beat:
            return !trackTitle.isEmpty && hasSelectedAudioFile
        case .foto:
            return !photoCaption.isEmpty
        case .evento:
            return !trackTitle.isEmpty && !eventVenue.isEmpty
        }
    }
    
    private var publishButton: some View {
        Button {
            uploadContent()
        } label: {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Publicar \(selectedCategory.rawValue) en UnderBro")
                }
            }
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(UBTheme.accentStart)
        .disabled(!isFormValid || isUploading)
    }
    
    private func uploadContent() {
        isUploading = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                isUploading = false
                dismiss()
            }
        }
    }
}
