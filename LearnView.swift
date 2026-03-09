import SwiftUI

/// Educational view explaining Ethiopian pentatonic scales and their cultural significance.
struct LearnView: View {
    @Bindable var toneGenerator: ToneGenerator
    @State private var expandedScale: EthiopianScale?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    scaleCards
                    aboutSection
                }
                .padding()
            }
            .background(Color(red: 0.94, green: 0.98, blue: 0.95))
            .navigationTitle("Learn")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, isActive: true)
            
            Text("Ethiopian Kiñit")
                .font(.largeTitle.weight(.bold))
            
            Text("The four pentatonic modes of Ethiopian music")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Scale Cards
    
    private var scaleCards: some View {
        VStack(spacing: 16) {
            ForEach(EthiopianScale.allCases) { scale in
                ScaleCard(
                    scale: scale,
                    isExpanded: expandedScale == scale,
                    toneGenerator: toneGenerator
                ) {
                    withAnimation(.snappy(duration: 0.35)) {
                        expandedScale = expandedScale == scale ? nil : scale
                    }
                }
            }
        }
    }
    
    // MARK: - About
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("About Ethiopian Music", systemImage: "info.circle.fill")
                .font(.headline)
            
            Text("Ethiopian music is built on a pentatonic (five-note) scale system called Kiñit (ቅኝት). Unlike Western music's seven-note scales, these five-note modes create the distinctive sound that defines Ethiopian musical identity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Each mode carries a specific emotional character and is associated with particular types of songs, ceremonies, and regions. Musicians learn to navigate between these modes to express different emotions within a single performance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Scale Card

struct ScaleCard: View {
    let scale: EthiopianScale
    let isExpanded: Bool
    let toneGenerator: ToneGenerator
    let onTap: () -> Void
    
    @State private var playingNoteIndex: Int?
    
    private var notes: [ScaleNote] {
        ScaleGenerator.generateNotes(scale: scale, octaveRange: 0...0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack(spacing: 14) {
                    Image(systemName: scale.iconName)
                        .font(.title2)
                        .foregroundStyle(cardColor)
                        .frame(width: 44, height: 44)
                        .background(cardColor.opacity(0.12), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(scale.rawValue)
                                .font(.title3.weight(.semibold))
                            Text(scale.amharicName)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(intervalLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal)
                    
                    Text(scale.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    // Interactive note buttons
                    HStack(spacing: 8) {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                            InteractiveNoteButton(
                                note: note,
                                color: cardColor,
                                isPlaying: playingNoteIndex == index
                            ) {
                                playNote(at: index)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Play all button
                    Button {
                        playScale()
                    } label: {
                        Label("Play Scale", systemImage: "play.fill")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(cardColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(cardColor)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    private var intervalLabel: String {
        notes.map { $0.noteName.components(separatedBy: " ").first ?? "" }.joined(separator: " - ")
    }
    
    private var cardColor: Color {
        switch scale.themeColorName {
        case "indigo": return .indigo
        case "red": return .red
        case "teal": return .teal
        case "orange": return .orange
        default: return .accentColor
        }
    }
    
    private func playNote(at index: Int) {
        guard index < notes.count else { return }
        playingNoteIndex = index
        toneGenerator.playNote(frequency: notes[index].frequency)
        
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                toneGenerator.stopNote()
                playingNoteIndex = nil
            }
        }
    }
    
    private func playScale() {
        Task {
            for (index, note) in notes.enumerated() {
                await MainActor.run {
                    playingNoteIndex = index
                    toneGenerator.playNote(frequency: note.frequency)
                }
                try? await Task.sleep(for: .milliseconds(450))
            }
            await MainActor.run {
                toneGenerator.stopNote()
                playingNoteIndex = nil
            }
        }
    }
}

// MARK: - Interactive Note Button

struct InteractiveNoteButton: View {
    let note: ScaleNote
    let color: Color
    let isPlaying: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(note.noteName.components(separatedBy: " ").first ?? "")
                    .font(.caption.weight(.bold).monospaced())
                Text("\(note.degree)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isPlaying ? color : color.opacity(0.08))
            )
            .foregroundStyle(isPlaying ? .white : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPlaying ? 1.1 : 1.0)
        .animation(.spring(duration: 0.2), value: isPlaying)
    }
}

#Preview {
    LearnView(toneGenerator: ToneGenerator())
}
