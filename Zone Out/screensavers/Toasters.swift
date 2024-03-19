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
var toastLightTemplate: Entity? = nil
var toastMediumTemplate: Entity? = nil
var toastDarkTemplate: Entity? = nil
var startPortal = Entity()
var endPortal = Entity()
var portalWorld = Entity()
var toastNumber = 0
var toasterSrcPoint = (x: 4.0, y: 4.0, z: -6.0)

var toasterPortal : Entity? = nil

func generateToasterStartEndRotation() -> (Point3D, Point3D, simd_quatf) {
    let centralPoint = toasterSrcPoint
    let range: Double = 0.5
    

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
    let (rotationAxis, radians) = calculateRotationAngle(from: start.toSIMD3(), to: end.toSIMD3())

    // Create a quaternion for the rotation around the y-axis
    let rotationQuaternion = simd_quatf(angle: radians, axis: rotationAxis)
    
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
    
    let toaster = toasters[toastIndex % toasters.count];
    toastIndex += 1;
    
    toaster.position = simd_float(start.vector + .init(x: 0, y: 0, z: -0.0))
    toaster.transform.rotation = rotationQuaternion

    toaster.playAnimation(animation, transitionDuration: 1.0, startsPaused: false)
    toaster.setMaterialParameterValues(parameter: "saturation", value: .float(0.0))
    toaster.setMaterialParameterValues(parameter: "animate_texture", value: .bool(false))
    
    toasterAnimate(toaster, kind: .flapWings, shouldRepeat: true)
    
    spaceOrigin.addChild(toaster)
    
    // Schedule the removal of the entity after the animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + anim_duration) { [weak toaster] in
        toaster?.removeFromParent()
        screenSaverModel.currentNumberOfToasters -= 1
    }
    
    return toaster
}

@MainActor
func spawnToast(screenSaverModel: ScreenSaverModel, toastType: String) async throws -> Entity {
    print("Spawning a new toast")
    
    let (start, end, _) = generateToasterStartEndRotation()
    let rotationQuaternion = simd_quatf(angle: Float.pi/4, axis: [1, 1, 0])
    
    // Randomize speed/duration of animation
    let mean_dur = ToasterSpawnParameters.average_anim_duration
    let range_dur = ToasterSpawnParameters.range_anim_duration
    let anim_duration = Double.random(in: (mean_dur-range_dur)...(mean_dur+range_dur))
    
    // Setup initial toast spot
    var toastTemplate = toastLightTemplate
    var toastObjName = "toast_light"
    if toastType == "medium" {
        toastTemplate = toastMediumTemplate
        toastObjName = "toast_med"
    }
    if toastType == "dark" {
        toastTemplate = toastDarkTemplate
        toastObjName = "toast_dark"
    }
    
    if toastTemplate == nil {
        print("loading toast template")
        guard let toast = await loadFromRealityComposerPro(
            named: toastObjName,
            fromSceneNamed: "flying_toasters"
        ) else {
            fatalError("Error loading toast from Reality Composer Pro project.")
        }
        toastTemplate = toast
        
    }
    guard let toastTemplate = toastTemplate else {
        fatalError("Toast template is nil.")
    }
    
    let toast = toastTemplate.clone(recursive: true)
    toast.generateCollisionShapes(recursive: true)
    toast.name = "CToast\(toastNumber)"
    toastNumber += 1
    
    let toastScale = toastScales[toastType]!
    toast.scale = SIMD3<Float>(repeating: toastScale)
    toast.position = simd_float(start.vector + .init(x: 0, y: 0, z: -0.0))
    toast.transform.rotation = rotationQuaternion
    
    
    // Generate animation
    let line = FromToByAnimation<Transform>(
        name: "line",
        from: .init(scale: .init(repeating: toastScale),  rotation: rotationQuaternion, translation: simd_float(start.vector)),
        to: .init(scale: .init(repeating: toastScale),  rotation: rotationQuaternion, translation: simd_float(end.vector)),
        duration: anim_duration,
        bindTarget: .transform
    )
    
    let animation = try! AnimationResource
        .generate(with: line)
    

    toast.playAnimation(animation, transitionDuration: 1.0, startsPaused: false)
    toast.setMaterialParameterValues(parameter: "saturation", value: .float(0.0))
    toast.setMaterialParameterValues(parameter: "animate_texture", value: .bool(false))
    
    spaceOrigin.addChild(toast)

    
    // Schedule the removal of the entity after the animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + anim_duration) { [weak toast] in
        toast?.removeFromParent()
        screenSaverModel.currentNumberOfToasters -= 1
    }
    
    return toast
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
var toasters: [Entity] = []
var toasts: [Entity] = []

var toastMempoolLen = 30

/// The available animations inside the toaster asset.
enum ToasterAnimations {
    case flapWings
}

/// Toaster spawn parameters (in meters).
struct ToasterSpawnParameters {
    static var deltaX = -12.0*0.5
    static var deltaY = -9.0*0.5
    static var deltaZ = 12.1*0.5
    
    static var average_anim_duration = 5.0
    static var range_anim_duration = 3.0 // +/- average
}

var toasterScale : Float = 0.005
var toastScales : [String: Float] = [ "light": 1.0, "medium" : 1.0, "dark" : 0.3]

/// A counter that advances to the next toaster.
var toasterIndex = 0
var toastIndex = 0

/// A hand-picked selection of random starting parameters for the motion of the toasters.
var toasterPaths: [(Double, Double, Double)] = []

