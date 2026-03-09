import SwiftUI

/// Ear training quiz that plays a scale and asks the user to identify it.
struct QuizView: View {
    @Bindable var toneGenerator: ToneGenerator
    
    @State private var currentQuiz: QuizQuestion?
    @State private var selectedAnswer: EthiopianScale?
    @State private var showResult = false
    @State private var score = 0
    @State private var totalQuestions = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var isPlayingScale = false
    @State private var pulsePlay = false
    @State private var resultEmoji = ""
    
    private var accuracy: Int {
        guard totalQuestions > 0 else { return 0 }
        return Int(round(Double(score) / Double(totalQuestions) * 100))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        statsRow
                        
                        if let quiz = currentQuiz {
                            quizContent(quiz)
                        } else {
                            startPrompt
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                // Fixed bottom area
                if showResult, let quiz = currentQuiz {
                    VStack(spacing: 10) {
                        resultFeedback(quiz)
                        
                        Button {
                            withAnimation(.snappy) {
                                generateQuestion()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Next Question")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .background(Color(red: 0.94, green: 0.98, blue: 0.95))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(Color(red: 0.94, green: 0.98, blue: 0.95))
            .navigationTitle("Practice")
        }
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            StatPill(icon: "checkmark.circle.fill", value: "\(score)/\(totalQuestions)", label: "Score", color: .green)
            StatPill(icon: "flame.fill", value: "\(streak)", label: "Streak", color: .orange)
            StatPill(icon: "trophy.fill", value: "\(bestStreak)", label: "Best", color: .yellow)
            StatPill(icon: "percent", value: "\(accuracy)%", label: "Accuracy", color: .blue)
        }
    }
    
    // MARK: - Start Prompt
    
    private var startPrompt: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 40)
            
            // Animated ear icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 130, height: 130)
                
                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 170, height: 170)
                
                Image(systemName: "ear.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse, isActive: true)
            }
            
            VStack(spacing: 10) {
                Text("Ear Training")
                    .font(.title.weight(.bold))
                
                Text("Listen to a pentatonic scale and identify\nwhich Ethiopian Kiñit it belongs to.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // How it works
            VStack(alignment: .leading, spacing: 12) {
                Label("How It Works", systemImage: "questionmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                HowItWorksStep(number: "1", text: "Tap the play button to hear a scale")
                HowItWorksStep(number: "2", text: "Choose which Kiñit you think it is")
                HowItWorksStep(number: "3", text: "Build your streak and sharpen your ear")
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            
            Button {
                withAnimation(.snappy) {
                    generateQuestion()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Practice")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            
            Spacer().frame(height: 20)
        }
    }
    
    // MARK: - Quiz Content
    
    @ViewBuilder
    private func quizContent(_ quiz: QuizQuestion) -> some View {
        VStack(spacing: 20) {
            // Question header
            HStack {
                Text("Question \(totalQuestions + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if showResult {
                    Text(resultEmoji)
                        .font(.title2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Play card
            Button {
                playQuizScale(quiz)
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(pulsePlay ? 0.2 : 0.1))
                            .frame(width: 64, height: 64)
                            .scaleEffect(pulsePlay ? 1.2 : 1.0)
                        
                        Image(systemName: isPlayingScale ? "speaker.wave.3.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .symbolEffect(.variableColor.iterative, isActive: isPlayingScale)
                    }
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulsePlay)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isPlayingScale ? "Playing..." : "Tap to Listen")
                            .font(.headline)
                        Text(isPlayingScale ? "Listen carefully to the notes" : "Play the mystery scale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(isPlayingScale)
            
            // Answer options
            VStack(spacing: 10) {
                Text("Which Kiñit is this?")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(quiz.options) { scale in
                        AnswerCard(
                            scale: scale,
                            state: answerState(for: scale, in: quiz)
                        ) {
                            submitAnswer(scale, for: quiz)
                        }
                        .disabled(showResult)
                    }
                }
            }
            
        }
    }
    
    // MARK: - Result Feedback
    
    @ViewBuilder
    private func resultFeedback(_ quiz: QuizQuestion) -> some View {
        let isCorrect = selectedAnswer == quiz.correctAnswer
        
        HStack(spacing: 12) {
            Image(systemName: isCorrect ? "checkmark.seal.fill" : "info.circle.fill")
                .font(.title2)
                .foregroundStyle(isCorrect ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isCorrect ? "Correct!" : "Not quite")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCorrect ? .green : .orange)
                
                if !isCorrect {
                    Text("The answer was **\(quiz.correctAnswer.rawValue)** (\(quiz.correctAnswer.amharicName))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            (isCorrect ? Color.green : Color.orange).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder((isCorrect ? Color.green : Color.orange).opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Answer State
    
    private func answerState(for scale: EthiopianScale, in quiz: QuizQuestion) -> AnswerCard.AnswerState {
        guard showResult else {
            return selectedAnswer == scale ? .selected : .idle
        }
        if scale == quiz.correctAnswer { return .correct }
        if scale == selectedAnswer && scale != quiz.correctAnswer { return .incorrect }
        return .idle
    }
    
    // MARK: - Actions
    
    private func generateQuestion() {
        let correct = EthiopianScale.allCases.randomElement()!
        let options = EthiopianScale.allCases.shuffled()
        
        currentQuiz = QuizQuestion(correctAnswer: correct, options: options)
        selectedAnswer = nil
        showResult = false
        resultEmoji = ""
        pulsePlay = false
    }
    
    private func playQuizScale(_ quiz: QuizQuestion) {
        let notes = ScaleGenerator.generateNotes(scale: quiz.correctAnswer, octaveRange: 0...0)
        isPlayingScale = true
        pulsePlay = true
        
        Task {
            for note in notes {
                await MainActor.run {
                    toneGenerator.playNote(frequency: note.frequency)
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
            for note in notes.reversed().dropFirst() {
                await MainActor.run {
                    toneGenerator.playNote(frequency: note.frequency)
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
            await MainActor.run {
                toneGenerator.stopNote()
                isPlayingScale = false
                pulsePlay = false
            }
        }
    }
    
    private func submitAnswer(_ answer: EthiopianScale, for quiz: QuizQuestion) {
        selectedAnswer = answer
        
        withAnimation(.snappy(duration: 0.3)) {
            showResult = true
            totalQuestions += 1
            
            if answer == quiz.correctAnswer {
                score += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
                resultEmoji = ["🎉", "✨", "🎵", "👏"].randomElement()!
            } else {
                streak = 0
                resultEmoji = "🤔"
            }
        }
    }
}

// MARK: - Quiz Question Model

struct QuizQuestion {
    let correctAnswer: EthiopianScale
    let options: [EthiopianScale]
}

// MARK: - How It Works Step

struct HowItWorksStep: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }
}

// MARK: - Answer Card (Grid)

struct AnswerCard: View {
    let scale: EthiopianScale
    let state: AnswerState
    let action: () -> Void
    
    enum AnswerState {
        case idle, selected, correct, incorrect
    }
    
    private var scaleColor: Color {
        switch scale.themeColorName {
        case "indigo": return .indigo
        case "red": return .red
        case "teal": return .teal
        case "orange": return .orange
        default: return .accentColor
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: scale.iconName)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconBackgroundColor, in: Circle())
                
                Text(scale.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(scale.amharicName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Result indicator
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.scale)
                } else if state == .incorrect {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.scale)
                } else {
                    Color.clear.frame(height: 16)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .shadow(color: shadowColor, radius: state == .selected ? 6 : 3, y: 1)
        }
        .buttonStyle(.plain)
        .scaleEffect(state == .selected ? 1.03 : 1.0)
        .animation(.spring(duration: 0.25), value: state)
    }
    
    private var iconColor: Color {
        switch state {
        case .correct: return .green
        case .incorrect: return .red
        default: return scaleColor
        }
    }
    
    private var iconBackgroundColor: Color {
        switch state {
        case .correct: return .green.opacity(0.12)
        case .incorrect: return .red.opacity(0.12)
        default: return scaleColor.opacity(0.1)
        }
    }
    
    private var backgroundColor: Color {
        switch state {
        case .idle: return Color(.systemBackground)
        case .selected: return Color.accentColor.opacity(0.06)
        case .correct: return Color.green.opacity(0.06)
        case .incorrect: return Color.red.opacity(0.06)
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .idle: return .clear
        case .selected: return .accentColor.opacity(0.5)
        case .correct: return .green.opacity(0.5)
        case .incorrect: return .red.opacity(0.5)
        }
    }
    
    private var borderWidth: CGFloat {
        state == .idle ? 0 : 2
    }
    
    private var shadowColor: Color {
        switch state {
        case .selected: return .accentColor.opacity(0.12)
        case .correct: return .green.opacity(0.12)
        case .incorrect: return .red.opacity(0.12)
        default: return .black.opacity(0.04)
        }
    }
}

#Preview {
    QuizView(toneGenerator: ToneGenerator())
}
