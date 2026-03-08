# Kiñit Identifier Feature - Implementation Plan

## Overview
Add a new "Identify" tab that listens to live music via the device microphone and guesses which Ethiopian pentatonic scale (Kiñit) is being played.

## New Files

### 1. `AudioAnalyzer.swift` - Pitch Detection Engine
- `@Observable` class with its own `AVAudioEngine` (separate from ToneGenerator)
- Uses `AVAudioEngine.inputNode` to tap the microphone
- FFT via Apple's **Accelerate** framework (`vDSP`) for real-time pitch detection
- Algorithm:
  1. Install a tap on the input node (buffer size 4096 at 44.1kHz)
  2. Apply Hanning window to the audio buffer
  3. Run FFT to get frequency spectrum
  4. Find peak frequency (fundamental pitch) using parabolic interpolation
  5. Convert frequency to chromatic semitone (mod 12)
  6. Accumulate detected semitones into a histogram over a rolling window (~3 seconds)
  7. Score each scale: compare the histogram of detected notes against each scale's interval set (trying all 12 possible roots)
  8. Report best match with confidence percentage
- Published properties: `isListening`, `detectedScale`, `confidence`, `detectedNotes` (set of active semitones), `dominantFrequency`
- Methods: `startListening()`, `stopListening()`, `reset()`

### 2. `IdentifyView.swift` - UI
- Microphone permission handling with clear prompts
- Large animated listening indicator (pulsing mic icon)
- Real-time display:
  - Detected notes shown on a chromatic circle or linear strip
  - Current best-guess scale with confidence bar
  - Scale icon + Amharic name when identified
- "Start/Stop Listening" toggle button
- Results card showing matched scale details
- Follows existing green theme and material card patterns

## Modified Files

### 3. `ContentView.swift`
- Add `.identify` case to `AppTab` enum
- Add 4th `Tab("Identify", systemImage: "waveform.badge.mic", value: .identify)` with `IdentifyView()`

### 4. `ToneGenerator.swift`
- Change audio session category from `.playback` to `.playAndRecord` with `.defaultToSpeaker` option
- This allows microphone access while keeping speaker output working

### 5. `Info.plist` (via Xcode build settings)
- Add `NSMicrophoneUsageDescription` key for microphone permission

## Scale Matching Algorithm Detail
- For each of the 4 scales × 12 possible root notes (48 combinations):
  - Map the scale's intervals to absolute semitones: `(root + interval) % 12`
  - Count how many detected notes fall on scale degrees vs. off-scale
  - Score = (on-scale note weight) - (off-scale penalty)
  - Best scoring combination = identified scale + detected root
- Require minimum 3 distinct detected notes and >60% confidence to show a result
