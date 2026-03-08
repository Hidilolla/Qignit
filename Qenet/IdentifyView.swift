import SwiftUI
import AVFoundation

/// View that listens to live music and identifies the Ethiopian pentatonic scale (Kiñit).
struct IdentifyView: View {
    @State private var analyzer = AudioAnalyzer()
    @State private var micPermissionDenied = false
    @State private var pulseAmount: CGFloat = 1.0
    
    private static let appGreen = Color(red: 0.086, green: 0.588, blue: 0.22)
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    listeningSection
                    
                    if analyzer.isListening {
                        noteDetectionStrip
                        
                        if let scale = analyzer.detectedScale {
                            resultCard(scale: scale)
                                .transition(.scale.combined(with: .opacity))
                        } else if analyzer.detectedSemitones.count > 0 {
                            analyzingCard
                                .transition(.opacity)
                        }
                    }
                    
                    instructionsSection
                }
                .padding()
            }
            .background(Color(red: 0.94, green: 0.98, blue: 0.95))
            .navigationTitle("Identify")
            .animation(.snappy(duration: 0.35), value: analyzer.detectedScale)
            .animation(.snappy(duration: 0.35), value: analyzer.isListening)
        }
        .onDisappear {
            analyzer.stopListening()
        }
    }
    
    // MARK: - Listening Section
    
    private var listeningSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer pulse rings
                if analyzer.isListening {
                    Circle()
                        .stroke(Self.appGreen.opacity(0.15), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseAmount)
                        .opacity(2.0 - Double(pulseAmount))
                    
                    Circle()
                        .stroke(Self.appGreen.opacity(0.1), lineWidth: 1.5)
                        .frame(width: 170, height: 170)
                        .scaleEffect(pulseAmount * 0.9)
                        .opacity(2.0 - Double(pulseAmount))
                }
                
                // Level ring
                Circle()
                    .stroke(
                        Self.appGreen.opacity(analyzer.isListening ? 0.2 : 0.08),
                        lineWidth: 4
                    )
                    .frame(width: 110, height: 110)
                
                if analyzer.isListening {
                    Circle()
                        .trim(from: 0, to: CGFloat(analyzer.inputLevel) * 3)
                        .stroke(Self.appGreen, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.1), value: analyzer.inputLevel)
                }
                
                // Mic button
                Button {
                    toggleListening()
                } label: {
                    Image(systemName: analyzer.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(analyzer.isListening ? .white : Self.appGreen)
                        .frame(width: 90, height: 90)
                        .background(
                            Circle()
                                .fill(analyzer.isListening ? Self.appGreen : Self.appGreen.opacity(0.1))
                        )
                        .shadow(
                            color: analyzer.isListening ? Self.appGreen.opacity(0.3) : .clear,
                            radius: 12
                        )
                }
                .buttonStyle(.plain)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseAmount = 1.3
                }
            }
            
            Text(analyzer.isListening ? "Listening..." : "Tap to Start")
                .font(.headline.weight(.semibold))
                .foregroundStyle(analyzer.isListening ? Self.appGreen : .secondary)
            
            if analyzer.isListening && analyzer.dominantFrequency > 0 {
                Text("\(Int(analyzer.dominantFrequency)) Hz")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            
            if micPermissionDenied {
                Label("Microphone access denied. Enable it in Settings.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Note Detection Strip
    
    private var noteDetectionStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Detected Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                ForEach(0..<12, id: \.self) { semitone in
                    let isDetected = analyzer.detectedSemitones.contains(semitone)
                    let noteName = ScaleNote.chromaticNames[semitone]
                    let isInScale = isNoteInDetectedScale(semitone)
                    
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                isDetected
                                    ? (isInScale ? Self.appGreen : Self.appGreen.opacity(0.4))
                                    : Color(.systemGray5)
                            )
                            .frame(height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        isDetected ? Self.appGreen : .clear,
                                        lineWidth: 1
                                    )
                            )
                        
                        Text(noteName)
                            .font(.system(size: 8, weight: isDetected ? .bold : .regular))
                            .foregroundStyle(isDetected ? .primary : .tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeOut(duration: 0.2), value: isDetected)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Result Card
    
    private func resultCard(scale: EthiopianScale) -> some View {
        let c = themeColor(for: scale)
        
        return VStack(spacing: 16) {
            // Scale icon
            Image(systemName: scale.iconName)
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(c, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: c.opacity(0.3), radius: 8, y: 2)
            
            // Scale name
            VStack(spacing: 4) {
                Text(scale.amharicName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                
                Text(scale.rawValue)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            // Root note
            if !analyzer.detectedRootName.isEmpty {
                HStack(spacing: 6) {
                    Text("Root:")
                        .foregroundStyle(.secondary)
                    Text(analyzer.detectedRootName)
                        .fontWeight(.bold)
                        .monospaced()
                }
                .font(.subheadline)
            }
            
            // Confidence bar
            VStack(spacing: 6) {
                HStack {
                    Text("Confidence")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(analyzer.confidence * 100))%")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(confidenceColor)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(confidenceColor)
                            .frame(width: geo.size.width * analyzer.confidence)
                            .animation(.easeOut(duration: 0.3), value: analyzer.confidence)
                    }
                }
                .frame(height: 8)
            }
            
            // Description
            Text(scale.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(c.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Analyzing Card
    
    private var analyzingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Self.appGreen)
            
            Text("Analyzing...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Text("Play or sing at least 3 distinct notes")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Instructions
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How It Works", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(Self.appGreen)
            
            VStack(alignment: .leading, spacing: 8) {
                instructionRow(number: 1, text: "Tap the microphone to start listening")
                instructionRow(number: 2, text: "Play or sing an Ethiopian melody")
                instructionRow(number: 3, text: "The app detects the notes and matches them to a Kiñit")
                instructionRow(number: 4, text: "Best results with clear, melodic input")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Self.appGreen, in: Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
    
    private func toggleListening() {
        if analyzer.isListening {
            analyzer.stopListening()
        } else {
            // Check microphone permission
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
