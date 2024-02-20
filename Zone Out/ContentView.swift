//
//  ContentView.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/17/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import AVFoundation

struct ContentView: View {

    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var isMusicPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var showingCredits = false
    @State private var wasAudioPlayingBeforeStop = false
    
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(ScreenSaverModel.self) var screenSaverModel

    var body: some View {
        GeometryReader {geometry in
        ScrollView {
            VStack {
                
                Spacer()
                
                Image("flying_toasters_splashscreen")
                    .resizable()
                    .frame(width: 180, height: 180).help("Tap on me to reset the screensaver timer!")
                
                Text("Flying Toasters")
                    .font(.title) // Makes the font size much larger
                    .fontWeight(.bold) // Makes the text bold
                    .foregroundColor(.primary) // Uses the primary color, which adapts to light/dark mode
                    .padding() // Adds some padding around the text
                    .background(Color.blue.opacity(0.05)) // Adds a light blue background with some transparency
                    .cornerRadius(20) // Rounds the corners of the background
                    .shadow(radius: 5) // Adds a shadow for a 3D effect
                    .help("A screensaver")
                
                Toggle(showImmersiveSpace ? "Stop" : "Start", isOn: $showImmersiveSpace)
                    .toggleStyle(.button)
                    .padding()
                    .help("Start or stop the screensaver")
                
                
                // Display the number of toasters
                @Bindable var screenSaverModel = screenSaverModel
                Text("Number of toasters: \(Int(screenSaverModel.numberOfToastersConfig))")
                    .help("Number of toasters flying at any given time")
                
                // Slider for choosing the number of toasters
                Slider(value: $screenSaverModel.numberOfToastersConfig, in: 10...20, step: 1)
                    .padding()
                    .frame(maxWidth:300)
                
                let toastLevels : Array = ["Light", "Medium", "Dark"]
                
                // Display the toast level
                Text("Toast level: \(toastLevels[screenSaverModel.toastLevelConfig])")
                
                // Dial (Picker) for choosing the toast level
                Picker("Toast Level", selection: $screenSaverModel.toastLevelConfig) {
                    ForEach(toastLevels, id: \.self) { toastLevel in
                        Text(toastLevel).tag(toastLevel)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth:300)
                
                
                // Music controls
                Button(action: {
                    // Toggle music state
                    self.isMusicPlaying.toggle()
                    
                    // Check if the audio player is already initialized
                    if self.audioPlayer == nil {
                        // Initialize the audio player
                        if let audioURL = Bundle.main.url(forResource: "Flying-Toasters-HD", withExtension: "mp3") {
                            do {
                                self.audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                                self.audioPlayer?.prepareToPlay()
                            } catch {
                                print("Failed to initialize AVAudioPlayer: \(error)")
                            }
                        }
                    }
                    
                    // Play or pause the music based on the toggle state
                    if self.isMusicPlaying {
                        self.audioPlayer?.volume = 0.1
                        self.audioPlayer?.play()
                    } else {
                        self.audioPlayer?.pause()
                    }
                }) {
                    Image(systemName: isMusicPlaying ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.largeTitle) // Adjust size as needed
                        .foregroundColor(isMusicPlaying ? .green : .red) // Optional color change
                }
                .padding()
                
                
                
                Button(action: {
                    self.showingCredits = true
                }) {
                    Text("Show Credits")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
                .sheet(isPresented: $showingCredits) {
                    CreditsView()
                }
                
                Spacer()
                
            }
            .frame(width: geometry.size.width)
            .padding()
            .onChange(of: showImmersiveSpace) { _, newValue in
                Task {
                    if newValue {
                        // If the immersive space is started
                        if wasAudioPlayingBeforeStop {
                            // Resume audio only if it was playing before stopping
                            isMusicPlaying = true
                            self.audioPlayer?.play() // Ensure this function starts playing the audio
                        } else {
                            // If the immersive space is stopped
                            wasAudioPlayingBeforeStop = isMusicPlaying // Remember if audio was playing
                            self.audioPlayer?.stop() // Ensure this function stops the audio
                        }
                        switch await openImmersiveSpace(id: "ImmersiveSpace") {
                        case .opened:
                            immersiveSpaceIsShown = true
                        case .error, .userCancelled:
                            fallthrough
                        @unknown default:
                            immersiveSpaceIsShown = false
                            showImmersiveSpace = false
                        }
                    } else if immersiveSpaceIsShown {
                        wasAudioPlayingBeforeStop = isMusicPlaying
                        self.audioPlayer?.stop() // Ensure this function stops the audio
                        await dismissImmersiveSpace()
                        immersiveSpaceIsShown = false
                    }
                }
            }
        }
    }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
