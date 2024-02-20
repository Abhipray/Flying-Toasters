//
//  File.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/18/24.
//

import Accessibility
import Spatial
import RealityKit
import RealityKitContent

/// The main toaster model; it's cloned when a new toaster spawns.
var toasterTemplate: Entity? = nil
var toasterNumber = 0
var toasterSrcPoint = (x: 4.0, y: 4.0, z: -6.0)

var toasterPortal : Entity? = nil


// A function to blink the portal by updating its opacity
func blinkPortal(duration: TimeInterval, blinkTimes: Int) {
    var blinkCount = 0
    let blinkInterval = duration / TimeInterval(blinkTimes * 2)
    
    Timer.scheduledTimer(withTimeInterval: blinkInterval, repeats: true) { timer in
        // Update the opacity
        updatePortalOpacity(to: blinkCount % 2 == 0 ? 0.95 : 1.0)
        
        // Increment the blink count and stop the timer if needed
        blinkCount += 1
        if blinkCount / 2 >= blinkTimes {
            timer.invalidate()
            // Make sure the portal is visible at the end of the blinking
            updatePortalOpacity(to: 1.0)
        }
    }
}

func updatePortalOpacity(to: Float) {
    // Change opacity of portal
    toasterPortal?.components[OpacityComponent.self] = .init(opacity:to)
}

func generateToasterStartEndRotation() -> (Point3D, Point3D, simd_quatf) {
    let centralPoint = toasterSrcPoint
    let range: Double = 1
    

    let x = Double.random(in: (centralPoint.x - range)...(centralPoint.x + range))
    let y = Double.random(in: (centralPoint.y - range)...(centralPoint.y + range))
    let z = Double.random(in: (centralPoint.z - range)...(centralPoint.z + range))
    
    let start = Point3D(x:x, y:y, z:z)
    
    
    let end = Point3D(
        x: start.x + ToasterSpawnParameters.deltaX,
        y: start.y + ToasterSpawnParameters.deltaY,
        z: start.z + ToasterSpawnParameters.deltaZ
    )
    
    // Rotation correction
    // Calculate the rotation in radians (RealityKit uses radians, not degrees)
    let degrees: Double = calculateRotationAngle(from: start.toSIMD3(), to: end.toSIMD3())
    let radians = Float(degrees) * (Float.pi / 180)

    // Create a quaternion for the rotation around the y-axis
    let rotationQuaternion = simd_quatf(angle: radians, axis: [0, 1, 0])
    
    return (start, end, rotationQuaternion)
}

/// Creates a toaster and places it in the space.
@MainActor
func spawnToaster(screenSaverModel: ScreenSaverModel) async throws -> Entity {
    print("Spawning a new toaster")
    
    let (start, end, rotationQuaternion) = generateToasterStartEndRotation()
    
    
    // Randomize speed/duration of animation
    let mean_dur = ToasterSpawnParameters.average_anim_duration
    let range_dur = ToasterSpawnParameters.range_anim_duration
    let anim_duration = Double.random(in: (mean_dur-range_dur)...(mean_dur+range_dur))
    
    // Setup initial toaster spot
    if toasterTemplate == nil {
        guard let toaster = await loadFromRealityComposerPro(
            named: "toaster",
            fromSceneNamed: "flying_toasters"
        ) else {
            fatalError("Error loading toaster from Reality Composer Pro project.")
        }
        toasterTemplate = toaster
    }
    guard let toasterTemplate = toasterTemplate else {
        fatalError("Toaster template is nil.")
    }
    
    let toaster = toasterTemplate.clone(recursive: true)
    toaster.generateCollisionShapes(recursive: true)
    toaster.name = "CToaster\(toasterNumber)"
    toasterNumber += 1
    
    toaster.components[PhysicsBodyComponent.self] = PhysicsBodyComponent()
    toaster.scale = SIMD3<Float>(x: toasterScale, y: toasterScale, z: toasterScale)
    toaster.position = simd_float(start.vector + .init(x: 0, y: 0, z: -0.0))
    toaster.transform.rotation = rotationQuaternion
    
    
    // Generate animation
    let line = FromToByAnimation<Transform>(
        name: "line",
        from: .init(scale: .init(repeating: toasterScale),  rotation: rotationQuaternion, translation: simd_float(start.vector)),
        to: .init(scale: .init(repeating: toasterScale), rotation: rotationQuaternion, translation: simd_float(end.vector)),
        duration: anim_duration,
        bindTarget: .transform
    )
    
    let animation = try! AnimationResource
        .generate(with: line)
    

    toaster.playAnimation(animation, transitionDuration: 1.0, startsPaused: false)
    toaster.setMaterialParameterValues(parameter: "saturation", value: .float(0.0))
    toaster.setMaterialParameterValues(parameter: "animate_texture", value: .bool(false))
    
    toasterAnimate(toaster, kind: .flapWings, shouldRepeat: true)
    
    spaceOrigin.addChild(toaster)

    
    // Schedule the removal of the entity after the animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + anim_duration) {
        toaster.removeFromParent()
        screenSaverModel.currentNumberOfToasters -= 1
    }
    
    // Block portal
    blinkPortal(duration: 0.2, blinkTimes: 1)
    
    return toaster
}


/// Plays one of the toaster animations on the toaster you specify.
@MainActor func toasterAnimate(_ toaster: Entity, kind: ToasterAnimations, shouldRepeat: Bool) {
    guard let animation = toasterAnimations[kind] else {
        fatalError("Tried to load an animation that doesn't exist: \(kind)")
    }
    
    if shouldRepeat {
        toaster.playAnimation(animation.repeat(count: 100))
    } else {
        toaster.playAnimation(animation)
    }
}

/// A map from a kind of animation to the animation resource that contains that animation.
var toasterAnimations: [ToasterAnimations: AnimationResource] = [:]

/// The available animations inside the toaster asset.
enum ToasterAnimations {
    case flapWings
}

/// Toaster spawn parameters (in meters).
struct ToasterSpawnParameters {
    static var deltaX = -12.0
    static var deltaY = -9.0
    static var deltaZ = 12.1
    
    static var average_anim_duration = 10.0
    static var range_anim_duration = 6.0 // +/- average
}

var toasterScale : Float = 0.005

/// A counter that advances to the next toaster path.
var toasterPathsIndex = 0

/// A hand-picked selection of random starting parameters for the motion of the toasters.
var toasterPaths: [(Double, Double, Double)] = []

