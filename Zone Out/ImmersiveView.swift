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
            print("Time left \(screenSaverModel.timeLeft)")
            if screenSaverModel.timeLeft > 0 {
                screenSaverModel.timeLeft -= 1
                if (screenSaverModel.timeLeft % 5 == 0 || screenSaverModel.timeLeft == ScreenSaverModel.gameTime - 1) && screenSaverModel.timeLeft > 4 {
                    Task { @MainActor () -> Void in
                        do {
                            let spawnAmount = 3
                            for _ in (0..<spawnAmount) {
                                _ = try await spawnToaster()
                                try await Task.sleep(for: .milliseconds(300))
                            }
                            
                        } catch {
                            print("Error spawning a cloud:", error)
                        }
                        
                    }
                }
            } else if screenSaverModel.timeLeft == 0 {
                print("Game finished.")
                screenSaverModel.reset()
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
