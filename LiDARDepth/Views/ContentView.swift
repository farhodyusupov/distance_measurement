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
    @State private var maxDepth = Float(15.0)
    @State private var minDepth = Float(0.0)
    @State private var tapLocation1: CGPoint? = nil
    @State private var tapLocation2: CGPoint? = nil
    @State private var distanceToPoint1: Float? = nil
    @State private var distanceToPoint2: Float? = nil
    @State private var distanceBetweenPoints: Float? = nil
    @State private var sceneView = ARSCNView()
    var spheres: [SCNNode] = []
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
//            SliderDepthBoundaryView(val: $maxDepth, label: "Max Depth", minVal: 0, maxVal: 10)
//            SliderDepthBoundaryView(val: $minDepth, label: "Min Depth", minVal: 0, maxVal: 10)
            
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

                ARView(distanceBetweenPoints: $distanceBetweenPoints)
                                .edgesIgnoringSafeArea(.all)
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


struct ARView: UIViewRepresentable {
    @Binding var distanceBetweenPoints: Float?
    var sceneView = ARSCNView()
    var spheres: [SCNNode] = []
    var tappedPoints: [SCNVector3] = []
    var lineNode: SCNNode?
    var planeNode: SCNNode?
    func makeUIView(context: Context) -> ARSCNView {
        sceneView.delegate = context.coordinator
        sceneView.scene = SCNScene()
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration)
        
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARView
        
        init(_ parent: ARView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
                   let location = sender.location(in: parent.sceneView)
                   let hitTestResults = parent.sceneView.hitTest(location, types: [.featurePoint])
                   
                   guard let result = hitTestResults.last else { return }
                   
                   let transform = result.worldTransform
                   let position = SCNVector3(
                       transform.columns.3.x,
                       transform.columns.3.y,
                       transform.columns.3.z
                   )
                   
                   // Reset if this is the third point
                   if parent.tappedPoints.count == 2 {
                       parent.clearPoints()
                   }
                   
                   // Add the new point and sphere
                   parent.addPoint(position)
                   
                   // Calculate distance if there are exactly two points
                   if parent.tappedPoints.count == 2 {
                       let distance = parent.tappedPoints[0].distance(to: parent.tappedPoints[1])
                       parent.distanceBetweenPoints = distance
                       parent.drawLineBetweenPoints()
//                       parent.drawSquareBetweenPoints()
                       parent.drawPointCloudSquareBetweenPoints()
                   }
               }
        
    }
    private mutating func clearPoints() {
        for sphere in spheres {
            sphere.removeFromParentNode()
        }
        spheres.removeAll()
        tappedPoints.removeAll()
        distanceBetweenPoints = nil
        lineNode?.removeAllActions()
        lineNode = nil
        
        planeNode?.removeFromParentNode()
        planeNode = nil
    }
    
    private mutating func addPoint(_ position: SCNVector3) {
           tappedPoints.append(position)
           
           let sphere = createSphere(at: position)
           sceneView.scene.rootNode.addChildNode(sphere)
           spheres.append(sphere)
       }
    private func createSphere(at position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: 0.02)
        let node = SCNNode(geometry: sphere)
        node.position = position
        
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        sphere.firstMaterial = material
        
        return node
    }
    private mutating func drawLineBetweenPoints() {
            guard tappedPoints.count == 2 else { return }
            
            let start = tappedPoints[0]
            let end = tappedPoints[1]
            
            // Create a cylinder to represent the line
            let cylinder = SCNCylinder(radius: 0.002, height: CGFloat(start.distance(to: end)))
            cylinder.firstMaterial?.diffuse.contents = UIColor.yellow
            
            let lineNode = SCNNode(geometry: cylinder)
            
            // Position the line node at the midpoint between start and end
            lineNode.position = SCNVector3(
                (start.x + end.x) / 2,
                (start.y + end.y) / 2,
                (start.z + end.z) / 2
            )
            
            // Rotate the line to align with the two points
            lineNode.look(at: end, up: sceneView.scene.rootNode.worldUp, localFront: lineNode.worldUp)
            
            // Add the line node to the scene and store a reference to it
            sceneView.scene.rootNode.addChildNode(lineNode)
            self.lineNode = lineNode
        }
    
   
    private mutating func drawPointCloudSquareBetweenPoints() {
        guard tappedPoints.count == 2 else { return }

        let start = tappedPoints[0]
        let end = tappedPoints[1]

        // Calculate the midpoint between the two points
        let midPoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )

        // Calculate the distance between the two points for square size
        let distance = start.distance(to: end)
        let pointSpacing: Float = 0.005  // Spacing between points in the point cloud

        // Calculate the number of points along each axis
        let numPoints = Int(distance / pointSpacing)

        for i in 0...numPoints {
            for j in 0...numPoints {
                // Calculate position within the plane
                let xOffset = Float(i) * pointSpacing - distance / 2
                let yOffset = Float(j) * pointSpacing - distance / 2

                // Offset from the midpoint along the direction vector
                let position = SCNVector3(
                    midPoint.x + xOffset,
                    midPoint.y + yOffset,
                    midPoint.z
                )

                let pointNode = createPoint(at: position)
                sceneView.scene.rootNode.addChildNode(pointNode)
                spheres.append(pointNode)  // Store each point node for cleanup if needed
            }
        }
    }
    private func createPoint(at position: SCNVector3) -> SCNNode {
        let point = SCNSphere(radius: 0.0005)  // Small radius for point size
        point.firstMaterial?.diffuse.contents = UIColor.green

        let pointNode = SCNNode(geometry: point)
        pointNode.position = position
        return pointNode
    }
    
    
    private mutating func drawSquareBetweenPoints() {
        guard tappedPoints.count == 2 else { return }
        
        let start = tappedPoints[0]
        let end = tappedPoints[1]
        
        // Calculate the midpoint between the two points
        let midPoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        
        // Calculate the distance between the two points for the square size
        let distance = start.distance(to: end)
        
        // Create a square plane geometry with width and height equal to the distance
        let plane = SCNPlane(width: CGFloat(distance), height: CGFloat(distance))
        plane.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.9)  // Semi-transparent green
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = midPoint
        
        // Calculate the direction vector from start to end
        let direction = SCNVector3(
            start.x - end.x,
            start.y - end.y,
            start.z - end.z
        )
        
        // Align the plane parallel to the line segment between start and end points
        planeNode.look(at: end, up: sceneView.scene.rootNode.worldUp, localFront: planeNode.worldUp)
        
        // Rotate the square 90 degrees around the direction vector to make it perpendicular to the line segment
//        let rotationAngle = Float.pi/2
//        let rotationAxis = direction
//        let rotationMatrix = SCNMatrix4MakeRotation(rotationAngle, rotationAxis.x, rotationAxis.y, rotationAxis.z)
//        planeNode.transform = SCNMatrix4Mult(planeNode.transform, rotationMatrix)
        
        // Add the plane node to the scene and store a reference to it
        sceneView.scene.rootNode.addChildNode(planeNode)
        self.planeNode = planeNode
    }
}

extension SCNVector3 {
    func distance(to vector: SCNVector3) -> Float {
        let dx = self.x - vector.x
        let dy = self.y - vector.y
        let dz = self.z - vector.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }
}

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
