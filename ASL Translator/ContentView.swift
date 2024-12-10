//
//  ContentView.swift
//  ASL Translator
//
//  Created by Graham Cassoutt on 10/20/24.
//

import SwiftUI

struct ContentView: View {
    @State private var isTracking = false
    @State private var showInfo = false

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height: 100)
            
                
                VStack(spacing: 20) {
                    Text("ASL Translator")
                        .font(.system(size: 60))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300, maxHeight: 175)
                        .padding()
                    
                    NavigationLink(destination: ARVideoView()) {
                        Text("Start Translate")
                            .font(.system(size: 50))
                            .padding()
                            .frame(maxWidth: 300, maxHeight: 160)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showInfo.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title)
                    }
                }
            }
            .sheet(isPresented: $showInfo) {
                InfoView()
            }
        }
    }
}

struct InfoView: View {
    var body: some View {
        VStack {
            Text("ASL Translator Info")
                .font(.largeTitle)
                .padding()
            
            Text("This app translates American Sign Language (ASL) gestures into text using AR technology.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
