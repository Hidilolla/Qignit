import Foundation

/// Represents the four main Ethiopian pentatonic scale modes (Kiñit).
/// Each mode defines a unique set of intervals that produce distinct emotional qualities.
enum EthiopianScale: String, CaseIterable, Identifiable, Codable {
    case tizita = "Tizita"
    case bati = "Bati"
    case ambassel = "Ambassel"
    case anchihoye = "Anchihoye"
    
    var id: String { rawValue }
    
    /// Amharic name of the scale.
    var amharicName: String {
        switch self {
        case .tizita: return "ትዝታ"
        case .bati: return "ባቲ"
        case .ambassel: return "አምባሰል"
        case .anchihoye: return "አንቺሆየ"
        }
    }
    
    /// Brief description of the mood and usage.
    var description: String {
        switch self {
        case .tizita:
            return "Nostalgia and longing. The most widely known Ethiopian scale, evoking memories and deep emotion. Often used in love songs and reflective melodies."
        case .bati:
            return "Strength and pride. A bold, passionate scale commonly heard in warrior songs, celebrations, and energetic performances."
        case .ambassel:
            return "Spiritual devotion. A contemplative, meditative scale rooted in the music of the Ethiopian Orthodox Church and northern highlands."
        case .anchihoye:
            return "Joy and playfulness. A bright, lively scale used in festive music, dances, and celebratory occasions."
        }
    }
    
    /// Intervals in semitones from the root for each pentatonic mode.
    var intervals: [Int] {
        switch self {
        case .tizita:    return [0, 2, 4, 7, 9]      // C D E G A
        case .bati:      return [0, 3, 5, 7, 10]     // C Eb F G Bb
        case .ambassel:  return [0, 1, 5, 7, 8]      // C Db F G Ab
        case .anchihoye: return [0, 2, 5, 7, 10]     // C D F G Bb
        }
    }
    
    /// SF Symbol icon representing the mood.
    var iconName: String {
        switch self {
        case .tizita: return "heart.fill"
        case .bati: return "flame.fill"
        case .ambassel: return "sparkles"
        case .anchihoye: return "star.fill"
        }
    }
    
    /// Theme color for each scale.
    var themeColorName: String {
        switch self {
        case .tizita: return "indigo"
        case .bati: return "red"
        case .ambassel: return "teal"
        case .anchihoye: return "orange"
        }
    }
}

/// A single note within a scale with its computed frequency.
struct ScaleNote: Identifiable {
    let id = UUID()
    let degree: Int          // 1-based scale degree
    let noteName: String
    let frequency: Double
    let interval: Int        // semitones from root
    
    /// Note names for chromatic scale starting from C.
    static let chromaticNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    
    /// Ethiopian solfege names for scale degrees.
    static let solfegeNames = ["Do", "Re", "Mi", "Sol", "La"]
}

/// Generates the notes for a given scale and root note.
struct ScaleGenerator {
    
    /// Base frequency for C4 (middle C).
    static let c4Frequency: Double = 261.63
    
    /// All available root notes.
    static let rootNotes: [(name: String, semitones: Int)] = [
        ("C", 0), ("C♯", 1), ("D", 2), ("D♯", 3),
        ("E", 4), ("F", 5), ("F♯", 6), ("G", 7),
        ("G♯", 8), ("A", 9), ("A♯", 10), ("B", 11)
    ]
    
    /// Generate notes across multiple octaves for a given scale and root.
    static func generateNotes(
        scale: EthiopianScale,
        rootSemitone: Int = 0,
        octaveRange: ClosedRange<Int> = 0...1
    ) -> [ScaleNote] {
        var notes: [ScaleNote] = []
        var degree = 1
        
        for octave in octaveRange {
            for (index, interval) in scale.intervals.enumerated() {
                let totalSemitones = rootSemitone + interval + (octave * 12)
                let frequency = c4Frequency * pow(2.0, Double(totalSemitones) / 12.0)
                let noteIndex = (rootSemitone + interval) % 12
                let noteName = ScaleNote.chromaticNames[noteIndex]
                let solfege = ScaleNote.solfegeNames[index]
                
                notes.append(ScaleNote(
                    degree: degree,
                    noteName: "\(noteName) (\(solfege))",
                    frequency: frequency,
                    interval: interval
                ))
                degree += 1
            }
        }
        
        return notes
    }
}
