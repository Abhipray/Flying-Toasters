//
//  Zone_OutApp.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/17/24.
//

import SwiftUI
import RealityKit

@main
struct Zone_OutApp: App {
    @State private var screenSaverModel = ScreenSaverModel()
    
    var body: some SwiftUI.Scene {
        WindowGroup("ScreenSavers", id: "main") {
            ContentView()
                .environment(screenSaverModel)
        }.defaultSize(width: 500, height:900)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView().environment(screenSaverModel)
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
    
}
