//
//  EditPageView.swift
//  ASL Translator
//
//  Created by Graham Cassoutt on 11/24/24.
//

import SwiftUI

struct EditTextView: View {
    @Binding var text: String
    @State private var showConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Translated Text")
                    .font(.title)
                    .padding()

                TextEditor(text: $text)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .padding()

                Spacer()
                
                Button(action: {
                    showConfirmation = true
                }) {
                    Text("Start New Translation")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .alert(isPresented: $showConfirmation) {
                    Alert(
                        title: Text("Start New Translation"),
                        message: Text("Are you sure you want to start a new translation? This will erase the current text."),
                        primaryButton: .destructive(Text("Yes")) {
                            text = ""
                            presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
            .padding()
        }
    }
}
