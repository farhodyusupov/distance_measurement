/*
See LICENSE folder for this sample’s licensing information.

Abstract:
An object that connects the camera controller and the views.
*/

import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation
import ARKit

class CameraManager: ObservableObject, CaptureDataReceiver {
    
    @Published var rotationAngle: Double = 0.0 // Ensure it's Double
    @Published var maxDepth: Float = 5.0       // Ensure it's Float
    @Published var minDepth: Float = 0.0       // Ensure it's Float
    @Published var processingCapturedResult: Bool = false
    @Published var capturedData = CameraCapturedData()
    @Published var isFilteringDepth: Bool = false
    var sceneView: ARSCNView?    // Minimum depth in meters for filtering
    @Published var orientation = UIDevice.current.orientation // Device orientation
    @Published var waitingForCapture: Bool = false            // Track capture state
    @Published var dataAvailable: Bool = false
    let controller: CameraController
    var cancellables = Set<AnyCancellable>()
    var session: AVCaptureSession { controller.captureSession }
    
    init() {
        capturedData = CameraCapturedData()
        controller = CameraController()
        controller.isFilteringEnabled = true
        controller.startStream()
        isFilteringDepth = controller.isFilteringEnabled
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
            // Update rotationAngle based on orientation change if needed
        }.store(in: &cancellables)
        controller.delegate = self
    }
    
    func getDepthValue(at point: CGPoint) -> Float {
        guard let depthTexture = capturedData.depth else {
            print("Depth texture not available")
            return 0.0
        }

        let width = depthTexture.width
        let height = depthTexture.height

        var depthData = [Float](repeating: 0.0, count: width * height)
        let region = MTLRegionMake2D(0, 0, width, height)
        depthTexture.getBytes(&depthData, bytesPerRow: width * MemoryLayout<Float>.stride, from: region, mipmapLevel: 0)

        let index = Int(point.y) * width + Int(point.x)
        if index >= 0 && index < depthData.count {
            let depthValue = depthData[index]
            print("Depth value at (\(point.x), \(point.y)): \(depthValue)")
            return depthValue
        } else {
            print("Invalid point for depth data")
            return 0.0
        }
    }

    func startPhotoCapture() {
        controller.capturePhoto()
        waitingForCapture = true
    }
    
    func resumeStream() {
        controller.startStream()
        processingCapturedResult = false
        waitingForCapture = false
    }
    
    func onNewPhotoData(capturedData: CameraCapturedData) {
        self.capturedData.depth = capturedData.depth
        self.capturedData.colorY = capturedData.colorY
        self.capturedData.colorCbCr = capturedData.colorCbCr
        self.capturedData.cameraIntrinsics = capturedData.cameraIntrinsics
        self.capturedData.cameraReferenceDimensions = capturedData.cameraReferenceDimensions
        waitingForCapture = false
        processingCapturedResult = true
    }
    
    func onNewData(capturedData: CameraCapturedData) {
        DispatchQueue.main.async {
            if !self.processingCapturedResult {
                self.capturedData.depth = capturedData.depth
                self.capturedData.colorY = capturedData.colorY
                self.capturedData.colorCbCr = capturedData.colorCbCr
                self.capturedData.cameraIntrinsics = capturedData.cameraIntrinsics
                self.capturedData.cameraReferenceDimensions = capturedData.cameraReferenceDimensions
                if self.dataAvailable == false {
                    self.dataAvailable = true
                }
            }
        }
    }
}

class CameraCapturedData {
    
    var depth: MTLTexture?
    var colorY: MTLTexture?
    var colorCbCr: MTLTexture?
    var cameraIntrinsics: matrix_float3x3
    var cameraReferenceDimensions: CGSize

    init(depth: MTLTexture? = nil,
         colorY: MTLTexture? = nil,
         colorCbCr: MTLTexture? = nil,
         cameraIntrinsics: matrix_float3x3 = matrix_float3x3(),
         cameraReferenceDimensions: CGSize = .zero) {
        
        self.depth = depth
        self.colorY = colorY
        self.colorCbCr = colorCbCr
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimensions = cameraReferenceDimensions
    }
}
