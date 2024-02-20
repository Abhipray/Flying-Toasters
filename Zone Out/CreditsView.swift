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
                .foregroundColor(.black) // Ensure text color contrasts with background

            Text("App developed by Your Name")
                .foregroundColor(.black) // Change text color

            Text("Icons and graphics provided by Designer Name")
                .foregroundColor(.black) // Change text color

            Text("Special thanks to...")
                .foregroundColor(.black) // Change text color

            Button("Dismiss") {
                dismiss() // Dismiss the credits sheet
            }
            .foregroundColor(.blue) // Button text color
            .padding()
            .cornerRadius(10)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white) // Background color of the entire view
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
    }
}

#Preview {
    CreditsView()
}
