import SwiftUI
import AVFoundation

/// View that listens to live music and identifies the Ethiopian pentatonic scale (Kiñit).
struct IdentifyView: View {
    @State private var analyzer = AudioAnalyzer()
    @State private var micPermissionDenied = false
    @State private var pulseAmount: CGFloat = 1.0
    @State private var wavePhase: CGFloat = 0
    
    private static let appGreen = Color(red: 0.086, green: 0.588, blue: 0.22)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.94, green: 0.98, blue: 0.95)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top: Big mic area — fills available space
                    Spacer(minLength: 0)
                    
                    micSection
                    
                    Spacer(minLength: 0)
                    
                    // Bottom: Feedback area + button pinned to bottom
                    VStack(spacing: 10) {
                        // Note strip
                        if analyzer.isListening {
                            noteStrip
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Result / analyzing / idle
                        if analyzer.isListening {
                            if let scale = analyzer.detectedScale {
                                compactResult(scale: scale)
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                            } else if !analyzer.detectedSemitones.isEmpty {
                                compactAnalyzing
                                    .transition(.opacity)
                            } else {
                                waitingPrompt
                                    .transition(.opacity)
                            }
                        } else {
                            idleTips
                                .transition(.opacity)
                        }
                        
                        // Action button
                        actionButton
                            .padding(.top, 4)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Identify")
            .animation(.snappy(duration: 0.35), value: analyzer.detectedScale)
            .animation(.snappy(duration: 0.3), value: analyzer.isListening)
        }
        .onDisappear {
            analyzer.stopListening()
        }
    }
    
    // MARK: - Mic Section
    
    private var micSection: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.85
            let ringSize = size * 0.75
            
            ZStack {
                // Outer pulse rings
                if analyzer.isListening {
                    Circle()
                        .stroke(Self.appGreen.opacity(0.08), lineWidth: 2)
                        .frame(width: size * 0.95, height: size * 0.95)
                        .scaleEffect(pulseAmount)
                        .opacity(2.0 - Double(pulseAmount))
                    
                    Circle()
                        .stroke(Self.appGreen.opacity(0.05), lineWidth: 1.5)
                        .frame(width: size, height: size)
                        .scaleEffect(pulseAmount * 0.92)
                        .opacity(2.0 - Double(pulseAmount))
                }
                
                // Background circle
                Circle()
                    .fill(
                        analyzer.isListening
                            ? Self.appGreen.opacity(0.06)
                            : Color(.systemGray6).opacity(0.5)
                    )
                    .frame(width: ringSize, height: ringSize)
                
                // Level ring
                Circle()
                    .stroke(Color(.systemGray4).opacity(0.3), lineWidth: 6)
                    .frame(width: ringSize, height: ringSize)
                
                if analyzer.isListening {
                    Circle()
                        .trim(from: 0, to: min(CGFloat(analyzer.inputLevel) * 4, 1.0))
                        .stroke(
                            AngularGradient(
                                colors: [Self.appGreen.opacity(0.2), Self.appGreen, Self.appGreen.opacity(0.2)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.1), value: analyzer.inputLevel)
                }
                
                // Mic icon
                VStack(spacing: 8) {
                    Image(systemName: analyzer.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: ringSize * 0.25, weight: .medium))
                        .foregroundStyle(analyzer.isListening ? Self.appGreen : .secondary)
                        .symbolEffect(.variableColor.iterative, isActive: analyzer.isListening)
                    
                    if analyzer.isListening && analyzer.dominantFrequency > 0 {
                        Text("\(Int(analyzer.dominantFrequency)) Hz")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    } else if !analyzer.isListening {
                        Text("Tap below to start")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAmount = 1.2
            }
        }
    }
    
    // MARK: - Note Strip (compact horizontal)
    
    private var noteStrip: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { semitone in
                let isDetected = analyzer.detectedSemitones.contains(semitone)
                let isInScale = isNoteInDetectedScale(semitone)
                let isRoot = isRootNote(semitone)
                let name = ScaleNote.chromaticNames[semitone]
                
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            isDetected
                                ? (isRoot ? Self.appGreen : isInScale ? Self.appGreen.opacity(0.7) : Self.appGreen.opacity(0.35))
                                : Color(.systemGray5)
                        )
                        .frame(height: 26)
                        .overlay(
                            Text(name)
                                .font(.system(size: 9, weight: isDetected ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isDetected ? .white : .secondary)
                        )
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.15), value: isDetected)
            }
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }
    
    // MARK: - Compact Result
    
    private func compactResult(scale: EthiopianScale) -> some View {
        let c = themeColor(for: scale)
        
        return VStack(spacing: 14) {
            // Icon + Name row
            HStack(spacing: 14) {
                Image(systemName: scale.iconName)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(c.gradient, in: RoundedRectangle(cornerRadius: 13))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(scale.amharicName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    
                    HStack(spacing: 6) {
                        Text(scale.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !analyzer.detectedRootName.isEmpty {
                            Text("·")
                                .foregroundStyle(.quaternary)
                            Text("Root \(analyzer.detectedRootName)")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                Spacer()
                
                // Confidence badge
                Text("\(Int(analyzer.confidence * 100))%")
                    .font(.title3.weight(.bold).monospaced())
                    .foregroundStyle(confidenceColor)
            }
            
            // Confidence bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [confidenceColor.opacity(0.6), confidenceColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(analyzer.confidence, 1.0))
                        .animation(.easeOut(duration: 0.3), value: analyzer.confidence)
                }
            }
            .frame(height: 5)
            
            // Scale notes row
            HStack(spacing: 5) {
                let rootIndex = ScaleNote.chromaticNames.firstIndex(of: analyzer.detectedRootName) ?? 0
                ForEach(scale.intervals, id: \.self) { interval in
                    let noteIdx = (interval + rootIndex) % 12
                    Text(ScaleNote.chromaticNames[noteIdx])
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(c.opacity(interval == 0 ? 1.0 : 0.55), in: Capsule())
                }
            }
            
            // Description
            Text(scale.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(c.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: c.opacity(0.08), radius: 8, y: 3)
    }
    
    // MARK: - Compact Analyzing
    
    private var compactAnalyzing: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                    .frame(width: 40, height: 40)
                Circle()
                    .trim(from: 0, to: min(Double(analyzer.detectedSemitones.count) / 3.0, 1.0))
                    .stroke(Self.appGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                Text("\(analyzer.detectedSemitones.count)")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundStyle(Self.appGreen)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzing...")
                    .font(.subheadline.weight(.semibold))
                Text("\(analyzer.detectedSemitones.count) of 3 notes detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
    
    // MARK: - Waiting Prompt
    
    private var waitingPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("Play or sing a melody...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Idle Tips
    
    private var idleTips: some View {
        VStack(spacing: 12) {
            Text("Kiñit Identifier")
                .font(.title2.weight(.bold))
            
            Text("Identify Ethiopian pentatonic scales from live music")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Divider().padding(.vertical, 4)
            
            VStack(spacing: 8) {
                tipRow(icon: "guitars.fill", text: "Best with masinko, krar, or voice")
                tipRow(icon: "music.note", text: "Play a clear melody, one note at a time")
                tipRow(icon: "speaker.wave.2.fill", text: "Keep the device close to the source")
            }
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Self.appGreen)
                .frame(width: 24)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Action Button
    
    private var actionButton: some View {
        Button {
            toggleListening()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: analyzer.isListening ? "stop.fill" : "mic.fill")
                Text(analyzer.isListening ? "Stop Listening" : "Start Listening")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                analyzer.isListening
                    ? Color(.systemGray5).gradient
                    : Self.appGreen.gradient,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .foregroundStyle(analyzer.isListening ? Color.primary : Color.white)
        }
        .buttonStyle(.plain)
        
        // Mic permission error
        .overlay(alignment: .top) {
            if micPermissionDenied {
                Text("Microphone access denied — enable in Settings")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .offset(y: -18)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var confidenceColor: Color {
        if analyzer.confidence > 0.7 { return .green }
        if analyzer.confidence > 0.5 { return .orange }
        return .red
    }
    
    private func isNoteInDetectedScale(_ semitone: Int) -> Bool {
        guard let scale = analyzer.detectedScale else { return false }
        let rootIndex = ScaleNote.chromaticNames.firstIndex(of: analyzer.detectedRootName) ?? 0
        let scaleNotes = Set(scale.intervals.map { ($0 + rootIndex) % 12 })
        return scaleNotes.contains(semitone)
    }
    
    private func isRootNote(_ semitone: Int) -> Bool {
        let rootIndex = ScaleNote.chromaticNames.firstIndex(of: analyzer.detectedRootName) ?? -1
        return semitone == rootIndex
    }
    
    private func toggleListening() {
        if analyzer.isListening {
            analyzer.stopListening()
        } else {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                analyzer.startListening()
                micPermissionDenied = false
            case .denied:
                micPermissionDenied = true
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted {
                            analyzer.startListening()
                            micPermissionDenied = false
                        } else {
                            micPermissionDenied = true
                        }
                    }
                }
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    IdentifyView()
}
