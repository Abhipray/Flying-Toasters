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

    var body: some View {
        Text("\(secondsElapsed) seconds")
            .onReceive(timer) { _ in
                secondsElapsed += 1
            }
            .font(.title)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    TimerView()
}
