//
//  ImmersiveView.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/17/24.
//

import SwiftUI
import RealityKit
import RealityKitContent


struct ImmersiveView: View {
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(ScreenSaverModel.self) var screenSaverModel
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        RealityView { content in
            // The root entity.
            content.add(spaceOrigin)
            content.add(cameraAnchor)
        }
        .onReceive(timer) { _ in
            var maxNumToSpawn = Int(screenSaverModel.numberOfToastersConfig) - screenSaverModel.currentNumberOfToasters
            if maxNumToSpawn > 1 {
                Task { @MainActor () -> Void in
                    do {
                        let spawnAmount = Int.random(in: 1...maxNumToSpawn)
                        for _ in (0..<spawnAmount) {
                            var _ = try await spawnToaster(screenSaverModel:screenSaverModel)
                            screenSaverModel.currentNumberOfToasters += 1
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
