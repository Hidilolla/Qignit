import SwiftUI

/// Interactive pentatonic keyboard for playing Ethiopian scale notes.
struct PlayerView: View {
    @State private var selectedScale: EthiopianScale = .tizita
    @State private var rootNoteIndex: Int = 0
    @State private var activeNoteID: UUID?
    @Bindable var toneGenerator: ToneGenerator
    
    private var notes: [ScaleNote] {
        ScaleGenerator.generateNotes(
            scale: selectedScale,
            rootSemitone: ScaleGenerator.rootNotes[rootNoteIndex].semitones
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scaleSelector
                rootSelector
                keyboardSection
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Play")
        }
    }
    
    // MARK: - Scale Selector
    
    private var scaleSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(EthiopianScale.allCases) { scale in
                    ScaleChip(
                        scale: scale,
                        isSelected: selectedScale == scale
                    ) {
                        withAnimation(.snappy(duration: 0.3)) {
                            selectedScale = scale
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Root Note Selector
    
    private var rootSelector: some View {
        VStack(spacing: 8) {
            Text("Root Note")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Picker("Root Note", selection: $rootNoteIndex) {
                ForEach(0..<ScaleGenerator.rootNotes.count, id: \.self) { index in
                    Text(ScaleGenerator.rootNotes[index].name)
                        .tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Keyboard
    
    private var keyboardSection: some View {
        VStack(spacing: 16) {
            // Scale name header
            VStack(spacing: 4) {
                Text(selectedScale.amharicName)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text(selectedScale.rawValue)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            // Note keys
            GeometryReader { geometry in
                let columns = min(notes.count, 5)
                let rows = (notes.count + columns - 1) / columns
                let spacing: CGFloat = 12
                let padH: CGFloat = 20
                let availableWidth = geometry.size.width - padH * 2
                let keyWidth = (availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
                let availableHeight = geometry.size.height - 20
                let keyHeight = (availableHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
                
                VStack(spacing: spacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<columns, id: \.self) { col in
                                let index = row * columns + col
                                if index < notes.count {
                                    NoteKey(
                                        note: notes[index],
                                        scale: selectedScale,
                                        isActive: activeNoteID == notes[index].id
                                    ) {
                                        notePressed(notes[index])
                                    } onRelease: {
                                        noteReleased()
                                    }
                                    .frame(width: keyWidth, height: keyHeight)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, padH)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Actions
    
    private func notePressed(_ note: ScaleNote) {
        activeNoteID = note.id
        toneGenerator.playNote(frequency: note.frequency)
    }
    
    private func noteReleased() {
        activeNoteID = nil
        toneGenerator.stopNote()
    }
}

// MARK: - Scale Chip

struct ScaleChip: View {
    let scale: EthiopianScale
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: scale.iconName)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 1) {
                    Text(scale.rawValue)
                        .font(.subheadline.weight(.semibold))
                    Text(scale.amharicName)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? chipColor.opacity(0.15) : Color(.tertiarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? chipColor : .clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? chipColor : .primary)
        }
        .buttonStyle(.plain)
    }
    
    private var chipColor: Color {
        switch scale.themeColorName {
        case "indigo": return .indigo
        case "red": return .red
        case "teal": return .teal
        case "orange": return .orange
        default: return .accentColor
        }
    }
}

// MARK: - Note Key

struct NoteKey: View {
    let note: ScaleNote
    let scale: EthiopianScale
    let isActive: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    
    var body: some View {
        let color = keyColor
        
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isActive
                    ? color.gradient
                    : color.opacity(0.12).gradient
                )
                .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: 8, y: 4)
            
            VStack(spacing: 4) {
                Text(note.noteName.components(separatedBy: " ").first ?? "")
                    .font(.title2.weight(.bold).monospaced())
                    .foregroundStyle(isActive ? .white : color)
                
                if let solfege = note.noteName.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "") {
                    Text(solfege)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary)
                }
            }
        }
        .scaleEffect(isActive ? 0.95 : 1.0)
        .animation(.spring(duration: 0.2), value: isActive)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isActive {
                        onPress()
                    }
                }
                .onEnded { _ in
                    onRelease()
                }
        )
    }
    
    private var keyColor: Color {
        switch scale.themeColorName {
        case "indigo": return .indigo
        case "red": return .red
        case "teal": return .teal
        case "orange": return .orange
        default: return .accentColor
        }
    }
}

#Preview {
    PlayerView(toneGenerator: ToneGenerator())
}
