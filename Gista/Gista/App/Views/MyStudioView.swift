//
//  MyStudioView.swift
//  Gista
//
//  Created by Tony Nlemadim on 3/17/25.
//

import SwiftUI

struct MyStudioView: View {
    var body: some View {
        Text("My Studio")
            .font(.title)
            .foregroundColor(.white)
    }
}

#if DEBUG
struct MyStudioView_Previews: PreviewProvider {
    static var previews: some View {
        MyStudioView()
            .preferredColorScheme(.dark)
    }
}
#endif

