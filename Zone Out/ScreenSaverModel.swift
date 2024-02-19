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

/// State that drives the different screens of the game and options that players select.
@Observable
class ScreenSaverModel {
    var isPlaying = false
    /// A Boolean value that indicates that game assets have loaded.
    var readyToStart = false
    
    static let gameTime = 35
    var timeLeft = gameTime
    
    /// Resets game state information.
    func reset() {
        isPlaying = false
        readyToStart = false
        timeLeft = ScreenSaverModel.gameTime
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
            toasterAnimations[.flapWings] = try .generate(with: AnimationView(source: def, trimStart: 0.0, trimEnd: 5.0))
            
            generateToasterMovementAnimations()
        
            
            self.readyToStart = true
        }
    }
    
    /// Preload animation assets.
    func generateToasterMovementAnimations() {
        for index in (0..<toasterPaths.count) {
            let start = Point3D(
                x: toasterPaths[index].0,
                y: toasterPaths[index].1,
                z: toasterPaths[index].2
            )
            let end = Point3D(
                x: start.x + ToasterSpawnParameters.deltaX,
                y: start.y + ToasterSpawnParameters.deltaY,
                z: start.z + ToasterSpawnParameters.deltaZ
            )
            let speed = ToasterSpawnParameters.speed
            
            let line = FromToByAnimation<Transform>(
                name: "line",
                from: .init(scale: .init(repeating: 1), translation: simd_float(start.vector)),
                to: .init(scale: .init(repeating: 1), translation: simd_float(end.vector)),
                duration: speed,
                bindTarget: .transform
            )
            
            let animation = try! AnimationResource
                .generate(with: line)
            
            toasterMovementAnimations.append(animation)
        }
    }
        
}
