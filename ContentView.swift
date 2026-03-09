//
//  ContentView.swift
//  Qenet
//
//  Created by Bikila Diriba on 3/5/26.
//

import SwiftUI

/// Root view with tab-based navigation for the Qignit music teaching app.
struct ContentView: View {
    @State private var selectedTab: AppTab = .play
    @State private var toneGenerator = ToneGenerator()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Play", systemImage: "pianokeys", value: .play) {
                PlayerView(toneGenerator: toneGenerator)
            }
            
            Tab("Learn", systemImage: "book.fill", value: .learn) {
                LearnView(toneGenerator: toneGenerator)
            }
            
            Tab("Practice", systemImage: "ear.fill", value: .practice) {
                QuizView(toneGenerator: toneGenerator)
            }
            
            Tab("Identify", systemImage: "waveform.badge.mic", value: .identify) {
                IdentifyView()
            }
        }
        .tint(.accentColor)
    }
}

enum AppTab: Hashable {
    case play
    case learn
    case practice
    case identify
}

#Preview {
    ContentView()
}
