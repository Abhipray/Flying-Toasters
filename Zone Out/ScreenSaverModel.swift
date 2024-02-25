//
//  ScreenSaverModel.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/18/24.
//

import Foundation
import RealityKit
import RealityKitContent
import SwiftUI
import GameplayKit
import AVFoundation
import Combine

func calculateRotationAngle(from startPoint: SIMD3<Double>, to endPoint: SIMD3<Double>) -> Double {
    let directionVector = endPoint - startPoint
    let normalizedDirection = normalize(directionVector)
    
    let forwardVector = SIMD3<Double>(0, 0, 1) 
    let dotProduct = dot(normalize(forwardVector), normalizedDirection)
    let angleCosine = acos(dotProduct)
    
    let angleDegrees = angleCosine * 180 / .pi
    
    // Determine the direction of rotation
    let crossProduct = cross(forwardVector, normalizedDirection)
    let angleSign = crossProduct.y.sign == .plus ? 1 : -1
    
    let finalAngleDegrees = angleDegrees * Double(angleSign)
    
    return finalAngleDegrees
}

/// State that drives the different screens of the game and options that players select.
@Observable
class ScreenSaverModel {
   
    var isScreenSaverRunning = false
    
    var audioPlayer: AVAudioPlayer? = nil
    
    var secondsElapsed = 0
    var secondsLeft = Int.max
    
    var timer: Timer?
    var cancellable: AnyCancellable?
    
    // Set externally
    var openImmersiveSpace: OpenImmersiveSpaceAction?
    var dismissImmersiveSpace: DismissImmersiveSpaceAction?
    
    
    // Toaster config
    var numberOfToastersConfig: Double = 10
    var toastLevelConfig: Int = 1
    var musicEnabled = false
    
    
    // State variables
    var currentNumberOfToasters: Int = 0
    var currentCountdownSecs: Int = 0
    
    var useCustomTimeout = false
    var hours = 0 {
        didSet {
            currentCountdownSecs = hours * 60 * 60 + minutes * 60 + seconds
        }
    }
    var minutes = 0 {
        didSet {
            currentCountdownSecs = hours * 60 * 60 + minutes * 60 + seconds
        }
    }
    var seconds = 0 {
        didSet {
            currentCountdownSecs = hours * 60 * 60 + minutes * 60 + seconds
        }
    }
    
    // Timer variables
    var isTimerActive: Bool = false
    
    let timeouts = [("For 1 Minute", 1), ("For 5 Minutes", 5), ("For 15 Minutes", 15), ("For 30 Minutes", 30), ("For 1 Hour", 60), ("For 2 Hours", 120), ("Never", 0), ("Custom", -1), ("For 10 seconds", 0.1)]
    
    var selectedTimeout : Int = 6 {
        didSet {
            let timeoutLabel = timeouts[selectedTimeout].0
            useCustomTimeout = false
            if timeoutLabel == "Never" {
                stopTimer()
            } else if timeoutLabel == "Custom" {
                useCustomTimeout = true
                currentCountdownSecs = Int(hours * 60 * 60 + minutes * 60 + seconds)
                startTimer()
            } else {
                useCustomTimeout = false
                currentCountdownSecs = Int(timeouts[selectedTimeout].1 * 60)
                startTimer()
            }
        }
    }
    
    
    
    // Initialize and start the timer
    func startTimer() {
        if isTimerActive {
            return
        }
        isTimerActive = true
        timer?.invalidate() // Invalidate any existing timer
        secondsElapsed = 0 // Reset the counter
        
        // Using a Combine publisher to update the @Published property
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }
                print("\(strongSelf.secondsElapsed)")
                strongSelf.secondsElapsed += 1
                strongSelf.secondsLeft = strongSelf.currentCountdownSecs - strongSelf.secondsElapsed
                
                if strongSelf.secondsLeft <= 0 {
                    strongSelf.handleImmersiveSpaceChange(newValue: true)
                }
            }
    }
    
    // Stop the timer
    func stopTimer() {
        if !isTimerActive {
            return
        }
        cancellable?.cancel() // Stop the Combine publisher
        timer?.invalidate() // Invalidate the timer
        timer = nil // Set the timer to nil
        isTimerActive = false
    }
    
    // Clean up
    deinit {
        stopTimer()
    }

    func handleImmersiveSpaceChange(newValue: Bool) {
        Task {
            if newValue && !isScreenSaverRunning {
                if  musicEnabled {
                    audioPlayer?.play() // Ensure this function starts playing the audio
                } else {
                    audioPlayer?.stop() // Ensure this function stops the audio
                }
                guard let openSpace = openImmersiveSpace else {
                    print("openImmersiveSpace is not available.")
                    return
                }
                switch await openSpace(id: "ImmersiveSpace") {
                case .opened:
                    isScreenSaverRunning = true
                    stopTimer()
                case .error, .userCancelled:
                    fallthrough
                @unknown default:
                    isScreenSaverRunning = false
                }
            } else if !newValue && isScreenSaverRunning {
                print("Disabling screen saver")
                isScreenSaverRunning = false
                secondsElapsed = 0
                audioPlayer?.stop() // Ensure this function stops the audio
                guard let dismissSpace = dismissImmersiveSpace else {
                    print("openImmersiveSpace is not available.")
                    return
                }
                await dismissSpace()
            }
        }
    }
    
    /// Preload assets when the app launches to avoid pop-in during the game.
    init() {
        Task { @MainActor in
        
            var entity: Entity? = nil
            do {
                let scene = try await Entity(named: "flying_toasters", in: realityKitContentBundle)
                entity = scene.findEntity(named: "toaster")
            } catch {
                print("Error loading toaster from scene flying_toasters: \(error.localizedDescription)")
            }
            
            
            toasterTemplate = entity
            
            guard toasterTemplate != nil else {
                fatalError("Error loading assets.")
            }
            
            
            // Generate animations inside the toaster models.
            let def = toasterTemplate!.availableAnimations[0].definition
            toasterAnimations[.flapWings] = try .generate(with: AnimationView(source: def, speed: 5.0))

        
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
            
        }
    }
    
}
