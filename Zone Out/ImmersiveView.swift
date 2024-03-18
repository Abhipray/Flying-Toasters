//
//  ImmersiveView.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/17/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

func rotationQuaternion(position: SIMD3<Float>) -> simd_quatf {
    // Target direction vector from position to the origin
    let targetDirection = normalize(simd_float3(0, 0, 0) - position)
    
    // Default forward direction in RealityKit for an entity is along -z
    let forwardDirection = simd_float3(0, 0, -1)
    
    // Calculate the rotation quaternion
    let dotProduct = dot(normalize(targetDirection), normalize(forwardDirection))
    let angle = acos(dotProduct)
    let axis = cross(normalize(targetDirection), normalize(forwardDirection))
    
    return simd_quatf(angle: angle, axis: normalize(axis))
}

struct ImmersiveView: View {
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(ScreenSaverModel.self) var screenSaverModel
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        RealityView { content in
            content.add(portalWorld)
            content.add(endPortal)
            content.add(startPortal)
            content.add(spaceOrigin)
            content.add(cameraAnchor)
        }
        .onReceive(timer) { _ in
            let maxAllowedToSpan = 4
            var maxNumToSpawn = Int(screenSaverModel.numberOfToastersConfig) - screenSaverModel.currentNumberOfToasters
            maxNumToSpawn = min(maxNumToSpawn, maxAllowedToSpan)
            if maxNumToSpawn > 1 {
                Task { @MainActor () -> Void in
                    do {
                        let spawnAmount = Int.random(in: 1...maxNumToSpawn)
                        for _ in (0..<spawnAmount) {
                            var _ = try await spawnToaster(screenSaverModel:screenSaverModel)
                            let toastType = screenSaverModel.toastTypes[screenSaverModel.toastLevelConfig]
                            var _ = try await spawnToast(screenSaverModel:screenSaverModel, toastType: toastType)
                            screenSaverModel.currentNumberOfToasters += 2
                        }
                    } catch {
                        print("Error spawning a toaster:", error)
                    }
                }
            }
        }
    }
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}

/// Loads assets from the local HappyBeamAssets package.
@MainActor
func loadFromRealityComposerPro(named entityName: String, fromSceneNamed sceneName: String) async -> Entity? {
    var entity: Entity? = nil
    do {
        let scene = try await Entity(named: sceneName, in: realityKitContentBundle)
        entity = scene.findEntity(named: entityName)
    } catch {
        print("Error loading \(entityName) from scene \(sceneName): \(error.localizedDescription)")
    }
    return entity
}
