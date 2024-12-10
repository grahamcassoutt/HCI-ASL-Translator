//
//  VideoRecordingView.swift
//  ASL Translator
//
//  Created by Graham Cassoutt on 10/20/24.
//

import SwiftUI
import RealityKit
import ARKit
import Vision
import Foundation
import Combine

struct ARVideoView: View {
    @State private var isTracking: Bool = false
    @State private var predictedLetter: String = ""
    @State private var useFrontCamera: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Capture Sign")
                .font(.title)
                .padding()
            ZStack {
                ARViewContainer(isTracking: $isTracking, predictedLetter: $predictedLetter, useFrontCamera: $useFrontCamera)
                                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.5)
                                .cornerRadius(15)
                                .shadow(radius: 10)
                
                VStack {
                    Spacer()
                    HStack {
                        // Flip Camera
                        Button(action: {
                            useFrontCamera.toggle()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                                .padding()
                                .background(
                                    Circle()
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                                )
                                .cornerRadius(20)
                                .shadow(radius: 5)
                        }
                        .padding([.leading, .bottom], 20)
                        Spacer()
                    }
                }
            }

            HStack(spacing: 0) {
                Button(action: {
                    isTracking.toggle()
                }) {
                    Text(isTracking ? "Stop" : "Start")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isTracking ? Color.red : Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                NavigationLink(destination: EditTextView(text: $predictedLetter)) {
                    Text("Finished")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }

            ScrollView {
                Text(predictedLetter)
                    .font(.title2)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 100)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2)
            )
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
}

// Camera Window
struct ARViewContainer: UIViewRepresentable {
    @Binding var isTracking: Bool
    @Binding var predictedLetter: String
    @Binding var useFrontCamera: Bool

    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.setupForAR(usingFrontCamera: useFrontCamera)
        context.coordinator.setupVision()
        arView.session.delegate = context.coordinator
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.setupForAR(usingFrontCamera: useFrontCamera)
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(isTracking: $isTracking, predictedLetter: $predictedLetter)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        @Binding var isTracking: Bool
        @Binding var predictedLetter: String
        
        private var curPredicting = ""
        private var predictionsCorrect = 0
        private var handPoseRequest = VNDetectHumanHandPoseRequest()
        private var frameCounter = 0
        private let predictionQueue = DispatchQueue(label: "PredictionQueue", qos: .background)
        
        init(isTracking: Binding<Bool>, predictedLetter: Binding<String>) {
            _isTracking = isTracking
            _predictedLetter = predictedLetter
        }
        
        func setupVision() {
            handPoseRequest.maximumHandCount = 1
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard isTracking else { return }
            
            frameCounter += 1
            if frameCounter % 15 == 0 {
                let pixelBuffer = frame.capturedImage
                processFrame(pixelBuffer)
            }
        }
        
        func processFrame(_ frame: CVPixelBuffer) {
            let handler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: .up, options: [:])
            do {
                try handler.perform([handPoseRequest])
                guard let results = handPoseRequest.results?.first else { return }
                updateHandPositions(from: results)
            } catch {
                print("Failed to perform hand pose detection: \(error)")
            }
        }
        
        func updateHandPositions(from observation: VNHumanHandPoseObservation) {
            do {
                let recognizedPoints = try observation.recognizedPoints(.all)
                let fingerJoints: [VNHumanHandPoseObservation.JointName] = [
                    .thumbTip, .thumbIP, .thumbMP, .thumbCMC,
                    .indexTip, .indexDIP, .indexPIP, .indexMCP,
                    .middleTip, .middleDIP, .middlePIP, .middleMCP,
                    .ringTip, .ringDIP, .ringPIP, .ringMCP,
                    .littleTip, .littleDIP, .littlePIP, .littleMCP
                ]
                var points: [CGPoint] = []
                
                for joint in fingerJoints {
                    if let point = recognizedPoints[joint], point.confidence > 0.5 {
                        points.append(point.location)
                    }
                }
                
                predictionQueue.async { [weak self] in
                    self?.predictLetter(from: points)
                }
            } catch {
                print("Error detecting points: \(error)")
            }
        }
        
        func predictLetter(from points: [CGPoint]) {
            guard points.count >= 20 else { return }
            
            let inputArray = points.flatMap { [$0.x, $0.y] }
            guard inputArray.count == 40 else { return }
//            print(points)
//            print(",")
//            return
//            
            do {
                let featureMapping = Dictionary(uniqueKeysWithValues: zip(0..<40, inputArray))
                let modelInput = PositionsLogisticRegression4Input(
                    feature_1: featureMapping[0] ?? 0,
                    feature_2: featureMapping[1] ?? 0,
                    feature_3: featureMapping[2] ?? 0,
                    feature_4: featureMapping[3] ?? 0,
                    feature_5: featureMapping[4] ?? 0,
                    feature_6: featureMapping[5] ?? 0,
                    feature_7: featureMapping[6] ?? 0,
                    feature_8: featureMapping[7] ?? 0,
                    feature_9: featureMapping[8] ?? 0,
                    feature_10: featureMapping[9] ?? 0,
                    feature_11: featureMapping[10] ?? 0,
                    feature_12: featureMapping[11] ?? 0,
                    feature_13: featureMapping[12] ?? 0,
                    feature_14: featureMapping[13] ?? 0,
                    feature_15: featureMapping[14] ?? 0,
                    feature_16: featureMapping[15] ?? 0,
                    feature_17: featureMapping[16] ?? 0,
                    feature_18: featureMapping[17] ?? 0,
                    feature_19: featureMapping[18] ?? 0,
                    feature_20: featureMapping[19] ?? 0,
                    feature_21: featureMapping[20] ?? 0,
                    feature_22: featureMapping[21] ?? 0,
                    feature_23: featureMapping[22] ?? 0,
                    feature_24: featureMapping[23] ?? 0,
                    feature_25: featureMapping[24] ?? 0,
                    feature_26: featureMapping[25] ?? 0,
                    feature_27: featureMapping[26] ?? 0,
                    feature_28: featureMapping[27] ?? 0,
                    feature_29: featureMapping[28] ?? 0,
                    feature_30: featureMapping[29] ?? 0,
                    feature_31: featureMapping[30] ?? 0,
                    feature_32: featureMapping[31] ?? 0,
                    feature_33: featureMapping[32] ?? 0,
                    feature_34: featureMapping[33] ?? 0,
                    feature_35: featureMapping[34] ?? 0,
                    feature_36: featureMapping[35] ?? 0,
                    feature_37: featureMapping[36] ?? 0,
                    feature_38: featureMapping[37] ?? 0,
                    feature_39: featureMapping[38] ?? 0,
                    feature_40: featureMapping[39] ?? 0
                )
                
                let model = try PositionsLogisticRegression4(configuration: .init())
                let prediction = try model.prediction(input: modelInput)
                
                if curPredicting == prediction.label {
                    predictionsCorrect += 1
                } else {
                    predictionsCorrect = 0
                }
                
                curPredicting = prediction.label
                
                if predictionsCorrect == 4 {
                    predictionsCorrect = 0
                    DispatchQueue.main.async {
                        self.predictedLetter += prediction.label + " "
                    }
                }
            } catch {
                print("Error making prediction: \(error)")
            }
        }
    }
}

extension ARView {
    func setupForAR(usingFrontCamera: Bool) {
        let configuration: ARConfiguration
        if usingFrontCamera {
            configuration = ARFaceTrackingConfiguration()
        } else {
            configuration = ARWorldTrackingConfiguration()
        }
        self.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        self.automaticallyConfigureSession = false
    }
}
