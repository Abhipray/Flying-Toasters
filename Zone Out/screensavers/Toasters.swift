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

/// Creates a toaster and places it in the space.
@MainActor
func spawnToaster() async throws -> Entity {
    print("Spawning a new toaster")
    let start = Point3D(
        x: toasterPaths[toasterPathsIndex].0,
        y: toasterPaths[toasterPathsIndex].1,
        z: toasterPaths[toasterPathsIndex].2
    )
    
    let toaster = try await spawnToasterExact(
        start: start,
        end: .init(
            x: start.x + ToasterSpawnParameters.deltaX,
            y: start.y + ToasterSpawnParameters.deltaY,
            z: start.z + ToasterSpawnParameters.deltaZ
        ),
        speed: ToasterSpawnParameters.duration
    )
    
    // Needs to increment *after* spawnToasterExact()
    toasterPathsIndex += 1
    toasterPathsIndex %= toasterPaths.count
    
    return toaster
}

/// Storage for each of the linear toaster movement animations.
var toasterMovementAnimations: [AnimationResource] = []

/// Places a toaster in the scene and sets it on a set journey.
@MainActor
func spawnToasterExact(start: Point3D, end: Point3D, speed: Double) async throws -> Entity {
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
    
    
    let animation = toasterMovementAnimations[toasterPathsIndex]

    toaster.playAnimation(animation, transitionDuration: 1.0, startsPaused: false)
    toaster.setMaterialParameterValues(parameter: "saturation", value: .float(0.0))
    toaster.setMaterialParameterValues(parameter: "animate_texture", value: .bool(false))
    
    toasterAnimate(toaster, kind: .flapWings, shouldRepeat: true)
    
    spaceOrigin.addChild(toaster)
    
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
//    static var deltaX = -4.0
//    static var deltaY = -1.5
//    static var deltaZ = 0.5
    
    static var duration = 5.0
}

var toasterScale : Float = 0.005

/// A counter that advances to the next toaster path.
var toasterPathsIndex = 0

/// A hand-picked selection of random starting parameters for the motion of the toasters.
var toasterPaths: [(Double, Double, Double)] = [
//    (x: 1.757_231_498_429_01, y: 1.911_673_694_896_59, z: -8.094_368_331_589_704),
//    (x: -0.179_269_237_592_594_17, y: 1.549_268_306_906_908_4, z: -7.254_713_426_424_875),
//    (x: -0.013_296_800_013_828_491, y: 2.147_766_026_068_617_8, z: -8.601_541_438_900_849),
//    (x: 2.228_704_746_539_703, y: 0.963_797_733_336_365_2, z: -7.183_621_312_117_454),
//    (x: -0.163_925_123_812_864_4, y: 1.821_619_897_406_197, z: -8.010_893_563_433_282),
//    (x: 0.261_716_575_589_896_03, y: 1.371_932_443_334_715, z: -7.680_206_361_333_17),
//    (x: 1.385_410_631_256_254_6, y: 1.797_698_998_556_775_5, z: -7.383_548_882_448_866),
//    (x: -0.462_798_470_454_367_4, y: 1.431_650_092_907_264_4, z: -7.169_154_476_151_876),
//    (x: 1.112_766_805_791_563, y: 0.859_548_406_627_492_2, z: -7.147_229_496_720_969),
//    (x: 1.210_194_536_657_374, y: 0.880_254_638_358_228_8, z: -8.051_132_737_691_349),
//    (x: 0.063_637_772_899_141_52, y: 1.973_172_635_040_014_7, z: -8.503_837_407_474_947),
//    (x: 0.883_082_630_134_997_2, y: 1.255_268_496_843_653_4, z: -7.760_994_300_660_705),
//    (x: 0.891_719_821_716_725_7, y: 2.085_000_111_104_786_7, z: -8.908_048_018_555_112),
//    (x: 0.422_260_067_132_894_2, y: 1.370_335_319_771_187, z: -7.525_853_388_894_509),
//    (x: 0.473_470_811_107_753_46, y: 1.864_930_149_962_240_6, z: -8.164_641_191_459_626)
//    (x: 2.0, y: 2.5, z: -8.0),
//    (x: 2.5, y: 2.7, z: -7.5),
//    (x: 2.2, y: 2.6, z: -8.1),
//    (x: 2.3, y: 2.8, z: -7.8),
//    (x: 2.1, y: 2.9, z: -8.2)
]

