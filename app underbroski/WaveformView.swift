//
//  WaveformView.swift
//  UnderBro iOS
//
//  Componente de onda de audio interactiva tipo "Liquid Glass".
//  Permite visualizar las frecuencias de la canción y hacer 'scrubbing' (deslizar)
//  para cambiar el segundo exacto de reproducción.
//

import SwiftUI

public struct WaveformView: View {
    public let samples: [CGFloat]
    public let progress: Double // 0.0 a 1.0
    public var onSeek: ((Double) -> Void)? = nil
    
    // Configuración visual
    public var barWidth: CGFloat = 3.5
    public var barSpacing: CGFloat = 2.5
    public var activeColor: Color = .white
    public var inactiveColor: Color = Color.white.opacity(0.3)
    public var showScrubberHandle: Bool = true
    
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double = 0.0
    
    public init(
        samples: [CGFloat]? = nil,
        progress: Double = 0.0,
        barWidth: CGFloat = 3.5,
        barSpacing: CGFloat = 2.5,
        activeColor: Color = .white,
        inactiveColor: Color = Color.white.opacity(0.3),
        showScrubberHandle: Bool = false,
        onSeek: ((Double) -> Void)? = nil
    ) {
        // Si no se proveen muestras reales de la pista, generamos una onda estilizada y armónica
        self.samples = samples ?? WaveformView.generateMockSamples(count: 42)
        self.progress = progress
        self.barWidth = barWidth
        self.barSpacing = barSpacing
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.showScrubberHandle = showScrubberHandle
        self.onSeek = onSeek
    }
    
    private var currentProgress: Double {
        isDragging ? dragProgress : progress
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let totalHeight = proxy.size.height
            let count = max(1, samples.count)
            let calculatedBarWidth = max(2, (totalWidth - (CGFloat(count - 1) * barSpacing)) / CGFloat(count))
            
            ZStack(alignment: .leading) {
                // Barras de la forma de onda
                HStack(alignment: .center, spacing: barSpacing) {
                    ForEach(0..<count, id: \.self) { index in
                        let sampleProgress = Double(index) / Double(count)
                        let isPlayed = sampleProgress <= currentProgress
                        let heightFactor = samples[index]
                        let barH = max(4, totalHeight * heightFactor)
                        
                        RoundedRectangle(cornerRadius: calculatedBarWidth / 2)
                            .fill(isPlayed ? activeColor : inactiveColor)
                            .frame(width: calculatedBarWidth, height: barH)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                
                // Indicador / Cursor de desplazamiento (scrubber handle)
                if showScrubberHandle {
                    let cursorX = min(max(0, CGFloat(currentProgress) * totalWidth), totalWidth)
                    
                    Capsule()
                        .fill(UBTheme.accentCyan)
                        .frame(width: 4, height: totalHeight)
                        .shadow(color: UBTheme.accentCyan.opacity(0.8), radius: 6, x: 0, y: 0)
                        .offset(x: cursorX - 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let newProgress = max(0.0, min(1.0, Double(value.location.x / totalWidth)))
                        dragProgress = newProgress
                    }
                    .onEnded { value in
                        let finalProgress = max(0.0, min(1.0, Double(value.location.x / totalWidth)))
                        dragProgress = finalProgress
                        isDragging = false
                        onSeek?(finalProgress)
                    }
            )
        }
    }
    
    /// Genera muestras de audio matemáticas deterministas para cuando no hay waveform JSON precargado
    public static func generateMockSamples(count: Int) -> [CGFloat] {
        (0..<count).map { i in
            let step = Double(i)
            let base = sin(step * 0.45) * 0.4 + cos(step * 0.9) * 0.35 + sin(step * 1.8) * 0.25
            let normalized = (base + 1.0) / 2.0 // Rango 0.0 .. 1.0
            return CGFloat(0.20 + 0.80 * normalized)
        }
    }
}
