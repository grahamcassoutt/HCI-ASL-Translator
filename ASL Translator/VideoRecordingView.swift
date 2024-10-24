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

struct ARVideoView: View {
    @Binding var isTracking: Bool
    
    var body: some View {
        ZStack {
            ARViewContainer(isTracking: $isTracking)
                .frame(width: UIScreen.main.bounds.width * 0.9, height: UIScreen.main.bounds.height * 0.6)
            
            VStack {
                HStack {
                    Spacer()
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(20)
                            .padding(.trailing)
                    }
                }
                Spacer()
                Button(action: {
                }) {
                    Text("Capture")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .navigationBarTitle("Capture Sign", displayMode: .inline)
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var isTracking: Bool
    @State private var arView = ARView(frame: .zero)
    
    func makeUIView(context: Context) -> ARView {
        arView = ARView(frame: .zero)
        arView.setupForAR()
        context.coordinator.setupVision()
        arView.session.delegate = context.coordinator
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update logic
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(arView: $arView)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        @Binding var arView: ARView
        private var handPoseRequest = VNDetectHumanHandPoseRequest()
        private var fingerViews: [UIView] = []
        private var frameCounter = 0

        init(arView: Binding<ARView>) {
            _arView = arView
        }

        func setupVision() {
            handPoseRequest.maximumHandCount = 1
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
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
                updateHandPositions(from: results)
            } catch {
                print("Failed to perform hand pose  detection: \(error)")
            }
        }

        // Update the hand positions
        func updateHandPositions(from observation: VNHumanHandPoseObservation) {
            do {
                let recognizedPoints = try observation.recognizedPoints(.all)

                fingerViews.forEach { $0.removeFromSuperview() }
                fingerViews.removeAll()

                guard let frame = arView.session.currentFrame else { return }
                let imageResolution = frame.camera.imageResolution

                let widthScale = arView.bounds.width / imageResolution.width
                let heightScale = arView.bounds.height / imageResolution.height

                let fingerJoints: [VNHumanHandPoseObservation.JointName] = [
                    .thumbTip, .thumbIP, .thumbMP, .thumbCMC,
                    .indexTip, .indexDIP, .indexPIP, .indexMCP,
                    .middleTip, .middleDIP, .middlePIP, .middleMCP,
                    .ringTip, .ringDIP, .ringPIP, .ringMCP,
                    .littleTip, .littleDIP, .littlePIP, .littleMCP
                ]
                
                var pointsToProject: [CGPoint] = []
                
                for joint in fingerJoints {
                    if let point = recognizedPoints[joint], point.confidence > 0.5 {
                        let adjustedX = point.location.x * imageResolution.width * widthScale
                        let adjustedY = (1 - point.location.y) * imageResolution.height * heightScale
                        pointsToProject.append(CGPoint(x: adjustedX, y: adjustedY))
                    }
                }
                
                DispatchQueue.main.async {
                    self.overlayFingerJoints(pointsToProject)
                }
            } catch {
                print("Error detecting points: \(error)")
            }
        }

        func overlayFingerJoints(_ points: [CGPoint]) {
            for point in points {
                let jointView = UIView(frame: CGRect(x: point.x, y: point.y, width: 10, height: 10))
                jointView.backgroundColor = .red
                jointView.layer.cornerRadius = 5
                arView.addSubview(jointView)
                fingerViews.append(jointView)
            }
        }
    }
}

extension ARView {
    func setupForAR() {
        let configuration = ARWorldTrackingConfiguration()
        self.session.run(configuration)
        self.automaticallyConfigureSession = false
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings Page")
            .font(.largeTitle)
            .padding()
    }
}

