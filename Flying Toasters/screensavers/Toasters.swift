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
import UIKit


/// The main toaster model; it's cloned when a new toaster spawns.
var toasterTemplate: Entity? = nil
var toastLightTemplate: Entity? = nil
var toastMediumTemplate: Entity? = nil
var toastDarkTemplate: Entity? = nil
var startPortal = Entity()
var endPortal = Entity()
var portalWorld = Entity()
var poemAttachment = Entity()
var toastNumber = 0
var toasterSrcPoint = (x: 4.0, y: 4.0, z: -6.0)

/// Toaster spawn parameters (in meters).
struct ToasterSpawnParameters {
    static var deltaX = -12.0*0.5
    static var deltaY = -9.0*0.5
    static var deltaZ = 12.1*0.5
    
    static var average_anim_duration = 9.0
    static var range_anim_duration = 3.0 // +/- average
}

var toasterEndPoint = simd_double(.init(
    x: toasterSrcPoint.x + ToasterSpawnParameters.deltaX,
    y: toasterSrcPoint.y + ToasterSpawnParameters.deltaY,
    z: toasterSrcPoint.z + ToasterSpawnParameters.deltaZ
))

var toasterPortal : Entity? = nil

func generateToasterStartEndRotation() -> (Point3D, Point3D, simd_quatf) {
    let centralPoint = Point3D(x:startPortal.position.x, y:startPortal.position.y, z:startPortal.position.z)
    let range: Double = 0.5
    

    let x = Double.random(in: (centralPoint.x - range)...(centralPoint.x + range))
    let y = Double.random(in: (centralPoint.y - range)...(centralPoint.y + range))
    let z = Double.random(in: (centralPoint.z - range)...(centralPoint.z + range))
    
    let start = Point3D(x:x, y:y, z:z)
    let end = Point3D(x: endPortal.position.x, y: endPortal.position.y, z: endPortal.position.z)
    
    // Rotation correction
    // Calculate the rotation in radians (RealityKit uses radians, not degrees)
    let (rotationAxis, radians) = calculateRotationAngle(from: start.toSIMD3(), to: end.toSIMD3())

    // Create a quaternion for the rotation around the y-axis
    let rotationQuaternion = simd_quatf(angle: radians, axis: rotationAxis)
    
    return (start, end, rotationQuaternion)
}

/// Creates a toaster and places it in the space.
@MainActor
func spawnToaster(screenSaverModel: ScreenSaverModel, startLocation: simd_float3?, endLocation: simd_float3?, scale: Float) async throws -> Entity {
    print("Spawning a new toaster")
    
    var (start, end, rotationQuaternion) = generateToasterStartEndRotation()
    if startLocation != nil {
        start = Point3D(startLocation!)
    }
    if endLocation != nil {
        end = Point3D(endLocation!)
    }
    
    // Randomize speed/duration of animation
    let mean_dur = ToasterSpawnParameters.average_anim_duration
    let range_dur = ToasterSpawnParameters.range_anim_duration
    let anim_duration = Double.random(in: (mean_dur-range_dur)...(mean_dur+range_dur))
    
    
    // Generate animation
    let line = FromToByAnimation<Transform>(
        name: "line",
        from: .init(scale: .init(repeating: scale),  rotation: rotationQuaternion, translation: simd_float(start.vector)),
        to: .init(scale: .init(repeating: scale), rotation: rotationQuaternion, translation: simd_float(end.vector)),
        duration: anim_duration,
        bindTarget: .transform
    )
    
    let animation = try! AnimationResource
        .generate(with: line)
    
    let toaster = toasters[toastIndex % toasters.count];
    toastIndex += 1;
    
    toaster.position = simd_float(start.vector + .init(x: 0, y: 0, z: -0.0))
    toaster.transform.rotation = rotationQuaternion

    if let flyingToasterEntity = toaster.findEntity(named: "Flying_Toaster") as? ModelEntity {
        // Accessing ModelComponent
        if var modelComponent = flyingToasterEntity.components[ModelComponent.self] {
            // Iterate and modify materials
            for (index, material) in modelComponent.materials.enumerated() {
                if var physMaterial = material as? PhysicallyBasedMaterial {
                    // Example modification: changing the base color
//                    physMaterial.baseColor = PhysicallyBasedMaterial.BaseColor(tint: .green)
                    physMaterial.emissiveColor =  PhysicallyBasedMaterial.EmissiveColor(color: UIColor(screenSaverModel.toasterColor))
                    // Assign the modified material back
                    modelComponent.materials[index] = physMaterial
                }
            }
            // Since materials array is a struct (value type), reassign the modified array back to the component
            flyingToasterEntity.modelComponent?.materials = modelComponent.materials
        }
    }

    toaster.playAnimation(animation, transitionDuration: 1.0, startsPaused: false)
    toaster.setMaterialParameterValues(parameter: "saturation", value: .float(0.0))
    toaster.setMaterialParameterValues(parameter: "animate_texture", value: .bool(true))
    
    toasterAnimate(toaster, kind: .flapWings, shouldRepeat: true)
    
    spaceOrigin.addChild(toaster)
    
    // Schedule the removal of the entity after the animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + anim_duration) { [weak toaster] in
        if let childToRemove = toaster?.children.first(where: { $0.name == "speech" }) {
            childToRemove.removeFromParent()
        }
        toaster?.removeFromParent()
        screenSaverModel.currentNumberOfToasters -= 1
    }
    
    
    return toaster
}

@MainActor
func spawnToast(screenSaverModel: ScreenSaverModel, toastType: String, startLocation: simd_float3?, endLocation: simd_float3?) async throws -> Entity {
    print("Spawning a new toast")
    
    var (start, end, _) = generateToasterStartEndRotation()
    if startLocation != nil {
        start = Point3D(startLocation!)
    }
    if endLocation != nil {
        end = Point3D(endLocation!)
    }
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
    toast.look(at:endPortal.position, from:startPortal.position, relativeTo: nil)
    
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



var toasterScale : Float = 0.005
var toastScales : [String: Float] = [ "light": 1.0, "medium" : 1.0, "dark" : 0.3]

/// A counter that advances to the next toaster.
var toasterIndex = 0
var toastIndex = 0

/// A hand-picked selection of random starting parameters for the motion of the toasters.
var toasterPaths: [(Double, Double, Double)] = []

var toasterPhrashes: [String] = ["Crust me, I'm flying!", "Bread to be wild!", "I'm on a roll!", "Toasty skies ahead!", "Butter believe it!", "Leaven the dream!", "Flour power!", "Born to be bread!", "Flying on yeast wings!", "Bun voyage!", "Spread the joy!", "Crumb and get it!", "Loafing around!", "A toast to you!", "Breadwinner in the sky!", "Sky's the limit!", "Yeasty rider!", "Seize the baguette!", "Sourdough solo!", "High in fiber!", "Rising high!", "Wheat me up!", "Grainiac in flight!", "Flap like a flapjack!", "Let's get this bread!", "Doughn't stop me now!", "Muffin compares to you!", "Gluten tag!", "Crumb believe in yourself!", "Pita patter, let's get at 'er!", "Bready for anything!", "Loaf is all you knead!", "In crust we trust!", "This is un-bread-able!", "A toastmaster!", "Biscuit in the basket!", "Roll with it!", "Donut worry, be happy!", "Egg-cited to fly!", "Pan-demonium!", "Bake my day!", "Rye so serious?", "A slice of heaven!", "Ciabatta believe it!", "Flour child!", "Bagel in the sky!", "Jumpin' jam!", "Croissant the skies!", "Bread head!", "Toast of the town!", "Sizzle with pizzazz!", "Sky-high ciabatta!", "Jam-packed flight!", "Rising above clouds!", "I knead speed!", "Butter up, buttercup!", "Dough-lightful heights!", "Fueled by crumbs!", "Bready for lift-off!", "Toasting new heights!", "Crumb-coated dreams!", "Fluffy cloud rider!", "Wheat's up, sky?", "Soaring on sourdough!", "Crusty but gusty!", "Aerodynamic baguette!", "Sky's the yeast limit!", "Biscotti in the jet stream!", "Crouton cruisin'!", "Brioche breeze!", "Bagel balloon!", "Glaze the trail!", "Pumpernickel propeller!", "Muffin much, just flying!", "Toast taking off!", "Pastry pilot!", "Sky scraping crêpes!", "Scone into the blue!", "Airborne and cornbread!", "Naan stop fun!", "Croissant the skies!", "Bread blimp!", "Flying focaccia!", "Pretzel propeller!", "Rolling in the dough!", "Eclairs in the air!", "Baking altitude!", "Panini planes!", "High-altitude hoagie!", "Donut drop me!", "Chapati charters!", "Flight of the flatbreads!", "Aloft on a loaf!", "Swift as a scone!", "Bun, two, three, lift!", "Toast and coast!", "Baguette brigade!", "Danish daredevil!", "Angel food flight!", "Cloudy with a chance of bread!", "Seize the crumb!", "Rise, shine, and bake!", "Knead to focus!", "Chill like dough", "Sourdough & unwind", "Proofing patience", "Bake, break, repeat", "Flourish in the slow", "Mix well, live well", "Rest, then zest", "Dough not hurry", "Crust your process", "Breathe & bake", "Loaf & learn", "Pace your bake", "Yeast of efforts", "Crumb together", "Sift through priorities", "Mold your day", "Toast to tranquility", "Layer your tasks", "Sprinkle joy", "Whisk away worries", "Batter up for success", "Cool on the rack", "Rising routine", "Spread calm", "Fold in fun", "Grain of motivation", "Slice of serenity", "Bun-dle tasks", "Roll out plans", "Proof of progress", "Rest the dough, rest the mind", "Knead, then knead not", "Flake off stress", "Savor the moment", "Glaze goals gently", "Dust off doubts", "Crumble concerns", "Butter up your brain", "Preserve peace", "Measure, mix, meditate", "Pan out smoothly", "Stir in positivity", "Balance the batch", "Align the almonds", "Pitcher of possibilities", "Temper tasks", "Whip up wellness"]
