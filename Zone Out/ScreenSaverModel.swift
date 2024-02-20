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

func calculateRotationAngle(from startPoint: SIMD3<Double>, to endPoint: SIMD3<Double>) -> Double {
    let directionVector = endPoint - startPoint
    let normalizedDirection = normalize(directionVector)
    
    let forwardVector = SIMD3<Double>(0, 0, -1) // Assuming forward is along the -z axis
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
    var isPlaying = false
    /// A Boolean value that indicates that game assets have loaded.
    var readyToStart = false
    
    var numberOfToastersConfig: Double = 10
    var toastLevelConfig: Int = 1
    
    var currentNumberOfToasters: Int = 0
    
    /// Resets game state information.
    func reset() {
        isPlaying = false
        readyToStart = false
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
            
//            generateToasterMovementAnimations()
        
            
            self.readyToStart = true
        }
    }
    
//    /// Preload animation assets.
//    func generateToasterMovementAnimations() {
//        let centralPoint = (x: 3.0, y: 3.0, z: -6.0)
//        let range: Double = 1
//        
//        for _ in 1...15 { // Generate 15 sample points
//            let x = Double.random(in: (centralPoint.x - range)...(centralPoint.x + range))
//            let y = Double.random(in: (centralPoint.y - range)...(centralPoint.y + range))
//            let z = Double.random(in: (centralPoint.z - range)...(centralPoint.z + range))
//            toasterPaths.append((Double(x), Double(y), Double(z)))
//        }
//        
//        
//        for index in (0..<toasterPaths.count) {
//            let start = Point3D(
//                x: toasterPaths[index].0,
//                y: toasterPaths[index].1,
//                z: toasterPaths[index].2
//            )
//            let end = Point3D(
//                x: start.x + ToasterSpawnParameters.deltaX,
//                y: start.y + ToasterSpawnParameters.deltaY,
//                z: start.z + ToasterSpawnParameters.deltaZ
//            )
//            let duration = ToasterSpawnParameters.duration
//            
//            // Rotation correction
//            // Calculate the rotation in radians (RealityKit uses radians, not degrees)
//            let degrees: Double = calculateRotationAngle(from: start.toSIMD3(), to: end.toSIMD3())
//            let radians = Float(degrees) * (Float.pi / 180)
//
//            // Create a quaternion for the rotation around the y-axis
//            let rotationQuaternion = simd_quatf(angle: radians, axis: [0, 1, 0])
//
//            
//            let line = FromToByAnimation<Transform>(
//                name: "line",
//                from: .init(scale: .init(repeating: toasterScale),  rotation: rotationQuaternion, translation: simd_float(start.vector)),
//                to: .init(scale: .init(repeating: toasterScale), rotation: rotationQuaternion, translation: simd_float(end.vector)),
//                duration: duration,
//                bindTarget: .transform
//            )
//            
//            let animation = try! AnimationResource
//                .generate(with: line)
//            
//            toasterMovementAnimations.append(animation)
//        }
//    }
    
}
