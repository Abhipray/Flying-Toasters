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

func calculateRotationAngle(from startPoint: SIMD3<Float>, to endPoint: SIMD3<Float>) -> (axis: SIMD3<Float>, angle: Float) {
    let directionVector = endPoint - startPoint
    let normalizedDirection = normalize(directionVector)
    
    let forwardVector = SIMD3<Float>(0, 0, 1)
    let dotProduct = dot(normalize(forwardVector), normalizedDirection)
    let angleRadians = acos(dotProduct)

    
    // Determine the direction of rotation
    let rotationAxis = cross(forwardVector, normalizedDirection)
    let rotationAxisFloat = SIMD3<Float>(Float(rotationAxis.x), Float(rotationAxis.y), Float(rotationAxis.z))

    // Normalize the rotation axis (if not already normalized)
    let normalizedAxis = normalize(rotationAxisFloat)
    
    return (normalizedAxis, Float(angleRadians))
}

extension DismissImmersiveSpaceAction: @unchecked Sendable {}

/// State that drives the different screens of the game and options that players select.
@Observable
class ScreenSaverModel {
   
    var isScreenSaverRunning = false
    var audioPlayer: AVAudioPlayer? = nil
    var secondsLeft = Int.max
    
    var toasterColor = Color(.sRGB, red: 0.98, green: 0.9, blue: 0.2)
    
    var secondsElapsed = 0 {
        didSet {
            print("Setting secondsElapsed", secondsLeft, secondsElapsed)
            secondsLeft = currentCountdownSecs - secondsElapsed
        }
    }
    
    var timer: Timer?
    var cancellable: AnyCancellable?
    
    // Set externally
    var openImmersiveSpace: OpenImmersiveSpaceAction?
    var dismissImmersiveSpace: DismissImmersiveSpaceAction?
    
    var openVolumeSpace: OpenWindowAction?
    var dismissVolumeSpace: DismissWindowAction?
    var displayMode : Int = 1 {
        didSet {
                useImmersiveDisplay = displayMode == 1
                let scale = useImmersiveDisplay ? 1.0 : volumetricToImmersionRatio
                preloadPortals(init_entities: false)
                moonEntity.position = (toasterEndPoint - 0.3) * scale
                moonEntity.scale = simd_float3(repeating: 0.75) * scale
                sunEntity.position = (toasterSrcPoint + 0.3) * scale
                sunEntity.scale = simd_float3(repeating: 1.0) * scale
            
        }
    }
    
    var useImmersiveDisplay : Bool = true
    
    // Toaster config
    var ghostMode: Bool = true
    var numberOfToastersConfig: Double = 10
    var toastLevelConfig: Int = 0
    var musicEnabled = true {
        didSet {
            if (isScreenSaverRunning) {
                if (musicEnabled) {
                    audioPlayer?.volume = 0.01
                    audioPlayer?.play()
                    audioPlayer?.setVolume(0.1, fadeDuration: 5)
                } else {
                    audioPlayer?.stop()
                }
            }
        }
    }
    
    
    // State variables
    var currentNumberOfToasters: Int = 0
    var currentCountdownSecs: Int = 0
    
    var useCustomTimeout = false
    var hours = 1 {
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
    
    let timeouts = [("For 1 Minute", 1), ("For 5 Minutes", 5), ("For 15 Minutes", 15), ("For 30 Minutes", 30), ("For 1 Hour", 60), ("For 2 Hours", 120), ("Never", 0), ("Custom", -1)]
    
    let toastTypes = ["light", "medium", "dark"]
    
    var selectedTimeout : Int = 4 {
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
        secondsElapsed = 0 // Reset the counter
        isTimerActive = true
        timer?.invalidate() // Invalidate any existing timer
        
        // Using a Combine publisher to update the @Published property
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let strongSelf = self else { return }
                print("\(strongSelf.secondsElapsed)")
                strongSelf.secondsElapsed += 1
                
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
                    audioPlayer?.volume = 0.01
                    audioPlayer?.play() // Ensure this function starts playing the audio
                    audioPlayer?.setVolume(0.1, fadeDuration: 5)
                } else {
                    audioPlayer?.stop() // Ensure this function stops the audio
                }
                if self.useImmersiveDisplay {
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
                } else {
                    guard let openSpace = self.openVolumeSpace else {
                        print("openVolumeSpace is not available.")
                        return
                    }
                    openSpace(id: "VolumetricSpace")
                    isScreenSaverRunning = true
                    stopTimer()
                }
            } else if !newValue && isScreenSaverRunning {
                print("Disabling screen saver")
                
                audioPlayer?.stop() // Ensure this function stops the audio
                if self.useImmersiveDisplay {
                    guard let dismissSpace = dismissImmersiveSpace else {
                        print("dismissImmersiveSpace is not available.")
                        return
                    }
                    await dismissSpace()
                } else {
                    guard let dismissSpace = dismissVolumeSpace else {
                        print("dismissVolumeSpace is not available.")
                        return
                    }
                    dismissSpace(id: "VolumetricSpace")
                }
                
                let timeoutLabel = timeouts[selectedTimeout].0
                if timeoutLabel != "Never" {
                    startTimer()
                }
                isScreenSaverRunning = false
                secondsElapsed = 0
            }
        }
    }
    
    func load_toast(toastObjName: String)  async throws -> Entity {
            guard let toast = await loadFromRealityComposerPro(
                named: toastObjName,
                fromSceneNamed: "flying_toasters"
            ) else {
                fatalError("Error loading toast from Reality Composer Pro project.")
            }
        return toast;
    }
    
    @MainActor
    public func getStarfieldEntity() async throws -> Entity {
        // Create a material with a star field on it.
        guard let resource = try? await TextureResource(named: "Starfield") else {
            // If the asset isn't available, something is wrong with the app.
            fatalError("Unable to load starfield texture.")
        }
        var material = UnlitMaterial()
        material.color = .init(texture: .init(resource))

        // Attach the material to a large sphere.
        let entity = Entity()
        entity.components.set(ModelComponent(
            mesh: .generateSphere(radius: 1000),
            materials: [material]
        ))

        // Ensure the texture image points inward at the viewer.
        entity.scale *= .init(x: -1, y: 1, z: 1)
        return entity
    }
    
    public func makeWorld() -> Entity {
        let world = Entity()
        world.components[WorldComponent.self] = .init()
        
        Task { @MainActor in
            let sky = try await getStarfieldEntity()
            world.addChild(sky)
            
            guard let moon = await loadFromRealityComposerPro(
                named: "Moon",
                fromSceneNamed: "flying_toasters"
            ) else {
                fatalError("Error loading Moon from Reality Composer Pro project.")
            }
            moon.position = toasterEndPoint
            moon.position -= 0.3
            moon.scale = simd_float3(repeating: 0.75)
            moonEntity = moon
            world.addChild(moon)
            
            guard let sun = await loadFromRealityComposerPro(
                named: "Sun",
                fromSceneNamed: "flying_toasters"
            ) else {
                fatalError("Error loading Moon from Reality Composer Pro project.")
            }
            sun.position = toasterSrcPoint
            sun.position += 0.3
            sun.scale = simd_float3(repeating: 1.0)
            sunEntity = sun
            world.addChild(sun)
        }
        
        return world
    }
    
    public func makePortal(world: Entity) -> Entity {
        let portal = Entity()
        
        portal.components[ModelComponent.self] = .init(mesh: .generatePlane(width: 2, height: 2, cornerRadius: 1), materials: [PortalMaterial()])
        portal.components[PortalComponent.self] = .init(target: world)
        portal.components[InputTargetComponent.self] = .init(allowedInputTypes: .all)
        portal.components[InputTargetComponent.self]?.isEnabled = true
        portal.components[CollisionComponent.self] = CollisionComponent(shapes: [.generateBox(width: 2, height: 2, depth: 0.5)], mode: .trigger)
        portal.components.set(HoverEffectComponent())
        
        let component = GestureComponent(canDrag: true, pivotOnDrag: false, preserveOrientationOnPivotDrag: false, canScale: true, canRotate: true)
        portal.components.set(component)
        
        // Particle effects
        let particleEntity = Entity()

        var particles = ParticleEmitterComponent.Presets.magic
        particles.mainEmitter.color = .evolving(start: .single(.white), end: .single(.blue))
        particles.emitterShape = ParticleEmitterComponent.EmitterShape.torus
        particles.birthLocation = ParticleEmitterComponent.BirthLocation.surface
        particles.birthDirection = ParticleEmitterComponent.BirthDirection.local
        particles.emitterShapeSize = SIMD3<Float>(x: 0.8, y: 0.8, z: 0.8)
        particles.particlesInheritTransform = true
        particles.speed = 3.0
        particles.burstCount = 100
        particles.mainEmitter.birthRate = 50
        particleEntity.components[ParticleEmitterComponent.self] = particles
        portal.addChild(particleEntity)
        
        // Add a backing
        // Create the circular plane as a child entity
        let circularPlaneBack = ModelEntity(mesh: .generatePlane(width: 2, height: 2, cornerRadius: 1), materials: [SimpleMaterial(color: .black, isMetallic: false)])
        circularPlaneBack.setSunlight(intensity: nil)
        circularPlaneBack.position = [0, 0, -0.1]
        circularPlaneBack.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0]) // Rotate 180 degrees around the y-axis

        // Add the circular plane as a child of the portal
        portal.addChild(circularPlaneBack)
        
        return portal
    }
    
    func preloadPortals(init_entities: Bool) -> Void {
        let scale = self.useImmersiveDisplay ? 1.0 : volumetricToImmersionRatio
        
        // Start portal
        if init_entities {
            portalWorld = makeWorld()
            startPortal = makePortal(world: portalWorld)
            endPortal = makePortal(world: portalWorld)
        }
        
        let end = toasterEndPoint * scale
        let start = toasterSrcPoint * scale
        let (rotationAxis, radians) = calculateRotationAngle(from:start, to:end)

        // Create a quaternion for the rotation around the y-axis
        // Convert rotation axis and angle to Float
        startPortal.position = start * scale
        var rotationQuaternion =  simd_quatf(angle: radians, axis: rotationAxis)
        startPortal.transform.rotation = rotationQuaternion
        startPortal.transform.scale = SIMD3<Float>(x: 1.0, y: 1.0, z: 1.0) * scale
    

        endPortal.position = end * scale
        endPortal.scale = SIMD3<Float>(repeating: 1.0) * scale
        rotationQuaternion =  simd_quatf(angle: radians + Float.pi, axis: rotationAxis)
        endPortal.transform.rotation = rotationQuaternion
        
        startPortal.components[GestureComponent.self]?.scaleMaxMag = 100*scale
        startPortal.components[GestureComponent.self]?.scaleMinMag = 0.8*scale
        startPortal.components[GestureComponent.self]?.initialScaleXVal = startPortal.scale.x
        
        endPortal.components[GestureComponent.self]?.scaleMaxMag = 100*scale
        endPortal.components[GestureComponent.self]?.scaleMinMag = 0.8*scale
        endPortal.components[GestureComponent.self]?.initialScaleXVal = endPortal.scale.x
    }
    
    /// Preload assets when the app launches to avoid pop-in during the game.
    init() {
        Task { @MainActor in
        
            // Pre-load toasters
            var entity: Entity? = nil
            do {
                let scene = try await Entity(named: "flying_toasters", in: realityKitContentBundle)
                entity = scene.findEntity(named: "toaster_mirror_perm2")
            } catch {
                print("Error loading toaster from scene flying_toasters: \(error.localizedDescription)")
            }
            
            toasterTemplate = entity
            
            guard toasterTemplate != nil else {
                fatalError("Error loading assets.")
            }
            
            guard let toasterTemplate = toasterTemplate else {
                fatalError("Toaster template is nil.")
            }
            
            for i in 1...toastMempoolLen {
                let toaster = toasterTemplate.clone(recursive: true)
                toaster.generateCollisionShapes(recursive: true)
                toaster.name = "CToaster\(i)"                
                toaster.scale = SIMD3<Float>(x: toasterScale, y: toasterScale, z: toasterScale)
                toasters.append(toaster)
            }
            
            // Pre-load toast
            do {
                toastLightTemplate = try await load_toast(toastObjName: "toast_light")
            } catch {
                print("Failed to load toast:", error.localizedDescription)
            }
            do {
                toastMediumTemplate = try await load_toast(toastObjName: "toast_med")
            } catch {
                print("Failed to load toast:", error.localizedDescription)
            }
            do {
                toastDarkTemplate = try await load_toast(toastObjName: "toast_dark")
            } catch {
                print("Failed to load toast:", error.localizedDescription)
            }
                       
            // Generate animations inside the toaster models.
            let def = toasterTemplate.availableAnimations[0].definition
            toasterAnimations[.flapWings] = try .generate(with: AnimationView(source: def, speed: 3.0))
        
            // Check if the audio player is already initialized
            if self.audioPlayer == nil {
                // Initialize the audio player
                if let audioURL = Bundle.main.url(forResource: "Flying-Toasters-HD", withExtension: "mp3") {
                    do {
                        self.audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
                        self.audioPlayer?.prepareToPlay()
                        self.audioPlayer?.numberOfLoops = -1 // Loop indefinetly
                    } catch {
                        print("Failed to initialize AVAudioPlayer: \(error)")
                    }
                }
            }
            
            preloadPortals(init_entities: true)
            
        }
    }
    
}
