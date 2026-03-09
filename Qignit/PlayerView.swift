import SwiftUI

// MARK: - Theme Color Helper

/// Resolves an EthiopianScale's theme color name to a SwiftUI Color.
func themeColor(for scale: EthiopianScale) -> Color {
    switch scale.themeColorName {
    case "indigo": return .indigo
    case "red": return .red
    case "teal": return .teal
    case "orange": return .orange
    default: return .accentColor
    }
}

// MARK: - Chromatic Key Model

/// Represents a single chromatic key on the piano keyboard.
struct ChromaticKey: Identifiable {
    let id = UUID()
    let semitone: Int           // 0-12 from root
    let noteName: String
    let isBlack: Bool
    let frequency: Double
    /// If this key is part of the active pentatonic scale, its scale note info.
    var scaleNote: ScaleNote?
    /// Which white-key index this sits at (for positioning black keys).
    let whiteKeyIndex: Int?
    
    /// Which semitones in a chromatic octave are black keys.
    static let blackKeySemitones: Set<Int> = [1, 3, 6, 8, 10]
    
    /// Build a full chromatic octave with scale notes mapped in.
    static func chromaticOctave(
        rootSemitone: Int,
        scale: EthiopianScale
    ) -> [ChromaticKey] {
        let scaleNotes = ScaleGenerator.generateNotes(
            scale: scale,
            rootSemitone: rootSemitone,
            octaveRange: 0...0
        )
        let scaleIntervalMap = Dictionary(
            uniqueKeysWithValues: zip(scale.intervals, scaleNotes)
        )
        
        let names = ScaleNote.chromaticNames
        var keys: [ChromaticKey] = []
        var whiteIndex = 0
        
        for semitone in 0...12 {
            let noteIndex = (rootSemitone + semitone) % 12
            let isBlack = blackKeySemitones.contains(semitone)
            let totalSemitones = rootSemitone + semitone
            let frequency = ScaleGenerator.c4Frequency * pow(2.0, Double(totalSemitones) / 12.0)
            
            let matchedNote: ScaleNote?
            if semitone == 12 {
                // Octave above root — not in the 5-note set
                matchedNote = nil
            } else {
                matchedNote = scaleIntervalMap[semitone]
            }
            
            keys.append(ChromaticKey(
                semitone: semitone,
                noteName: names[noteIndex],
                isBlack: isBlack,
                frequency: frequency,
                scaleNote: matchedNote,
                whiteKeyIndex: isBlack ? nil : whiteIndex
            ))
            
            if !isBlack { whiteIndex += 1 }
        }
        return keys
    }
}

// MARK: - PlayerView

/// The available instrument views.
enum InstrumentMode: String, CaseIterable {
    case piano = "Piano"
    case guitar = "Guitar"
    
    var iconName: String {
        switch self {
        case .piano: return "pianokeys"
        case .guitar: return "guitars.fill"
        }
    }
}

/// Interactive pentatonic piano for playing Ethiopian scale notes.
struct PlayerView: View {
    @State private var selectedScale: EthiopianScale = .tizita
    @State private var rootNoteIndex: Int = 0
    @State private var activeKeyID: UUID?
    @State private var hapticTrigger: Int = 0
    @State private var isAutoPlaying = false
    @State private var instrumentMode: InstrumentMode = .piano
    @Bindable var toneGenerator: ToneGenerator
    
    private var chromaticKeys: [ChromaticKey] {
        ChromaticKey.chromaticOctave(
            rootSemitone: ScaleGenerator.rootNotes[rootNoteIndex].semitones,
            scale: selectedScale
        )
    }
    
    private var scaleNotes: [ScaleNote] {
        ScaleGenerator.generateNotes(
            scale: selectedScale,
            rootSemitone: ScaleGenerator.rootNotes[rootNoteIndex].semitones,
            octaveRange: 0...0
        )
    }
    
    private var color: Color { themeColor(for: selectedScale) }
    
    var body: some View {
        ZStack {
            meshBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                topBar
                
                scalePicker
                    .padding(.top, 8)
                
                instrumentPicker
                    .padding(.top, 12)
                
                Spacer()
                
                // Instrument view
                if instrumentMode == .piano {
                    pianoKeyboard
                        .aspectRatio(1.6, contentMode: .fit)
                } else {
                    guitarFretboard
                }
                
                Spacer()
                
                bottomControls
            }
            .padding(.bottom, 8)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .onChange(of: selectedScale) { _, _ in keyReleased() }
        .onChange(of: rootNoteIndex) { _, _ in keyReleased() }
    }
    
    // MARK: - Mesh Background
    
    private var meshBackground: some View {
        MeshGradient(width: 3, height: 3, points: [
            .init(0, 0),    .init(0.5, 0),   .init(1, 0),
            .init(0, 0.5),  .init(0.5, 0.5), .init(1, 0.5),
            .init(0, 1),    .init(0.5, 1),    .init(1, 1)
        ], colors: meshColors)
        .opacity(activeKeyID != nil ? 0.55 : 0.25)
        .animation(.easeInOut(duration: 0.6), value: selectedScale)
        .animation(.easeInOut(duration: 0.15), value: activeKeyID != nil)
    }
    
    private static let appGreen = Color(red: 0.086, green: 0.588, blue: 0.22)
    
    private var meshColors: [Color] {
        let c = color
        let bg = Color(red: 0.94, green: 0.98, blue: 0.95)
        let g = Self.appGreen
        switch selectedScale {
        case .tizita:
            return [
                bg, g.opacity(0.15), bg,
                .indigo.opacity(0.15), c.opacity(0.3), g.opacity(0.12),
                bg, g.opacity(0.1), bg
            ]
        case .bati:
            return [
                bg, g.opacity(0.15), bg,
                .red.opacity(0.15), c.opacity(0.3), g.opacity(0.12),
                bg, g.opacity(0.1), bg
            ]
        case .ambassel:
            return [
                bg, g.opacity(0.15), bg,
                .teal.opacity(0.15), c.opacity(0.3), g.opacity(0.12),
                bg, g.opacity(0.1), bg
            ]
        case .anchihoye:
            return [
                bg, g.opacity(0.15), bg,
                .orange.opacity(0.15), c.opacity(0.3), g.opacity(0.12),
                bg, g.opacity(0.1), bg
            ]
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedScale.amharicName)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(selectedScale.rawValue)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Menu {
                ForEach(0..<ScaleGenerator.rootNotes.count, id: \.self) { index in
                    Button {
                        rootNoteIndex = index
                    } label: {
                        HStack {
                            Text(ScaleGenerator.rootNotes[index].name)
                            if index == rootNoteIndex {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(ScaleGenerator.rootNotes[rootNoteIndex].name)
                        .font(.title3.weight(.bold).monospaced())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .foregroundStyle(.primary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }
    
    // MARK: - Scale Picker
    
    private var scalePicker: some View {
        HStack(spacing: 10) {
            ForEach(EthiopianScale.allCases) { scale in
                let isSelected = selectedScale == scale
                let c = themeColor(for: scale)
                
                Button {
                    withAnimation(.snappy(duration: 0.35)) {
                        selectedScale = scale
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: scale.iconName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : c)
                            .frame(width: 42, height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? c : c.opacity(0.1))
                            )
                        
                        Text(scale.rawValue)
                            .font(.caption2.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? .ultraThinMaterial : .regularMaterial)
                            .shadow(
                                color: isSelected ? c.opacity(0.3) : .black.opacity(0.06),
                                radius: isSelected ? 8 : 4,
                                y: isSelected ? 2 : 1
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? c.opacity(0.4) : .clear, lineWidth: 1.5)
                    )
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Instrument Picker
    
    private var instrumentPicker: some View {
        HStack(spacing: 4) {
            ForEach(InstrumentMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        keyReleased()
                        instrumentMode = mode
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.iconName)
                            .font(.caption)
                        Text(mode.rawValue)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(instrumentMode == mode ? color.opacity(0.15) : .clear)
                    )
                    .foregroundStyle(instrumentMode == mode ? color : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
    }
    
    // MARK: - Guitar Fretboard
    
    /// Standard guitar tuning: E2 A2 D3 G3 B3 E4 (low to high)
    /// Displayed left-to-right: low E on left, high E on right (player's perspective)
    private static let guitarStringTunings: [(name: String, semitone: Int)] = [
        ("E", 40), ("A", 45), ("D", 50), ("G", 55), ("B", 59), ("E", 64)
    ]
    
    /// Number of frets to display
    private static let fretCount = 7
    
    private var guitarFretboard: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let stringCount = CGFloat(Self.guitarStringTunings.count)
            let fretCount = CGFloat(Self.fretCount)
            let stringSpacing = width / (stringCount + 1)
            let fretSpacing = height / (fretCount + 1)
            let nutHeight: CGFloat = 5
            
            ZStack(alignment: .topLeading) {
                // Fretboard background
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.38, green: 0.24, blue: 0.13),
                                Color(red: 0.30, green: 0.18, blue: 0.09)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Fret position markers (dots) — frets 3, 5, 7
                ForEach([3, 5, 7], id: \.self) { fret in
                    if fret <= Self.fretCount {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 10, height: 10)
                            .position(
                                x: width / 2,
                                y: fretSpacing * CGFloat(fret) + fretSpacing / 2
                            )
                    }
                }
                
                // Nut (top bar)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.92))
                    .frame(width: width - stringSpacing, height: nutHeight)
                    .position(x: width / 2, y: fretSpacing / 2)
                
                // Fret wires (horizontal)
                ForEach(1...Self.fretCount, id: \.self) { fret in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.72), Color(white: 0.58)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width - stringSpacing, height: 2.5)
                        .position(
                            x: width / 2,
                            y: fretSpacing * CGFloat(fret) + fretSpacing / 2
                        )
                }
                
                // Fret numbers on the right edge
                ForEach(1...Self.fretCount, id: \.self) { fret in
                    Text("\(fret)")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .position(
                            x: width - 10,
                            y: fretSpacing * CGFloat(fret)
                        )
                }
                
                // Strings (vertical) — low E on left, high E on right
                ForEach(0..<Self.guitarStringTunings.count, id: \.self) { stringIdx in
                    let xPos = stringSpacing * CGFloat(stringIdx + 1)
                    let thickness = max(1.2, 3.5 - CGFloat(stringIdx) * 0.4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.85), Color(white: 0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: thickness, height: height)
                        .position(x: xPos, y: height / 2)
                }
                
                // String names at top (above nut)
                ForEach(0..<Self.guitarStringTunings.count, id: \.self) { stringIdx in
                    let xPos = stringSpacing * CGFloat(stringIdx + 1)
                    Text(Self.guitarStringTunings[stringIdx].name)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .position(x: xPos, y: fretSpacing * 0.18)
                }
                
                // Scale note markers
                ForEach(0..<Self.guitarStringTunings.count, id: \.self) { stringIdx in
                    let openSemitone = Self.guitarStringTunings[stringIdx].semitone
                    let xPos = stringSpacing * CGFloat(stringIdx + 1)
                    
                    ForEach(0...Self.fretCount, id: \.self) { fret in
                        let noteSemitone = (openSemitone + fret) % 12
                        let rootSemitone = ScaleGenerator.rootNotes[rootNoteIndex].semitones
                        let interval = (noteSemitone - rootSemitone + 12) % 12
                        
                        if selectedScale.intervals.contains(interval) {
                            let isRoot = interval == 0
                            let yPos = fret == 0
                                ? fretSpacing * 0.28
                                : fretSpacing * CGFloat(fret) + fretSpacing * 0.25
                            let noteFrequency = ScaleGenerator.c4Frequency * pow(2.0, Double(openSemitone + fret - 48) / 12.0)
                            let markerSize = min(stringSpacing * 0.65, fretSpacing * 0.45)
                            let markerID = UUID()
                            
                            Button {
                                activeKeyID = markerID
                                hapticTrigger += 1
                                toneGenerator.playNote(frequency: noteFrequency)
                                Task {
                                    try? await Task.sleep(for: .milliseconds(500))
                                    await MainActor.run {
                                        if activeKeyID == markerID {
                                            toneGenerator.stopNote()
                                            activeKeyID = nil
                                        }
                                    }
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(isRoot ? color : color.opacity(0.85))
                                        .frame(width: markerSize, height: markerSize)
                                        .shadow(color: color.opacity(0.4), radius: 3, y: 1)
                                    
                                    Text(ScaleNote.chromaticNames[noteSemitone])
                                        .font(.system(size: max(markerSize * 0.4, 8), weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .minimumScaleFactor(0.5)
                                }
                            }
                            .buttonStyle(.plain)
                            .position(x: xPos, y: yPos)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Piano Keyboard
    
    private var pianoKeyboard: some View {
        let whiteKeys = chromaticKeys.filter { !$0.isBlack }
        let blackKeys = chromaticKeys.filter { $0.isBlack }
        let whiteCount = CGFloat(whiteKeys.count)
        
        return GeometryReader { geo in
            let totalWidth = geo.size.width
            let height = geo.size.height
            let whiteKeySpacing: CGFloat = 3
            let whiteKeyWidth = (totalWidth - whiteKeySpacing * (whiteCount - 1)) / whiteCount
            let blackKeyWidth = whiteKeyWidth * 0.58
            let blackKeyHeight = height * 0.58
            
            ZStack(alignment: .topLeading) {
                // Invisible hit-test surface
                Color.clear
                    .contentShape(Rectangle())
                
                // White keys layer
                HStack(spacing: whiteKeySpacing) {
                    ForEach(whiteKeys) { key in
                        WhiteKeyView(
                            key: key,
                            accentColor: color,
                            isActive: activeKeyID == key.id
                        )
                    }
                }
                .allowsHitTesting(false)
                
                // Black keys layer (overlaid)
                ForEach(blackKeys) { key in
                    let posIndex = blackKeyPositionIndex(semitone: key.semitone)
                    let xOffset = (whiteKeyWidth + whiteKeySpacing) * CGFloat(posIndex) + whiteKeyWidth - blackKeyWidth / 2
                    
                    BlackKeyView(
                        key: key,
                        accentColor: color,
                        isActive: activeKeyID == key.id,
                        width: blackKeyWidth,
                        height: blackKeyHeight
                    )
                    .offset(x: xOffset)
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = value.location
                        // Hit-test black keys first (they're on top)
                        if let hitKey = hitTestBlackKey(
                            at: location,
                            blackKeys: blackKeys,
                            whiteKeyWidth: whiteKeyWidth,
                            whiteKeySpacing: whiteKeySpacing,
                            blackKeyWidth: blackKeyWidth,
                            blackKeyHeight: blackKeyHeight
                        ) {
                            if activeKeyID != hitKey.id {
                                keyPressed(hitKey)
                            }
                        } else if let hitKey = hitTestWhiteKey(
                            at: location,
                            whiteKeys: whiteKeys,
                            whiteKeyWidth: whiteKeyWidth,
                            whiteKeySpacing: whiteKeySpacing,
                            totalHeight: height
                        ) {
                            if activeKeyID != hitKey.id {
                                keyPressed(hitKey)
                            }
                        } else {
                            if activeKeyID != nil {
                                keyReleased()
                            }
                        }
                    }
                    .onEnded { _ in
                        keyReleased()
                    }
            )
        }
        .padding(.horizontal, 12)
        .onDisappear {
            keyReleased()
        }
    }
    
    /// Hit-test black keys at a touch point.
    private func hitTestBlackKey(
        at point: CGPoint,
        blackKeys: [ChromaticKey],
        whiteKeyWidth: CGFloat,
        whiteKeySpacing: CGFloat,
        blackKeyWidth: CGFloat,
        blackKeyHeight: CGFloat
    ) -> ChromaticKey? {
        for key in blackKeys {
            let posIndex = blackKeyPositionIndex(semitone: key.semitone)
            let xOffset = (whiteKeyWidth + whiteKeySpacing) * CGFloat(posIndex) + whiteKeyWidth - blackKeyWidth / 2
            let keyRect = CGRect(x: xOffset, y: 0, width: blackKeyWidth, height: blackKeyHeight)
            if keyRect.contains(point) {
                return key
            }
        }
        return nil
    }
    
    /// Hit-test white keys at a touch point.
    private func hitTestWhiteKey(
        at point: CGPoint,
        whiteKeys: [ChromaticKey],
        whiteKeyWidth: CGFloat,
        whiteKeySpacing: CGFloat,
        totalHeight: CGFloat
    ) -> ChromaticKey? {
        for (index, key) in whiteKeys.enumerated() {
            let xOffset = (whiteKeyWidth + whiteKeySpacing) * CGFloat(index)
            let keyRect = CGRect(x: xOffset, y: 0, width: whiteKeyWidth, height: totalHeight)
            if keyRect.contains(point) {
                return key
            }
        }
        return nil
    }
    
    /// Maps a black-key semitone to the white key index it sits after.
    private func blackKeyPositionIndex(semitone: Int) -> Int {
        // Semitones: 0  1  2  3  4  5  6  7  8  9  10 11 12
        // White idx:  0     1     2  3     4     5      6  7
        // Black 1 -> after white 0, Black 3 -> after white 1,
        // Black 6 -> after white 3, Black 8 -> after white 4, Black 10 -> after white 5
        switch semitone {
        case 1: return 0
        case 3: return 1
        case 6: return 3
        case 8: return 4
        case 10: return 5
        default: return 0
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(spacing: 16) {
            Button {
                autoPlayScale()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isAutoPlaying ? "waveform" : "play.fill")
                        .symbolEffect(.variableColor.iterative, isActive: isAutoPlaying)
                    Text(isAutoPlaying ? "Playing..." : "Play Scale")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .foregroundStyle(color)
            .disabled(isAutoPlaying)
            
            Text(intervalSummary)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 24)
    }
    
    private var intervalSummary: String {
        scaleNotes.map { $0.noteName.components(separatedBy: " ").first ?? "" }
            .joined(separator: " · ")
    }
    
    // MARK: - Actions
    
    private func keyPressed(_ key: ChromaticKey) {
        activeKeyID = key.id
        hapticTrigger += 1
        toneGenerator.playNote(frequency: key.frequency)
    }
    
    private func keyReleased() {
        activeKeyID = nil
        toneGenerator.stopNote()
    }
    
    private func autoPlayScale() {
        guard !isAutoPlaying else { return }
        isAutoPlaying = true
        
        // Find the chromatic keys that correspond to scale notes
        let scaleKeys = chromaticKeys.filter { $0.scaleNote != nil }
        
        Task {
            for key in scaleKeys {
                await MainActor.run {
                    activeKeyID = key.id
                    hapticTrigger += 1
                    toneGenerator.playNote(frequency: key.frequency)
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
            try? await Task.sleep(for: .milliseconds(100))
            for key in scaleKeys.reversed().dropFirst() {
                await MainActor.run {
                    activeKeyID = key.id
                    hapticTrigger += 1
                    toneGenerator.playNote(frequency: key.frequency)
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
            await MainActor.run {
                toneGenerator.stopNote()
                activeKeyID = nil
                isAutoPlaying = false
            }
        }
    }
}

// MARK: - White Key View

struct WhiteKeyView: View {
    let key: ChromaticKey
    let accentColor: Color
    let isActive: Bool
    
    private var isInScale: Bool { key.scaleNote != nil }
    
    private var solfege: String {
        guard let sn = key.scaleNote else { return "" }
        if let s = sn.noteName.components(separatedBy: "(").last?
            .replacingOccurrences(of: ")", with: "") {
            return s
        }
        return ""
    }
    
    private var keyShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 6,
                bottomLeading: 10,
                bottomTrailing: 10,
                topTrailing: 6
            )
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Glow layer behind the key
            if isActive {
                keyShape
                    .fill(accentColor)
                    .blur(radius: 18)
                    .opacity(0.6)
                    .scaleEffect(CGSize(width: 1.1, height: 1.05))
            }
            
            // Key background
            keyShape
                .fill(whiteKeyFill)
                .overlay(
                    keyShape
                        .strokeBorder(
                            isActive ? accentColor : isInScale ? accentColor.opacity(0.25) : Color(.systemGray4),
                            lineWidth: isActive ? 2.5 : 1
                        )
                )
                .shadow(color: .black.opacity(0.08), radius: 2, y: 2)
            
            // Bottom label area
            VStack(spacing: 3) {
                if isInScale {
                    Text(solfege)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(isActive ? .white : accentColor.opacity(0.7))
                }
                
                Text(key.noteName)
                    .font(.system(size: 14, weight: isInScale ? .bold : .regular, design: .rounded))
                    .foregroundStyle(
                        isActive ? .white :
                            isInScale ? accentColor : Color(.systemGray3)
                    )
                
                if isInScale {
                    Circle()
                        .fill(isActive ? Color.white : accentColor)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(isActive ? CGSize(width: 0.95, height: 0.97) : CGSize(width: 1, height: 1), anchor: .top)
        .zIndex(isActive ? 1 : 0)
        .animation(.spring(duration: 0.15, bounce: 0.3), value: isActive)
    }
    
    private var whiteKeyFill: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(accentColor.gradient)
        }
        if isInScale {
            return AnyShapeStyle(accentColor.opacity(0.07).gradient)
        }
        return AnyShapeStyle(Color.white.gradient)
    }
}

// MARK: - Black Key View

struct BlackKeyView: View {
    let key: ChromaticKey
    let accentColor: Color
    let isActive: Bool
    let width: CGFloat
    let height: CGFloat
    
    private var isInScale: Bool { key.scaleNote != nil }
    
    private var keyShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: 4,
                bottomLeading: 7,
                bottomTrailing: 7,
                topTrailing: 4
            )
        )
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Glow layer behind the key
            if isActive {
                keyShape
                    .fill(accentColor)
                    .blur(radius: 14)
                    .opacity(0.7)
                    .scaleEffect(CGSize(width: 1.15, height: 1.08))
            }
            
            keyShape
                .fill(blackKeyFill)
                .overlay(
                    keyShape
                        .strokeBorder(
                            isActive ? accentColor : isInScale ? accentColor.opacity(0.25) : .clear,
                            lineWidth: isActive ? 2 : isInScale ? 1 : 0
                        )
                )
                .shadow(color: .black.opacity(0.35), radius: 3, y: 3)
            
            // Scale indicator
            if isInScale {
                VStack(spacing: 2) {
                    Text(key.noteName)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? .white : accentColor)
                    Circle()
                        .fill(isActive ? Color.white : accentColor)
                        .frame(width: 5, height: 5)
                }
                .padding(.bottom, 8)
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(isActive ? CGSize(width: 0.93, height: 0.97) : CGSize(width: 1, height: 1), anchor: .top)
        .zIndex(isActive ? 1 : 0)
        .animation(.spring(duration: 0.15, bounce: 0.3), value: isActive)
    }
    
    private var blackKeyFill: some ShapeStyle {
        if isActive {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [accentColor, accentColor.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        if isInScale {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [accentColor.opacity(0.45), accentColor.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [Color(.systemGray5), .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

#Preview {
    PlayerView(toneGenerator: ToneGenerator())
}
