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
    
    @State private var showSettings = false
    @State private var immersiveSpaceIsShown = false
    @State private var showingCredits = false
    @State private var wasAudioPlayingBeforeStop = false
    @State private var isJiggling = false
    @State private var timerString = ""
    @State private var showImmersiveSpace = false
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(\.openWindow) private var openVolumeWindow
    @Environment(\.dismissWindow) private var dismissVolumeWindow
    
    @Environment(ScreenSaverModel.self) var screenSaverModel
    
    func timeString(from totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = (totalSeconds % 3600) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func updateTimerString() {
        if (screenSaverModel.isScreenSaverRunning) {
            timerString = "Timer paused"
        } else {
            if (screenSaverModel.isTimerActive) {
                timerString = timeString(from: screenSaverModel.secondsLeft)
            } else {
                timerString = "Timer disabled"
            }
        }
    }
    
    var body: some View {
            VStack(alignment: .center) {
                Spacer()
                
                Text("Flying Toasters")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .fontWeight(.bold) // Makes the text bold
                    .foregroundColor(.primary) // Uses the primary color, which adapts to light/dark mode
                    .background(Color.blue.opacity(0.05)) // Adds a light blue background with some transparency
                    .cornerRadius(10) // Rounds the corners of the background
                    .shadow(radius: 2.5) // Adds a shadow for a 3D effect
                    .help("A Screen Saver")
                
                VStack{

                    Image("flying_toasters_splashscreen")
                        .resizable()
                        .frame(width: 100, height: 100).help("Tap on me to reset the Screen Saver timer")
                        .rotationEffect(.degrees(isJiggling ? 4 : -4), anchor: .center)
                        .animation(isJiggling ? .linear(duration: 0.1).repeatForever(autoreverses: true) : .default, value: isJiggling)
                        .onTapGesture {
                            isJiggling.toggle()
                            
                            // Optionally, stop the jiggle after some time
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                isJiggling = false
                            }
                            
                            screenSaverModel.secondsElapsed = 0
                        }
                        .padding(-15)
                    
                    Toggle(isOn: $showImmersiveSpace) {
                        Image(systemName: showImmersiveSpace ? "pause.fill" : "play.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18) // Specify the frame to increase the size
                    }
                    .onAppear {
                        showImmersiveSpace = screenSaverModel.isScreenSaverRunning
                    }
                    .toggleStyle(.button)
                    .help("Start or stop the Screen Saver")
                    .onChange(of: showImmersiveSpace) { _, newValue in
                        screenSaverModel.handleImmersiveSpaceChange(newValue: newValue)
                    }
                    .onChange(of: screenSaverModel.isScreenSaverRunning) {_,newValue in
                        showImmersiveSpace = newValue;
                    }
                    .padding()
                    
                    // Countdown Timer Display
                    
                    Text(timerString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .onChange(of: screenSaverModel.secondsLeft, {
                            updateTimerString()
                        })
                        .onAppear {
                            screenSaverModel.selectedTimeout = screenSaverModel.selectedTimeout
                            updateTimerString()
                        }
                        .onChange(of: screenSaverModel.isTimerActive, {
                            updateTimerString()
                        })
                        .help("Countdown until next Screen Saver start")
                    
                }
                
                HStack{
                    // Reset animation
                    Button(action: {
                        screenSaverModel.preloadPortals(init_entities: false)
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16) // Specify the frame to increase the size
                            .clipShape(Circle())
                    }
                    .clipShape(Circle())
                    .help("Reset the Screen Saver to default portal positions")
                    
                    
                    // Settings Button
                    Button(action: {
                        showSettings.toggle()
                    }) {
                        Image(systemName: "gear")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16) // Specify the frame to increase the size
                            .clipShape(Circle())
                    }
                    .clipShape(Circle()) // Ensure the entire button is clipped to a circle shape.
                    .sheet(isPresented: $showSettings) {
                        SettingsView()
                    }
                    .help("Settings")
                    
                    
                    Button(action: {
                        self.showingCredits = true
                    }) {
                        Image(systemName: "info.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16) // Specify the frame to increase the size
                            .foregroundColor(.primary)
                    }
                    .sheet(isPresented: $showingCredits) {
                        CreditsView()
                    }
                    .clipShape(Circle()) // Ensure the entire button is clipped to a circle shape.
                    .help("Credits")
                }
                .padding()
            }
            .padding()
            .onAppear {
                screenSaverModel.openImmersiveSpace = openImmersiveSpace
                screenSaverModel.dismissImmersiveSpace = dismissImmersiveSpace
                screenSaverModel.dismissVolumeSpace = dismissVolumeWindow
                screenSaverModel.openVolumeSpace = openVolumeWindow
            }
            .onDisappear {
                screenSaverModel.handleImmersiveSpaceChange(newValue:false)
            }
    }
}

struct SettingsView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(ScreenSaverModel.self) var screenSaverModel

    
    // Arrays to hold the values for hours, minutes, and seconds
    let hoursRange = Array(0...23)
    let minutesAndSecondsRange = Array(0...59)

    var body: some View {
        @Bindable var screenSaverModel = screenSaverModel
        NavigationView {
            Form {
                Section() {
                    HStack{
                        Text("Display mode:")
                        Picker("Display mode", selection: $screenSaverModel.displayMode) {
                            Text("Volumetric").tag(0) // Index for Light
                            Text("Immersive").tag(1) // Index for Medium
                        }
                        .pickerStyle(.segmented)
                        .disabled(screenSaverModel.isScreenSaverRunning)
                        .help("Allow/disallow Screen Saver to run alongside other apps")
                    }
                    
                    
                    Picker("Start Screen Saver when inactive ", selection: $screenSaverModel.selectedTimeout) {
                        ForEach(0..<screenSaverModel.timeouts.count, id: \.self) { index in
                            Text(screenSaverModel.timeouts[index].0).tag(index)
                        }
                    }
                    .help("Choose the duration of inactivity before the screensaver starts.")
                    
                    if screenSaverModel.useCustomTimeout {
                        HStack {
                            Picker("Hrs", selection: $screenSaverModel.hours) {
                                ForEach(hoursRange, id: \.self) {
                                    Text("\($0)")
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Picker("Mins", selection: $screenSaverModel.minutes) {
                                ForEach(minutesAndSecondsRange, id: \.self) {
                                    Text("\($0)")
                                }
                            }
                            .pickerStyle(.menu)
                            
                            Picker("Secs", selection: $screenSaverModel.seconds) {
                                ForEach(minutesAndSecondsRange, id: \.self) {
                                    Text("\($0)")
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                Section(header: Text("Toaster Settings").font(.headline)) {
                    VStack {
                        Text("Number of toasts and toasters: \(Int(screenSaverModel.numberOfToastersConfig))")
                        Slider(value: $screenSaverModel.numberOfToastersConfig, in: 5...20, step: 1)
                            .padding(.horizontal)
                            .help("Set the number of flying toasters displayed.")
                    }

                    HStack{
                        Text("Toast Level:")
                        Picker("Toast Level", selection: $screenSaverModel.toastLevelConfig) {
                            Text("Light").tag(0) // Index for Light
                            Text("Medium").tag(1) // Index for Medium
                            Text("Dark").tag(2) // Index for Dark
                        }
                        .pickerStyle(.segmented)
                        .help("Adjust how toasted you like your toasts.")
                    }
                    
                    Toggle(isOn: $screenSaverModel.musicEnabled) {
                        Label("Music", systemImage: screenSaverModel.musicEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                            .foregroundColor(screenSaverModel.musicEnabled ? .green : .red)
                    }
                    .help("Enable or disable background music for the screensaver.")
                    
                    ColorPicker("Toaster Color", selection: $screenSaverModel.toasterColor).help("Pick a color for the toasters")
                    
                    Toggle(isOn: $screenSaverModel.ghostMode) {
                        Text("Make Toasters Ghosts")
                    }
                    .help("Allow toasters to pass through each other")
                    
                }
                
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "checkmark.circle")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.white) // Change the icon color to white for better contrast
                            .frame(width: 32, height: 32) // Control the image size
                            .padding(8) // Add some padding to make the button larger and easier to tap
                            .clipShape(Circle()) // Ensure the button's background is also clipped to a circle
                            .shadow(radius: 5) // Add a shadow for a lifted effect
                    }
                    .clipShape(Circle())
                }
            }
        }
    }
}


#Preview(windowStyle: .automatic) {
    SettingsView()
}
