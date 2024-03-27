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

private var user_pos = simd_float3(0,0,0)

struct ImmersiveView: View {
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(ScreenSaverModel.self) var screenSaverModel
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var showImmersiveSpace = true
    
    var tap: some Gesture {
        TapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                // Access the tapped entity here.
                if value.entity.name.starts(with: "CToast") {
                    let toaster = value.entity
                    if toaster.children.first(where: { $0.name == "speech" }) != nil {
                        return
                    }
                    let idx = Int.random(in: 0...toasterPhrashes.count-1)
                    let text = ModelEntity(mesh: .generateText(toasterPhrashes[idx],
                                                               extrusionDepth: 0.1,
                                                               font: .boldSystemFont(ofSize: 12)))
                    text.model?.materials = [UnlitMaterial(color:.magenta)]
                    text.name = "speech"
                    
                    let toasterHeight = value.entity.visualBounds(relativeTo: nil).extents.y * 100 + 5 // in cm
                    let toasterWidth = value.entity.visualBounds(relativeTo: nil).extents.x * 100/2 + 5 // in cm
                    text.position = [toasterWidth, toasterHeight, 0.0]
                    text.look(at:user_pos, from:text.position, relativeTo: nil)
                    value.entity.addChild(text)
                }
            }
    }
    
    var body: some View {
        RealityView { content, attachments in
            content.add(portalWorld)
            content.add(endPortal)
            content.add(startPortal)
            content.add(spaceOrigin)
            content.add(cameraAnchor)
            if let earthAttachment = attachments.entity(for: "h1") {
                earthAttachment.position = [0, -1.5, 0]
                startPortal.addChild(earthAttachment)
            }
            
        } attachments: {
            Attachment(id: "h1") {
                Text("Dismiss Screen Saver").font(.system(size: 60, weight: .bold, design: .monospaced))
                Toggle(isOn: $showImmersiveSpace) {
                    Image(systemName: showImmersiveSpace ? "eye.slash" : "eye")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200) // Specify the frame to increase the size
                        .clipShape(Circle())
                }
                .onAppear {
                    showImmersiveSpace = screenSaverModel.isScreenSaverRunning
                }
                .toggleStyle(.button)
                .help("Start or stop preview of the Screen Saver")
                .onChange(of: showImmersiveSpace) { _, newValue in
                    screenSaverModel.handleImmersiveSpaceChange(newValue: newValue)
                }
                .onChange(of: screenSaverModel.isScreenSaverRunning) {_,newValue in
                    showImmersiveSpace = newValue;
                }
                .padding()
            }
        }
        .installGestures()
        .gesture(tap)
        .onReceive(timer) { _ in
            let probFamily = 0.3
            let maxAllowedToSpan = 4
            let numBabies = 3
            var maxNumToSpawn = Int(screenSaverModel.numberOfToastersConfig) - screenSaverModel.currentNumberOfToasters
            maxNumToSpawn = min(maxNumToSpawn, maxAllowedToSpan)
            
            var family = false
            let randomValue = Double.random(in: 0...1)
            if randomValue < probFamily {
                family = true
            }
            if maxNumToSpawn > 1 {
                Task { @MainActor () -> Void in
                    do {
                        let spawnAmount = Int.random(in: 1...maxNumToSpawn)
                        for _ in (0..<spawnAmount) {
                            let mother = try await spawnToaster(screenSaverModel:screenSaverModel,  startLocation: nil, endLocation: nil, scale:toasterScale)
                            try await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
                            
                            if family {
                                for _ in 1...numBabies {
                                    let _ = try await spawnToaster(screenSaverModel:screenSaverModel, startLocation: mother.position, endLocation: endPortal.position, scale: toasterScale*0.4)
                                    try await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
                                }
                                screenSaverModel.currentNumberOfToasters += numBabies
                                family = false
                            }
                            
                            let toastType = screenSaverModel.toastTypes[screenSaverModel.toastLevelConfig]
                            let _ = try await spawnToast(screenSaverModel:screenSaverModel, toastType: toastType, startLocation: nil, endLocation: nil)
                            screenSaverModel.currentNumberOfToasters += 2
                            try await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
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
