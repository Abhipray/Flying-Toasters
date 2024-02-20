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
    
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(ScreenSaverModel.self) var screenSaverModel

    var body: some View {
        GeometryReader {geometry in
            VStack {
                
                Spacer()
                
                Text("Flying Toasters").padding()
                
                Toggle(showImmersiveSpace ? "Stop" : "Start", isOn: $showImmersiveSpace)
                    .toggleStyle(.button)
                    .padding()
                
                
                // Display the number of toasters
                @Bindable var screenSaverModel = screenSaverModel
                Text("Number of toasters: \(Int(screenSaverModel.numberOfToastersConfig))")
                    .padding()
                
                // Slider for choosing the number of toasters
                Slider(value: $screenSaverModel.numberOfToastersConfig, in: 10...20, step: 1)
                    .padding()
                    .frame(maxWidth:300)
                
                let toastLevels : Array = ["Light", "Medium", "Dark"]
                
                // Display the toast level
                Text("Toast level: \(toastLevels[screenSaverModel.toastLevelConfig])")
                    .padding()
                
                // Dial (Picker) for choosing the toast level
                Picker("Toast Level", selection: $screenSaverModel.toastLevelConfig) {
                    ForEach(toastLevels, id: \.self) { toastLevel in
                        Text(toastLevel).tag(toastLevel)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth:300)
                .padding()
                
                
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
                .background(Circle().fill(isMusicPlaying ? Color.green.opacity(0.2) : Color.red.opacity(0.2))) // Optional background
                
                Spacer()
                
            }
            .frame(width: geometry.size.width)
            .padding()
            .onChange(of: showImmersiveSpace) { _, newValue in
                Task {
                    if newValue {
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
                        await dismissImmersiveSpace()
                        immersiveSpaceIsShown = false
                    }
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
