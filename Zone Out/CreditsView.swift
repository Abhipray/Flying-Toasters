//
//  CreditsView.swift
//  Zone Out
//
//  Created by Abhipray Sahoo on 2/19/24.
//

import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Credits")
                .font(.title)
                .fontWeight(.bold)

            Text("Music by Melissa Elliott, 0xabad1dea, soundcloud.com")

            Text("Toaster 3D model based on Flying Toaster by @fiveiron, printables.com")

            Button("Dismiss") {
                dismiss() // Dismiss the credits sheet
            }
            .padding()
            .cornerRadius(10)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
    }
}

#Preview {
    CreditsView()
}
