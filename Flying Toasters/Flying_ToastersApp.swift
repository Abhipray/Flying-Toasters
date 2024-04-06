//
//  Zone_OutApp.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/17/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

@main
struct Flying_ToastersApp: App {
    @State private var screenSaverModel = ScreenSaverModel()
    
    init() {
        RealityKitContent.GestureComponent.registerComponent()
    }
    
    var body: some SwiftUI.Scene {
        WindowGroup("ScreenSavers", id: "main") {
            ContentView()
                .environment(screenSaverModel)
        }.defaultSize(width: 200, height:320)
            

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView().environment(screenSaverModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        WindowGroup(id: "VolumetricSpace") {
            ImmersiveView().environment(screenSaverModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 2, height: 2, depth: 2, in: .meters)
        
    }
    
}
