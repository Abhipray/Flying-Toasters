//
//  ContentView.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/17/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    
    
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(ScreenSaverModel.self) var screenSaverModel

    var body: some View {
        GeometryReader {geometry in
            VStack {
                @Bindable var screenSaverModel = screenSaverModel
                
                Text("Flying Toasters")
                
                Toggle(showImmersiveSpace ? "Stop" : "Start", isOn: $showImmersiveSpace)
                    .toggleStyle(.button)
                    .padding(.top, 50)

                
                // Display the number of toasters
                Text("Number of toasters: \(Int(screenSaverModel.numberOfToastersConfig))")
                    .padding()
                
                // Slider for choosing the number of toasters
                Slider(value: $screenSaverModel.numberOfToastersConfig, in: 10...20, step: 1)
                    .padding()
                
                // Display the toast level
                Text("Toast level: \(screenSaverModel.toastLevelConfig)")
                    .padding()
                
                // Dial (Picker) for choosing the toast level
                let toastLevels : Array = ["Light", "Medium", "Dark"]
                Picker("Toast Level", selection: $screenSaverModel.toastLevelConfig) {
                    ForEach(toastLevels, id: \.self) { toastLevel in
                        Text(toastLevel).tag(toastLevel)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: geometry.size.width * 0.4 ) // Adjust the frame to fit the picker nicely in your UI
                .clipped()
            }
            .padding()
            .onChange(of: showImmersiveSpace) { _, newValue in
                Task {
                    if newValue {
                        switch await openImmersiveSpace(id: "ImmersiveSpace") {
                        case .opened:
                            immersiveSpaceIsShown = true
                        case .error, .userCancelled:
                            fallthrough
                        @unknown default:
                            immersiveSpaceIsShown = false
                            showImmersiveSpace = false
                        }
                    } else if immersiveSpaceIsShown {
                        await dismissImmersiveSpace()
                        immersiveSpaceIsShown = false
                    }
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
