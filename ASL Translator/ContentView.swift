//
//  ContentView.swift
//  ASL Translator
//
//  Created by Graham Cassoutt on 10/20/24.
//

import SwiftUI

struct ContentView: View {
    @State private var isTracking = false

    var body: some View {
        NavigationView {
            VStack {
                Text("ASL Translator")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                NavigationLink(destination: ARVideoView(isTracking: $isTracking)) {
                    Text("Start Translate")
                        .font(.title)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                }
                
                Spacer()
            }
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


