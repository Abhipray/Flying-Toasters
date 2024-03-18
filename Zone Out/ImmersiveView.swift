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
    
    @MainActor
    public func getStarfieldEntity() async throws -> Entity {
        // Create a material with a star field on it.
        guard let resource = try? await TextureResource(named: "Starfield") else {
            // If the asset isn't available, something is wrong with the app.
            fatalError("Unable to load starfield texture.")
        }
        var material = UnlitMaterial()
        material.color = .init(texture: .init(resource))

        // Attach the material to a large sphere.
        let entity = Entity()
        entity.components.set(ModelComponent(
            mesh: .generateSphere(radius: 1000),
            materials: [material]
        ))

        // Ensure the texture image points inward at the viewer.
        entity.scale *= .init(x: -1, y: 1, z: 1)
        return entity
    }
    
    public func makeWorld() -> Entity {
        let world = Entity()
        world.components[WorldComponent.self] = .init()
        
        let environment = try! EnvironmentResource.load(named: "OuterSpace")
        world.components[ImageBasedLightComponent.self] = .init(source: .single(environment), intensityExponent: 6)
        world.components[ImageBasedLightReceiverComponent.self] = .init(imageBasedLight: world)
        
        Task { @MainActor in
            let sky = try await getStarfieldEntity()
            world.addChild(sky)
        }
        
        return world
    }
    
    public func makePortal(world: Entity) -> Entity {
        let portal = Entity()
        
        portal.components[ModelComponent.self] = .init(mesh: .generatePlane(width: 2, height: 2, cornerRadius: 1), materials: [PortalMaterial()])
        portal.components[PortalComponent.self] = .init(target: world)
        let particleEntity = Entity()

        var particles = ParticleEmitterComponent.Presets.magic
        particles.mainEmitter.color = .evolving(start: .single(.white), end: .single(.blue))
        particles.emitterShape = ParticleEmitterComponent.EmitterShape.plane
        particles.emitterShapeSize = SIMD3<Float>(x: 1.0, y: 1.0, z: 1.0)
        particles.particlesInheritTransform = true
        
        
        particleEntity.components[ParticleEmitterComponent.self] = particles
        portal.addChild(particleEntity)
        
        return portal
    }
    
    var body: some View {
        RealityView { content in
            content.add(spaceOrigin)
            content.add(cameraAnchor)
            
            let world = makeWorld()
            content.add(world)
            
            
            // Start portal
            let portal = makePortal(world: world)
            let translate = 0.0
            let start_pos = simd_float(.init(x:toasterSrcPoint.x-translate, y:toasterSrcPoint.y-translate, z:toasterSrcPoint.z-translate))
            portal.position = start_pos
            
            let end = simd_float(.init(
                x: toasterSrcPoint.x + ToasterSpawnParameters.deltaX,
                y: toasterSrcPoint.y + ToasterSpawnParameters.deltaY,
                z: toasterSrcPoint.z + ToasterSpawnParameters.deltaZ
            ))
            let end_double = simd_double(.init(
                x: toasterSrcPoint.x + ToasterSpawnParameters.deltaX,
                y: toasterSrcPoint.y + ToasterSpawnParameters.deltaY,
                z: toasterSrcPoint.z + ToasterSpawnParameters.deltaZ
            ))
            
            let start = Point3D(x:toasterSrcPoint.x, y:toasterSrcPoint.y, z:toasterSrcPoint.z)
            let degrees = calculateRotationAngle(from:start.toSIMD3(), to:end_double)
            let radians = Float(degrees) * (Float.pi / 180)

            // Create a quaternion for the rotation around the y-axis
            let rotationQuaternion =  simd_quatf(angle: radians, axis: [0, 1, 0])
            portal.transform.rotation = rotationQuaternion
            content.add(portal)
            
        
            let end_portal = makePortal(world: world)
            end_portal.position = end + simd_float(.init(
                x: ToasterSpawnParameters.deltaX*0.1,
                y: ToasterSpawnParameters.deltaY*0.1,
                z: ToasterSpawnParameters.deltaZ*0.1
            ))
            end_portal.transform.rotation = simd_quatf(angle: Float.pi/2-radians, axis: [0, 1, 0])
            
            // Create a quaternion for the rotation around the y-axis
            content.add(end_portal)
                    
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
