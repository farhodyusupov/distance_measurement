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
    
    @State private var horizontalDistance: Double = 0.0
    @State private var verticalDistance: Float = 0.0
    var spheres: [SCNNode] = []
    
    var body: some View {
        VStack {
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("H Distance")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(String(format: "%.2f m", distanceBetweenPoints ?? 0.0))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("V Distance")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(String(format: "%.2f m", verticalDistance))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 20)
                
                Divider()
                    .background(Color.white.opacity(0.5))
                    .padding(.horizontal, 10)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Comp. Dist.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("0.00 m")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Ball Spd.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("0.0 m/s")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 20)
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .cornerRadius(10)
            
            
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
                                if let p1 = distanceToPoint1, let p2 = distanceToPoint2 {
                                    distanceBetweenPoints = abs(p1 - p2)
                                }
                            }
                        }
                )

                ARView(verticalDistance: $verticalDistance, distanceBetweenPoints: $distanceBetweenPoints)
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
    @Binding var verticalDistance: Float
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
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            let cameraTransform = frame.camera.transform
            let cameraPosition = cameraTransform.columns.3
            let cameraHeight = cameraPosition.z
            
            
        }
        
        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            let location = sender.location(in: parent.sceneView)
            let hitTestResults = parent.sceneView.hitTest(location, types: [.featurePoint])
            
            guard let result = hitTestResults.last else { return }
            let transform = result.worldTransform
            parent.verticalDistance = transform.columns.3.z
            let position = SCNVector3(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            )
            
            if parent.tappedPoints.count == 2 {
                parent.clearPoints()  // Clear previous points and line
            }
            
            parent.addPoint(position)
            
            if parent.tappedPoints.count == 2 {
                let distance = parent.tappedPoints[0].distance(to: parent.tappedPoints[1])
                parent.distanceBetweenPoints = distance
                parent.drawLineBetweenPoints()
                parent.drawSquareBetweenPoints()
//                parent.drawDensePointCloudBetweenPoints()
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
        
        lineNode?.removeFromParentNode()  // Clear previous line
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
        
        let cylinder = SCNCylinder(radius: 0.002, height: CGFloat(start.distance(to: end)))
        cylinder.firstMaterial?.diffuse.contents = UIColor.yellow
        
        let lineNode = SCNNode(geometry: cylinder)
        
        lineNode.position = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        
        lineNode.look(at: end, up: sceneView.scene.rootNode.worldUp, localFront: lineNode.worldUp)
        
        sceneView.scene.rootNode.addChildNode(lineNode)
        self.lineNode = lineNode
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
    private mutating func drawDensePointCloudBetweenPoints() {
        guard tappedPoints.count == 2 else { return }
        
        let start = tappedPoints[0]
        let end = tappedPoints[1]
        
        let midPoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        
        let distance = start.distance(to: end)
        let pointCount = 500

        for _ in 0..<pointCount {
            let randomOffsetX = Float.random(in: -distance / 2...distance / 2)
            let randomOffsetY = Float.random(in: -distance / 2...distance / 2)
            let randomOffsetZ = Float.random(in: -distance / 2...distance / 2)
            
            let position = SCNVector3(
                midPoint.x + randomOffsetX,
                midPoint.y + randomOffsetY,
                midPoint.z + randomOffsetZ
            )

            let pointNode = createPoint(at: position)
            sceneView.scene.rootNode.addChildNode(pointNode)
            spheres.append(pointNode)
        }
    }

    private func createPoint(at position: SCNVector3) -> SCNNode {
        let point = SCNSphere(radius: 0.003)
        point.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.7)

        let pointNode = SCNNode(geometry: point)
        pointNode.position = position
        return pointNode
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
