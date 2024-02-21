//
//  TimerView.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/20/24.
//

import SwiftUI

struct TimerView: View {
    @State private var secondsElapsed = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var selectedIncrement = 1 // Default to 15 minutes
    @State private var customTimeout = 15
    @State private var useCustomTimeout = false
    
    let increments = [("15 Minutes", 15), ("30 Minutes", 30), ("1 Hour", 60), ("2 Hours", 120)]

    var body: some View {
        VStack {
            Text("\(secondsElapsed) seconds")
                .onReceive(timer) { _ in
                    secondsElapsed += 1
                }
                .font(.title)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
                Picker("Start Screen Saver when inactive for", selection: $selectedIncrement) {
                    ForEach(0..<increments.count) {
                        Text(self.increments[$0].0).tag($0)
                    }
                }
        }
    }
}

#Preview {
    TimerView()
}
