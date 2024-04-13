//
//  ImmersiveView.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/17/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Combine

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

@Observable class VisionProPose {
    let session = ARKitSession()
    let worldTracking = WorldTrackingProvider()
    
    func runArSession() async {
        Task {
            try? await session.run([worldTracking])
        }
    }

    func getTransform() async -> simd_float4x4? {
        guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: 1)
        else { return nil }
    
        let transform = deviceAnchor.originFromAnchorTransform
        return transform
    }
}

struct ImmersiveView: View {
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(ScreenSaverModel.self) var screenSaverModel
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var showImmersiveSpace = true
    
    @State var sceneUpdateSubscription : Cancellable? = nil
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()
    @State private var prevToasterStart : simd_float3? = nil
    
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
                    print("Tap tap@")
                    
                    let scale : Float = screenSaverModel.useImmersiveDisplay ? 1.0 : volumetricToImmersionRatio
                    let idx = Int.random(in: 0...toasterPhrashes.count-1)
                    let text = ModelEntity(mesh: .generateText(toasterPhrashes[idx],
                                                               extrusionDepth: 0.0,
                                                               font: .monospacedSystemFont(ofSize: CGFloat(0.05*scale), weight: .light)))
                    text.model?.materials = [UnlitMaterial(color:.white)]
                    let textHeight = text.visualBounds(relativeTo: nil).extents.y
                    let textWidth = text.visualBounds(relativeTo: nil).extents.x
                    

                    // Create a plane for the bubble background. Using a plane as an approximation.
                    let bubbleMesh = MeshResource.generatePlane(width: textWidth+(0.1*scale), height: textHeight+(0.1*scale), cornerRadius: 0.1*scale)
                    let bubbleMaterial = SimpleMaterial(color: .black, isMetallic: false)
                    let bubbleEntity = ModelEntity(mesh: bubbleMesh, materials: [bubbleMaterial])
                    bubbleEntity.name = "speech"

                    // Position the bubble behind and centered on the text
                    text.position = SIMD3<Float>(-textWidth/2, -textHeight/2, 0.01*scale) // Slightly behind the text

                    // Add the text entity as a child of the bubble entity
                    bubbleEntity.addChild(text)
                    
                    let toasterHeight = toaster.visualBounds(relativeTo: nil).extents.y
                    let toasterWidth = toaster.visualBounds(relativeTo: nil).extents.x

                    
                    if screenSaverModel.useImmersiveDisplay {
                        bubbleEntity.position = toaster.position
                        bubbleEntity.position.y += toasterHeight + 0.05*scale
                        bubbleEntity.position.x -= toasterWidth/2
                        let direction = normalize(user_pos - bubbleEntity.position)
                        let rotationQuaternion = simd_quatf(from: [0, 0, 1], to: direction)
                        bubbleEntity.orientation = rotationQuaternion
                        toaster.addChild(bubbleEntity, preservingWorldTransform: true)
                    } else {
                        bubbleEntity.position = [0,0,0]
                        toaster.addChild(bubbleEntity, preservingWorldTransform: true)
                        print(toaster.position)
                    }
                    print("Added a speech bubble")
                }
            }
    }
    
    var body: some View {
        RealityView { content, attachments in
            try? await session.run([worldInfo])
            spaceOrigin.addChild(portalWorld)
            spaceOrigin.addChild(endPortal)
            spaceOrigin.addChild(startPortal)
            content.add(spaceOrigin)
            content.add(cameraAnchor)
            
            if !screenSaverModel.useImmersiveDisplay {
                spaceOrigin.position.y -= 0.5
            }
            
            if let earthAttachment = attachments.entity(for: "h1") {
                earthAttachment.position = [0, -1.5, 0]
                startPortal.addChild(earthAttachment)
            }
            
            sceneUpdateSubscription =
                content.subscribe(to: SceneEvents.Update.self) {event in
                    if screenSaverModel.useImmersiveDisplay {
                        guard let pose =
                                worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
                        else { return }
                        let toDeviceTransform = pose.originFromAnchorTransform
                        let devicePosition = toDeviceTransform.translation
                        user_pos = devicePosition
                    }
                } as? any Cancellable
            
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
            let maxAllowedToSpan = 2
            let numBabies = 2
            var maxNumToSpawn = Int(screenSaverModel.numberOfToastersConfig) - screenSaverModel.currentNumberOfToasters
            maxNumToSpawn = min(maxNumToSpawn, maxAllowedToSpan)
            
            var family = false
            let randomValue = Double.random(in: 0...1)
            if randomValue < probFamily {
                family = true
            }
            
            let motherScale = screenSaverModel.useImmersiveDisplay ? toasterScale : toasterScale * volumetricToImmersionRatio
            
            if maxNumToSpawn >= 1 {
                Task { @MainActor () -> Void in
                    do {
                        let spawnAmount = Int.random(in: 1...maxNumToSpawn)
                        for _ in (0..<spawnAmount) {
                            let (mother, mother_timing) = try await spawnToaster(screenSaverModel:screenSaverModel,  startLocation: nil, endLocation: nil, scale:motherScale, timing: nil, prevLocation: prevToasterStart)
                            prevToasterStart = mother.position
                            startPortal.children[0].components[ParticleEmitterComponent.self]?.burst()
                            
                            try await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
                            
                            if family {
                                for _ in 1...numBabies {
                                    let _ = try await spawnToaster(screenSaverModel:screenSaverModel, startLocation: prevToasterStart, endLocation: endPortal.position, scale: motherScale*0.4, timing: mother_timing, prevLocation: prevToasterStart)
                                    try await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
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
        .onDisappear(perform: {
            screenSaverModel.handleImmersiveSpaceChange(newValue: false)
        })
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
