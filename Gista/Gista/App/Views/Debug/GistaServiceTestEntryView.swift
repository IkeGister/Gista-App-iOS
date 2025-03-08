//
//  GistaServiceTestEntryView.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/7/25.
//

import SwiftUI

struct GistaServiceTestEntryView: View {
    @State private var showTestView = true
    
    var body: some View {
        VStack {
            Text("Gista Service Test")
                .font(.largeTitle)
                .padding()
            
            Button("Open Test View") {
                showTestView = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .sheet(isPresented: $showTestView) {
            GistaServiceTestView()
        }
    }
}

struct GistaServiceTestEntryView_Previews: PreviewProvider {
    static var previews: some View {
        GistaServiceTestEntryView()
    }
} 