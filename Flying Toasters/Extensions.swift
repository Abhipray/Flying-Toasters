/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Extensions and utilities.
*/

import SwiftUI
import RealityKit
import ObjectiveC

extension Entity {
    /// Property for getting or setting an entity's `modelComponent`.
    var modelComponent: ModelComponent? {
        get { components[ModelComponent.self] }
        set { components[ModelComponent.self] = newValue }
    }
    
    var descendentsWithModelComponent: [Entity] {
        var descendents = [Entity]()
        
        for child in children {
            if child.components[ModelComponent.self] != nil {
                descendents.append(child)
            }
            descendents.append(contentsOf: child.descendentsWithModelComponent)
        }
        return descendents
    }
}

private var fromToByAnimationKey: UInt8 = 0

extension Entity {
    func setMaterialParameterValues(parameter: String, value: MaterialParameters.Value) {
        let modelEntities = descendentsWithModelComponent
        for entity in modelEntities {
            if var modelComponent = entity.modelComponent {
               
                modelComponent.materials = modelComponent.materials.map {
                    
                    guard var material = $0 as? ShaderGraphMaterial else { return $0 }
                    if material.parameterNames.contains(parameter) {
                        do {
                            try material.setParameter(name: parameter, value: value)
                        } catch {
                            print("Error setting parameter: \(error.localizedDescription)")
                        }
                    }
                    return material
                }
                entity.modelComponent = modelComponent
            }
        }
    }
    
    subscript(parentMatching targetName: String) -> Entity? {
        if name.contains(targetName) {
            return self
        }
        
        guard let nextParent = parent else {
            return nil
        }
        
        return nextParent[parentMatching: targetName]
    }
    
    func getParent(nameBeginsWith name: String) -> Entity? {
        if self.name.hasPrefix(name) {
            return self
        }
        guard let nextParent = parent else {
            return nil
        }
        
        return nextParent.getParent(nameBeginsWith: name)
    }
    
    /// Finds the top-level entity with a name that matches or starts with the given string in the entity's hierarchy.
    /// - Parameter nameStart: The string to match the beginning of the entity's name.
    /// - Returns: The top-level entity with a matching name if found; otherwise, nil.
    func findTopLevelEntity(named nameStart: String) -> Entity? {
        // Start with the current entity.
        var currentEntity: Entity? = self
        
        // Traverse up the hierarchy.
        while let parent = currentEntity {
            if parent.name.starts(with: nameStart) {
                // If the parent entity's name matches the criteria, return it.
                return parent
            }
            currentEntity = parent.parent
        }
        
        // If no matching entity is found in the hierarchy above the current entity,
        // check if the current entity itself matches the criteria.
        if self.name.starts(with: nameStart) {
            return self
        }
        
        // If the loop exits without finding a matching entity, return nil.
        return nil
    }
    
    func getParent(withName name: String) -> Entity? {
        if self.name == name {
            return self
        }
        guard let nextParent = parent else {
            return nil
        }
        
        return nextParent.getParent(withName: name)
    }
    
    subscript(descendentMatching targetName: String) -> Entity? {
        if name.contains(targetName) {
            return self
        }
        
        var match: Entity? = nil
        for child in children {
            match = child[descendentMatching: targetName]
            if let match = match {
                return match
            }
        }
        
        return match
    }
    
    func getSelfOrDescendent(withName name: String) -> Entity? {
        if self.name == name {
            return self
        }
        var match: Entity? = nil
        for child in children {
            match = child.getSelfOrDescendent(withName: name)
            if match != nil {
                return match
            }
        }
        
        return match
    }
    
    func forward(relativeTo referenceEntity: Entity?) -> SIMD3<Float> {
        normalize(convert(direction: SIMD3<Float>(0, 0, +1), to: referenceEntity))
    }
    
    var forward: SIMD3<Float> {
        forward(relativeTo: nil)
    }
    
    var fromToByAnimation: FromToByAnimation<Transform>? {
        get {
            objc_getAssociatedObject(self, &fromToByAnimationKey) as? FromToByAnimation<Transform>
        }
        set {
            objc_setAssociatedObject(self, &fromToByAnimationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}

extension Point3D {
    func toSIMD3() -> SIMD3<Double> {
        return SIMD3<Double>(x, y, z)
    }
}

extension simd_float4x4 {
    var translation : simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
    var upper3x3 : simd_float3x3 {
       return simd_float3x3(columns.0.float3, columns.1.float3, columns.2.float3)
    }
}

extension simd_float4 {
    var float3 : simd_float3 {
        return simd_float3(x,y,z)
    }
}
