///*
//See LICENSE folder for this sample’s licensing information.
//
//Abstract:
//The app's main user interface.
//*/
//
import SwiftUI
import SceneKit
import ARKit

struct ContentView: View {
    @StateObject private var manager = CameraManager()
    @State private var maxDepth = Float(5.0)
    @State private var minDepth = Float(0.0)
    @State private var tapLocation1: CGPoint? = nil
    @State private var tapLocation2: CGPoint? = nil
    @State private var distanceToPoint1: Float? = nil
    @State private var distanceToPoint2: Float? = nil
    @State private var distanceBetweenPoints: Float? = nil

    var body: some View {
        VStack {
            VStack {
                if let distance1 = distanceToPoint1 {
                    Text("Distance to Point 1: \(String(format: "%.2f", distance1)) meters")
                        .font(.headline)
                        .padding(4)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                if let distance2 = distanceToPoint2 {
                    Text("Distance to Point 2: \(String(format: "%.2f", distance2)) meters")
                        .font(.headline)
                        .padding(4)
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
                if let distanceBetween = distanceBetweenPoints {
                    Text("Distance Between Points: \(String(format: "%.2f", distanceBetween)) meters")
                        .font(.headline)
                        .padding(4)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                }
            }
            
            // Slider controls for max and min depth
            SliderDepthBoundaryView(val: $maxDepth, label: "Max Depth", minVal: 0, maxVal: 10)
            SliderDepthBoundaryView(val: $minDepth, label: "Min Depth", minVal: 0, maxVal: 10)
            
            ZStack {
                MetalTextureColorThresholdDepthView(
                    rotationAngle: 0,
                    maxDepth: $maxDepth,
                    minDepth: $minDepth,
                    capturedData: manager.capturedData,
                    tapLocation1: $tapLocation1,
                    tapLocation2: $tapLocation2,
                    distanceToPoint1: $distanceToPoint1,
                    distanceToPoint2: $distanceToPoint2,
                    fx: 500.0,
                    fy: 500.0,
                    cx: 160.0,
                    cy: 120.0
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            if tapLocation1 == nil {
                                tapLocation1 = value.location
                            } else if tapLocation2 == nil {
                                tapLocation2 = value.location
                                // Calculate the distance between the two 3D points
                                if let p1 = distanceToPoint1, let p2 = distanceToPoint2 {
                                    distanceBetweenPoints = abs(p1 - p2)
                                }
                            }
                        }
                )

                // Overlay circles at tap locations
                if let location1 = tapLocation1 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .position(x: location1.x, y: location1.y)
                }
                if let location2 = tapLocation2 {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .position(x: location2.x, y: location2.y)
                }
            }
        }
    }
}
//struct ContentView: View {
//    
//    @StateObject private var manager = CameraManager()
//    
//    @State private var maxDepth = Float(5.0)
//    @State private var minDepth = Float(0.0)
//    @State private var firstPoint: CGPoint? = nil
//    @State private var secondPoint: CGPoint? = nil
//    @State private var distance: Float? = nil
//    @State private var worldPoints: [simd_float3] = []
//    @State private var screenPoints: [CGPoint] = []
//    
//    let maxRangeDepth = Float(15)
//    let minRangeDepth = Float(0)
//    
//    var body: some View {
//        VStack {
//            HStack {
//                Button {
//                    manager.processingCapturedResult ? manager.resumeStream() : manager.startPhotoCapture()
//                } label: {
//                    Image(systemName: manager.processingCapturedResult ? "play.circle" : "camera.circle")
//                        .font(.largeTitle)
//                }
//                
//                Text("Depth Filtering")
//                Toggle("Depth Filtering", isOn: $manager.isFilteringDepth).labelsHidden()
//                Spacer()
//            }
//            SliderDepthBoundaryView(val: $maxDepth, label: "Max Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
//            SliderDepthBoundaryView(val: $minDepth, label: "Min Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
//            if #available(iOS 17.0, *) {
//                if #available(iOS 18.0, *) {
//                    ZStack {
//                        MetalTextureColorZapView(
//                            rotationAngle: rotationAngle,
//                            maxDepth: $maxDepth,
//                            minDepth: $minDepth,
//                            capturedData: manager.capturedData
//                        )
//                        
//                        // Overlay red circles on tapped points
//                        ForEach(screenPoints, id: \.self) { point in
//                            Circle()
//                                .fill(Color.red)
//                                .frame(width: 20, height: 20)
//                                .position(point)
//                        }
//                    }
//                    .onTapGesture { location in
//                        if firstPoint == nil {
//                            firstPoint = location
//                        } else {
//                            secondPoint = location
//                            calculateDistance()
//                            
//                            // Convert and store 3D world points
//                            if let point1 = firstPoint {
//                                let texCoord1 = convertToTextureCoordinates(point: point1, textureWidth: manager.capturedData.depth!.width, textureHeight: manager.capturedData.depth!.height)
//                                let depth1 = manager.getDepthValue(at: texCoord1)
//                                let worldPoint1 = convertScreenToWorld(point: texCoord1, depth: depth1)
//                                worldPoints.append(worldPoint1)
//                                screenPoints.append(projectWorldToScreen(worldPoint1))
//                            }
//                            
//                            if let point2 = secondPoint {
//                                let texCoord2 = convertToTextureCoordinates(point: point2, textureWidth: manager.capturedData.depth!.width, textureHeight: manager.capturedData.depth!.height)
//                                let depth2 = manager.getDepthValue(at: texCoord2)
//                                let worldPoint2 = convertScreenToWorld(point: texCoord2, depth: depth2)
//                                worldPoints.append(worldPoint2)
//                                screenPoints.append(projectWorldToScreen(worldPoint2))
//                            }
//                            
//                            // Clear the points for next set of taps
//                            firstPoint = nil
//                            secondPoint = nil
//                        }
//                    }
//                } else {
//                    // Fallback on earlier versions
//                }
//            } else {
//                // Fallback on earlier versions
//            }
//            
//            if let distance = distance {
//                Text(String(format: "Distance: %.2f meters", distance))
//                    .font(.headline)
//                    .padding()
//            }
//        }
//    }
//    func calculateDistance() {
//            guard let point1 = firstPoint, let point2 = secondPoint else {
//                return
//            }
//
//            // Convert points to texture coordinates
//            let texCoord1 = convertToTextureCoordinates(point: point1, textureWidth: manager.capturedData.depth!.width, textureHeight: manager.capturedData.depth!.height)
//            let texCoord2 = convertToTextureCoordinates(point: point2, textureWidth: manager.capturedData.depth!.width, textureHeight: manager.capturedData.depth!.height)
//
//            // Get depth values at these points
//            let depth1 = manager.getDepthValue(at: texCoord1)
//            let depth2 = manager.getDepthValue(at: texCoord2)
//
//            // Convert 2D points + depth into 3D coordinates
//            let worldPoint1 = convertScreenToWorld(point: texCoord1, depth: depth1)
//            let worldPoint2 = convertScreenToWorld(point: texCoord2, depth: depth2)
//
//            // Calculate the Euclidean distance between the two 3D points
//            let calculatedDistance = simd_distance(worldPoint1, worldPoint2)
//
//            // Update the distance state to show in the UI
//            distance = calculatedDistance
//            print("calculatedDistance:: \(calculatedDistance)")
//            // Clear points for next selection
//            firstPoint = nil
//            secondPoint = nil
//        }
//
//    func convertToTextureCoordinates(point: CGPoint, textureWidth: Int, textureHeight: Int) -> CGPoint {
//        let convertedX = max(0, min(textureWidth - 1, Int(point.x * CGFloat(textureWidth) / UIScreen.main.bounds.width)))
//        let convertedY = max(0, min(textureHeight - 1, Int(point.y * CGFloat(textureHeight) / UIScreen.main.bounds.height)))
//        return CGPoint(x: convertedX, y: convertedY)
//    }
//
//    func convertScreenToWorld(point: CGPoint, depth: Float) -> simd_float3 {
//        let fx: Float = 500.0  // Focal length in the x direction (in pixels)
//        let fy: Float = 500.0  // Focal length in the y direction (in pixels)
//        let cx: Float = 320.0  // Principal point offset in x (center of the image)
//        let cy: Float = 240.0  // Principal point offset in y (center of the image)
//
//        let x = (Float(point.x) - cx) * depth / fx
//        let y = (Float(point.y) - cy) * depth / fy
//        let z = depth
//
//        return simd_float3(x, y, z)
//    }
//
//    func projectWorldToScreen(_ worldPoint: simd_float3) -> CGPoint {
//        let fx: Float = 500.0
//        let fy: Float = 500.0
//        let cx: Float = 320.0
//        let cy: Float = 240.0
//
//        let screenX = (worldPoint.x * fx) / worldPoint.z + cx
//        let screenY = (worldPoint.y * fy) / worldPoint.z + cy
//
//        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
//    }
//}

struct SliderDepthBoundaryView: View {
    @Binding var val: Float
    var label: String
    var minVal: Float
    var maxVal: Float
    let stepsCount = Float(200.0)
    
    var body: some View {
        HStack {
            Text(String(format: " %@: %.2f", label, val))
            Slider(
                value: $val,
                in: minVal...maxVal,
                step: (maxVal - minVal) / stepsCount
            ) {
            } minimumValueLabel: {
                Text(String(minVal))
            } maximumValueLabel: {
                Text(String(maxVal))
            }
        }
    }
}
