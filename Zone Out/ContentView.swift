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
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(ScreenSaverModel.self) var screenSaverModel
    
    
    var body: some View {
        GeometryReader {geometry in
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    Spacer()
                    
                    Text("Flying Toasters")
                        .font(.title) // Makes the font size much larger
                        .fontWeight(.bold) // Makes the text bold
                        .foregroundColor(.primary) // Uses the primary color, which adapts to light/dark mode
                        .padding() // Adds some padding around the text
                        .background(Color.blue.opacity(0.05)) // Adds a light blue background with some transparency
                        .cornerRadius(20) // Rounds the corners of the background
                        .shadow(radius: 5) // Adds a shadow for a 3D effect
                        .help("A screensaver")
                    
                    VStack{

                        Image("flying_toasters_splashscreen")
                            .resizable()
                            .frame(width: 256, height: 256).help("Tap on me to reset the screensaver timer!")
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
                            .opacity(0.9)
                        
                        // Countdown Timer Display
                        Text(screenSaverModel.getTimerString())
                            .font(.largeTitle)
                            .padding()
                            .background(Color.black.opacity(1.0))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .onChange(of: screenSaverModel.secondsLeft, {timerString = screenSaverModel.getTimerString()})
                        
                    }
                    
                    HStack{
                        // Settings Button
                        Button(action: {
                            showSettings.toggle()
                        }) {
                            Image(systemName: "gear")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32) // Specify the frame to increase the size
                                .clipShape(Circle())
                        }
                        .padding()
                        .sheet(isPresented: $showSettings) {
                            SettingsView()
                        }
                        
                        
                        Button(action: {
                            self.showingCredits = true
                        }) {
                            Image(systemName: "info.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32) // Specify the frame to increase the size
                                .clipShape(Circle())
                        }
                        .sheet(isPresented: $showingCredits) {
                            CreditsView()
                        }
                    }
                    
                    Spacer()
                    
                }
                .frame(width: geometry.size.width)
                .padding()
            }
            .onAppear {
                screenSaverModel.openImmersiveSpace = openImmersiveSpace
                screenSaverModel.dismissImmersiveSpace = dismissImmersiveSpace
            }
        }
    }
}

struct SettingsView: View {

    @Environment(\.dismiss) var dismiss
    @Environment(ScreenSaverModel.self) var screenSaverModel
    
    @State private var showImmersiveSpace = false

    var body: some View {
        @Bindable var screenSaverModel = screenSaverModel
        NavigationView {
            Form {
                Section(header: Text("").font(.headline)) {
                    Picker("Start Screen Saver when inactive ", selection: $screenSaverModel.selectedTimeout) {
                        ForEach(0..<screenSaverModel.timeouts.count, id: \.self) { index in
                            Text(screenSaverModel.timeouts[index].0).tag(index)
                        }
                    }
                    .help("Choose the duration of inactivity before the screensaver starts.")
                }

                Section(header: Text("Toaster Settings").font(.headline)) {
                    VStack {
                        Text("Number of toasters: \(Int(screenSaverModel.numberOfToastersConfig))")
                        Slider(value: $screenSaverModel.numberOfToastersConfig, in: 10...20, step: 1)
                            .padding(.horizontal)
                            .help("Set the number of flying toasters displayed.")
                    }

                    VStack{
                        Text("Toast Level:")
                        Picker("Toast Level", selection: $screenSaverModel.toastLevelConfig) {
                            ForEach(["Light", "Medium", "Dark"], id: \.self) { toastLevel in
                                Text(toastLevel).tag(toastLevel)
                            }
                        }
                        .pickerStyle(.segmented)
                        .help("Adjust how toasted you like your toasts.")
                    }
                    Toggle(isOn: $screenSaverModel.musicEnabled) {
                        Label("Music", systemImage: screenSaverModel.musicEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                            .foregroundColor(screenSaverModel.musicEnabled ? .green : .red)
                    }
                    .help("Enable or disable background music for the screensaver.")
                }
                
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Toggle(isOn: $showImmersiveSpace) {
                            Image(systemName: showImmersiveSpace ? "eye.slash" : "eye")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32) // Specify the frame to increase the size
                                .clipShape(Circle())
                        }
                        .toggleStyle(.button)
                        .help("Start or stop preview of the screensaver")
                        .onChange(of: showImmersiveSpace) { _, newValue in
                            screenSaverModel.handleImmersiveSpaceChange(newValue: newValue)
                        }
                        Spacer()
                        
                        
                        Button(action: {
                            screenSaverModel.handleImmersiveSpaceChange(newValue: false)
                            dismiss()
                        }) {
                            Image(systemName: "checkmark")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32) // Specify the frame to increase the size
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding()
        }
    }
}
    


#Preview(windowStyle: .automatic) {
    SettingsView()
}
