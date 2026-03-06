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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                statsBar
                
                Spacer()
                
                if let quiz = currentQuiz {
                    quizContent(quiz)
                } else {
                    startPrompt
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Practice")
        }
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 20) {
            StatBadge(label: "Score", value: "\(score)/\(totalQuestions)", icon: "checkmark.circle.fill", color: .green)
            StatBadge(label: "Streak", value: "\(streak)", icon: "flame.fill", color: .orange)
            StatBadge(label: "Best", value: "\(bestStreak)", icon: "trophy.fill", color: .yellow)
        }
    }
    
    // MARK: - Start Prompt
    
    private var startPrompt: some View {
        VStack(spacing: 20) {
            Image(systemName: "ear.fill")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            
            Text("Ear Training")
                .font(.title.weight(.bold))
            
            Text("Listen to a pentatonic scale and identify which Ethiopian mode it belongs to.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                generateQuestion()
            } label: {
                Label("Start Quiz", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.accent.gradient, in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Quiz Content
    
    @ViewBuilder
    private func quizContent(_ quiz: QuizQuestion) -> some View {
        VStack(spacing: 28) {
            // Question number
            Text("Question \(totalQuestions + 1)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Play button
            Button {
                playQuizScale(quiz)
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: isPlayingScale ? "speaker.wave.3.fill" : "play.circle.fill")
                        .font(.system(size: 72))
                        .symbolEffect(.variableColor.iterative, isActive: isPlayingScale)
                    
                    Text(isPlayingScale ? "Listening..." : "Tap to Listen")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .foregroundStyle(.accent)
            .disabled(isPlayingScale)
            
            // Answer options
            VStack(spacing: 12) {
                Text("Which scale is this?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ForEach(quiz.options) { scale in
                    AnswerButton(
                        scale: scale,
                        state: answerState(for: scale, in: quiz)
                    ) {
                        submitAnswer(scale, for: quiz)
                    }
                    .disabled(showResult)
                }
            }
            
            // Next button
            if showResult {
                Button {
                    generateQuestion()
                } label: {
                    Label("Next Question", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.accent.gradient, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Answer State
    
    private func answerState(for scale: EthiopianScale, in quiz: QuizQuestion) -> AnswerButton.AnswerState {
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
        var options = EthiopianScale.allCases.shuffled()
        // Ensure correct answer is in options (it always will be since we use allCases)
        if !options.contains(correct) {
            options[0] = correct
        }
        
        currentQuiz = QuizQuestion(correctAnswer: correct, options: options)
        selectedAnswer = nil
        showResult = false
    }
    
    private func playQuizScale(_ quiz: QuizQuestion) {
        let notes = ScaleGenerator.generateNotes(scale: quiz.correctAnswer, octaveRange: 0...0)
        isPlayingScale = true
        
        Task {
            for note in notes {
                await MainActor.run {
                    toneGenerator.playNote(frequency: note.frequency)
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
            // Play descending too for better recognition
            for note in notes.reversed().dropFirst() {
                await MainActor.run {
                    toneGenerator.playNote(frequency: note.frequency)
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
            await MainActor.run {
                toneGenerator.stopNote()
                isPlayingScale = false
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
            } else {
                streak = 0
            }
        }
    }
}

// MARK: - Quiz Question Model

struct QuizQuestion {
    let correctAnswer: EthiopianScale
    let options: [EthiopianScale]
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Answer Button

struct AnswerButton: View {
    let scale: EthiopianScale
    let state: AnswerState
    let action: () -> Void
    
    enum AnswerState {
        case idle, selected, correct, incorrect
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: scale.iconName)
                    .font(.title3)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(scale.rawValue)
                        .font(.body.weight(.semibold))
                    Text(scale.amharicName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else if state == .incorrect {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor, lineWidth: state == .idle ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch state {
        case .idle: return Color(.secondarySystemGroupedBackground)
        case .selected: return Color.accentColor.opacity(0.1)
        case .correct: return Color.green.opacity(0.1)
        case .incorrect: return Color.red.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .idle: return .clear
        case .selected: return .accentColor
        case .correct: return .green
        case .incorrect: return .red
        }
    }
}

#Preview {
    QuizView(toneGenerator: ToneGenerator())
}
