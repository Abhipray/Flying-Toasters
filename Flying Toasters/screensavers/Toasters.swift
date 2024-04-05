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
var moonEntity = Entity()
var toastNumber = 0
var toasterSrcPoint = simd_float3(x: 4.0, y: 3.0, z: -8.0)
var toasterEndPoint = simd_float3(x: -3.0, y: 0.5, z: -1.0)

/// Toaster spawn parameters (in meters).
struct ToasterSpawnParameters {
    static var average_anim_duration = 10.0
    static var range_anim_duration = 4.0 // +/- average
    
    static var average_speed : Float = 2.0
    static var range_speed : Float = 1.0
}

var toasterPortal : Entity? = nil

/// Generate a random point within a 2D circle in 3D space based on an entity's transform.
/// - Parameters:
///   - center: The center of the circle in global space (entity's position).
///   - radius: The radius of the circle.
///   - transform: The entity's transform.
/// - Returns: A random point within the circle in global 3D space.
func randomPointInCircle3D(center: SIMD3<Float>, radius: Float, transform: Transform) -> SIMD3<Float> {
    // Step 1: Generate a random angle and radius for the point within the 2D circle.
    let angle = Float.random(in: 0..<2 * .pi) // Random angle in radians
    let randomRadius = sqrt(Float.random(in: 0...1)) * radius // Uniform distribution
    
    // Step 2: Calculate the point's position in local space (relative to the circle's center).
    let localPoint = SIMD3<Float>(randomRadius * cos(angle), randomRadius * sin(angle), 0.3)
    
    // Step 3: Apply the circle's rotation to the point. This assumes `transform.rotation` is a simd_quatf.
    let rotatedPoint = transform.rotation.act(localPoint)
    
    // Step 4: Scale the point if needed (optional, depending on your application's needs).
    // This step is skipped in this example for simplicity, assuming the circle's scale is uniform and already considered.
    
    // Step 5: Translate the point by the circle's global position to get its position in global space.
    let globalPoint = rotatedPoint + center
    
    return globalPoint
}

func generateToasterStartEndRotation(prevLocation: simd_float3?) -> (simd_float3, simd_float3, simd_quatf) {
    let range: Float = 0.75
    let min_dist: Float = 0.5

    var start = randomPointInCircle3D(center: startPortal.position, radius: range, transform: startPortal.transform)
    if prevLocation != nil {
        // Enforce a minimum distance
        while (distance(start, prevLocation!) < min_dist) {
            start = randomPointInCircle3D(center: startPortal.position, radius: range, transform: startPortal.transform)
        }
    }
    
    let end = randomPointInCircle3D(center: endPortal.position, radius: range, transform: endPortal.transform)
    
    // Rotation correction
    // Calculate the rotation in radians (RealityKit uses radians, not degrees)
    let (rotationAxis, radians) = calculateRotationAngle(from: start, to: end)

    // Create a quaternion for the rotation
    let rotationQuaternion = simd_quatf(angle: radians, axis: rotationAxis)
    
    return (start, end, rotationQuaternion)
}

var velocityResetWorkItems = [String: DispatchWorkItem]()
var collidingToasters: [Entity] = [] // Assuming toasters is defined here


//@MainActor
//func handleCollisionStart(for event: CollisionEvents.Began) async throws {
//    // Unused
//        let toasterA = event.entityA.findTopLevelEntity(named: "CToaster")
//        let toasterB = event.entityB.findTopLevelEntity(named: "CToaster")
//        print("--- Collision ---", event.entityA.name, event.entityB.name)
//    
//        // Remove toaster from parent if collision with endPortal
//}

func randomFloat(in range: ClosedRange<Float>) -> Float {
    return Float.random(in: range)
}

// Function to create a random cubic Bezier curve
func createRandomCubicBezier() -> (controlPoint1: SIMD2<Float>, controlPoint2: SIMD2<Float>) {
    // Define the range for the control point coordinates
    let range : ClosedRange<Float> = 0.0...1.0
    
    // Generate random control points
    let controlPoint1 = SIMD2<Float>(randomFloat(in: range), randomFloat(in: range))
    let controlPoint2 = SIMD2<Float>(randomFloat(in: range), randomFloat(in: range))
    
    return (controlPoint1, controlPoint2)
}


/// Creates a toaster and places it in the space.
@MainActor
func spawnToaster(screenSaverModel: ScreenSaverModel, startLocation: simd_float3?, endLocation: simd_float3?, scale: Float, timing: AnimationTimingFunction?, prevLocation: simd_float3?) async throws -> (Entity, AnimationTimingFunction?) {
    print("Spawning a new toaster")
    
    var (start, end, rotationQuaternion) = generateToasterStartEndRotation(prevLocation: prevLocation)
    if startLocation != nil {
        start = startLocation!
    }
    if endLocation != nil {
        end = endLocation!
    }
    
    // Randomize speed/duration of animation
    let mean_dur = ToasterSpawnParameters.average_anim_duration
    let range_dur = ToasterSpawnParameters.range_anim_duration
    let anim_duration = Double.random(in: (mean_dur-range_dur)...(mean_dur+range_dur))
    
    let (controlPoint1, controlPoint2) = createRandomCubicBezier()
    let animationTiming : AnimationTimingFunction
    if timing == nil {
        animationTiming = .cubicBezier(controlPoint1: controlPoint1, controlPoint2: controlPoint2)
    } else {
        animationTiming = timing!
    }
    // Generate animation
    let line = FromToByAnimation<Transform>(
        name: "line",
        from: .init(scale: .init(repeating: scale),  rotation: rotationQuaternion, translation: start),
        to: .init(scale: .init(repeating: scale), rotation: rotationQuaternion, translation: end),
        duration: anim_duration,
        timing: animationTiming,
        isAdditive: false,
        bindTarget: .transform
    )
    
    let conclusion_time = 2.0
    // Lurch into portal with scaling down
    // find the point on the surface of the sphere that is closest to end
    let direction = normalize(end - moonEntity.position)
    let moon_radius = moonEntity.visualBounds(relativeTo: nil).extents.x
    let targetPoint = moonEntity.position + normalize(direction) * moon_radius
    let (rotationAxis, radians) = calculateRotationAngle(from:end, to:targetPoint)
    let final_rotation = simd_quatf(angle: radians, axis: rotationAxis)
    let final_transform = Transform(scale: .init(repeating: scale*0.02), rotation: final_rotation, translation: targetPoint)
    
    // Approach towards the Moon in the other world
    let conclusion_line = FromToByAnimation<Transform>(
        name: "line2",
        to: final_transform ,
        duration: conclusion_time,
        isAdditive: false,
        bindTarget: .transform
    )
    
    // Orbit moon animation
    let orbit_time = 4.0
    let orbit = OrbitAnimation(name: "orbit",
        duration: orbit_time,
        axis: moonEntity.position,
        startTransform: final_transform,
        orientToPath: true,
        bindTarget: .transform,
        repeatMode: .repeat)
    
    
    let animation_first = try! AnimationResource
        .generate(with: line)
    let animation_second = try! AnimationResource
        .generate(with: conclusion_line)
    let animation_third = try! AnimationResource
        .generate(with: orbit)
    let animation_sequence = try! AnimationResource.sequence(with: [animation_first, animation_second, animation_third])
    
    let toaster = toasters[toastIndex % toasters.count];
    toastIndex += 1;
    
    // Initial toaster configuration
    toaster.position = start
    toaster.transform.rotation = rotationQuaternion

    if let flyingToasterEntity = toaster.findEntity(named: "Flying_Toaster") as? ModelEntity {
        // Accessing ModelComponent
        if var modelComponent = flyingToasterEntity.components[ModelComponent.self] {
            // Iterate and modify materials
            for (index, material) in modelComponent.materials.enumerated() {
                if var physMaterial = material as? PhysicallyBasedMaterial {
                    // Example modification: changing the base color
//                    physMaterial.emissiveColor =  PhysicallyBasedMaterial.EmissiveColor(color: UIColor(screenSaverModel.toasterColor))
                    physMaterial.emissiveIntensity = 0.0
                    physMaterial.baseColor =  PhysicallyBasedMaterial.BaseColor(tint: UIColor(screenSaverModel.toasterColor))
                    physMaterial.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 1.0)
                    // Assign the modified material back
                    modelComponent.materials[index] = physMaterial
                }
            }
            // Since materials array is a struct (value type), reassign the modified array back to the component
            flyingToasterEntity.modelComponent?.materials = modelComponent.materials
        }
    }

    toaster.playAnimation(animation_sequence, transitionDuration: 0.1, startsPaused: false)
    toaster.setMaterialParameterValues(parameter: "saturation", value: .float(0.0))
    toaster.setMaterialParameterValues(parameter: "animate_texture", value: .bool(true))
    toaster.components[HoverEffectComponent.self] = HoverEffectComponent()
    

    if (screenSaverModel.ghostMode) {
        toaster.components[PhysicsBodyComponent.self]?.mode = .static
    } else {
        toaster.components[PhysicsBodyComponent.self]?.mode = .dynamic
    }
    
    
    toasterAnimate(toaster, kind: .flapWings, shouldRepeat: true)
    
    spaceOrigin.addChild(toaster)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + anim_duration) { [weak toaster] in
        // Remove from main world and put in second world
        toaster?.removeFromParent()
        portalWorld.addChild(toaster!, preservingWorldTransform: true)
    }
    
    // Schedule the removal of the entity after the second animation completes
    DispatchQueue.main.asyncAfter(deadline: .now() + anim_duration + conclusion_time + orbit_time) { [weak toaster] in
        if let childToRemove = toaster?.children.first(where: { $0.name == "speech" }) {
            childToRemove.removeFromParent()
        }
        toaster?.removeFromParent()
        screenSaverModel.currentNumberOfToasters -= 1
    }
    
    
    return (toaster, timing)
}

@MainActor
func spawnToast(screenSaverModel: ScreenSaverModel, toastType: String, startLocation: simd_float3?, endLocation: simd_float3?) async throws -> Entity {
    print("Spawning a new toast")
    
    var (start, end, _) = generateToasterStartEndRotation(prevLocation: nil)
    if startLocation != nil {
        start = startLocation!
    }
    if endLocation != nil {
        end = endLocation!
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
    toast.position = start
    toast.transform.rotation = rotationQuaternion
    toast.look(at:endPortal.position, from:startPortal.position, relativeTo: nil)
    
    if (screenSaverModel.ghostMode) {
        toast.components[PhysicsBodyComponent.self]?.mode = .static
    } else {
        toast.components[PhysicsBodyComponent.self]?.mode = .dynamic
    }
    
    // Generate animation
    let line = FromToByAnimation<Transform>(
        name: "line",
        from: .init(scale: .init(repeating: toastScale),  rotation: rotationQuaternion, translation: start),
        to: .init(scale: .init(repeating: toastScale),  rotation: rotationQuaternion, translation: end),
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
