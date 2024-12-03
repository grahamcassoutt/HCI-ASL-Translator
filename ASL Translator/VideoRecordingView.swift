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
import CoreML

struct ARVideoView: View {
    @Binding var isTracking: Bool
    @State private var isCapturing: Bool = false
    @State private var isUsingFrontCamera: Bool = false
    @State private var predictedLetters: String = "" // Holds the sequence of predicted letters

    var body: some View {
        VStack {
            ZStack {
                ARViewContainer(isTracking: $isTracking, isCapturing: $isCapturing, isUsingFrontCamera: $isUsingFrontCamera, predictedLetters: $predictedLetters)
                    .frame(width: UIScreen.main.bounds.width * 0.8, height: UIScreen.main.bounds.height * 0.65)
                
                VStack {
                    Spacer()

                    // Prediction Text Box
                    ScrollView {
                        Text(predictedLetters)
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                            .padding()
                    }
                    .frame(height: 100)
                }
            }

            HStack(spacing: 20) {
                Button(action: {
                    flipCamera()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }

                Button(action: {
                    isCapturing = true
                    print("Capture started")
                }) {
                    Text("Start")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 120)
                        .background(Color.green)
                        .cornerRadius(12)
                }

                Button(action: {
                    isCapturing = false
                    print("Capture stopped")
                }) {
                    Text("End")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 120)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationBarTitle("Capture Sign", displayMode: .inline)
    }

    private func flipCamera() {
        isUsingFrontCamera.toggle()
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var isTracking: Bool
    @Binding var isCapturing: Bool
    @Binding var isUsingFrontCamera: Bool
    @Binding var predictedLetters: String
    var arView = ARView(frame: .zero)

    init(isTracking: Binding<Bool>, isCapturing: Binding<Bool>, isUsingFrontCamera: Binding<Bool>, predictedLetters: Binding<String>) {
        _isTracking = isTracking
        _isCapturing = isCapturing
        _isUsingFrontCamera = isUsingFrontCamera
        _predictedLetters = predictedLetters
    }

    func makeUIView(context: Context) -> ARView {
        setupARView(usingFrontCamera: isUsingFrontCamera)
        arView.session.delegate = context.coordinator
        context.coordinator.setupVision()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if context.coordinator.isUsingFrontCamera != isUsingFrontCamera {
            uiView.session.pause()
            setupARView(usingFrontCamera: isUsingFrontCamera)
            context.coordinator.isUsingFrontCamera = isUsingFrontCamera
        }
        context.coordinator.isCapturing = isCapturing
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(arView: arView, isCapturing: $isCapturing, isUsingFrontCamera: isUsingFrontCamera, predictedLetters: $predictedLetters)
    }

    private func setupARView(usingFrontCamera: Bool) {
        let configuration: ARConfiguration
        if usingFrontCamera {
            let faceConfig = ARFaceTrackingConfiguration()
            faceConfig.isWorldTrackingEnabled = true
            configuration = faceConfig
        } else {
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.environmentTexturing = .none
            worldConfig.planeDetection = []
            configuration = worldConfig
        }
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    class Coordinator: NSObject, ARSessionDelegate {
        var arView: ARView
        @Binding var isCapturing: Bool
        var isUsingFrontCamera: Bool
        @Binding var predictedLetters: String
        private var handPoseRequest = VNDetectHumanHandPoseRequest()
        private var frameCounter = 0
        private var lastUpdateTime: TimeInterval = 0
        private var isProcessingPrediction = false

        init(arView: ARView, isCapturing: Binding<Bool>, isUsingFrontCamera: Bool, predictedLetters: Binding<String>) {
            self.arView = arView
            _isCapturing = isCapturing
            self.isUsingFrontCamera = isUsingFrontCamera
            _predictedLetters = predictedLetters
        }

        func setupVision() {
            handPoseRequest.maximumHandCount = 1
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard isCapturing else { return }

            let currentTime = Date().timeIntervalSince1970
            if currentTime - lastUpdateTime < 5.0 { return }
            lastUpdateTime = currentTime

            frameCounter += 1
            if frameCounter % 10 == 0 {
                let pixelBuffer = frame.capturedImage
                processFrame(pixelBuffer)
            }
        }

        func processFrame(_ frame: CVPixelBuffer) {
            let handler = VNImageRequestHandler(cvPixelBuffer: frame, orientation: .up, options: [:])
            do {
                try handler.perform([handPoseRequest])
                guard let results = handPoseRequest.results?.first else { return }
                processHandPositions(from: results)
            } catch {
                print("Failed to perform hand pose detection: \(error)")
            }
        }

        func processHandPositions(from observation: VNHumanHandPoseObservation) {
            do {
                let recognizedPoints = try observation.recognizedPoints(.all)
                let fingerJoints: [VNHumanHandPoseObservation.JointName] = [
                    .thumbTip, .thumbIP, .thumbMP, .thumbCMC,
                    .indexTip, .indexDIP, .indexPIP, .indexMCP,
                    .middleTip, .middleDIP, .middlePIP, .middleMCP,
                    .ringTip, .ringDIP, .ringPIP, .ringMCP,
                    .littleTip, .littleDIP, .littlePIP, .littleMCP
                ]

                var inputArray: [Double] = []
                for joint in fingerJoints {
                    if let point = recognizedPoints[joint] {
                        inputArray.append(point.location.x)
                        inputArray.append(point.location.y)
                    } else {
                        inputArray.append(0.0)
                        inputArray.append(0.0)
                    }
                }

                // Use the machine learning model
                predictLetter(from: inputArray)
            } catch {
                print("Error processing hand positions: \(error)")
            }
        }

        func predictLetter(from inputArray: [Double]) {
            guard let model = try? LogisticRegressionModel(configuration: .init()) else {
                print("Failed to load model")
                return
            }

            // Ensure the input array has the required number of features
            guard inputArray.count == 40 else {
                print("Invalid input array size: expected 40 features, got \(inputArray.count)")
                return
            }

            // Prevent overlapping predictions
            guard !isProcessingPrediction else { return }
            isProcessingPrediction = true

            // Perform prediction on a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let modelInput = LogisticRegressionModelInput(
                        feature0: inputArray[0], feature1: inputArray[1], feature2: inputArray[2], feature3: inputArray[3],
                        feature4: inputArray[4], feature5: inputArray[5], feature6: inputArray[6], feature7: inputArray[7],
                        feature8: inputArray[8], feature9: inputArray[9], feature10: inputArray[10], feature11: inputArray[11],
                        feature12: inputArray[12], feature13: inputArray[13], feature14: inputArray[14], feature15: inputArray[15],
                        feature16: inputArray[16], feature17: inputArray[17], feature18: inputArray[18], feature19: inputArray[19],
                        feature20: inputArray[20], feature21: inputArray[21], feature22: inputArray[22], feature23: inputArray[23],
                        feature24: inputArray[24], feature25: inputArray[25], feature26: inputArray[26], feature27: inputArray[27],
                        feature28: inputArray[28], feature29: inputArray[29], feature30: inputArray[30], feature31: inputArray[31],
                        feature32: inputArray[32], feature33: inputArray[33], feature34: inputArray[34], feature35: inputArray[35],
                        feature36: inputArray[36], feature37: inputArray[37], feature38: inputArray[38], feature39: inputArray[39]
                    )

                    let prediction = try model.prediction(input: modelInput)

                    DispatchQueue.main.async {
                        self.predictedLetters.append(prediction.class_0)
                        if self.predictedLetters.count > 50 {
                            self.predictedLetters.removeFirst(self.predictedLetters.count - 50)
                        }
                        self.isProcessingPrediction = false
                    }
                } catch {
                    print("Prediction error: \(error)")
                    self.isProcessingPrediction = false
                }
            }
        }
    }
}
