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
//    @State private var targetArea: CGRect = .zero
    private let targetArea = CGRect(x: 0, y: 0, width: 200, height: 200)
    @State private var showDepthView = false

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
                                tapLocation1 = nil
                                tapLocation2 = nil
                            }
                        }
                )
                ARView(
                    verticalDistance: $verticalDistance,
                    distanceBetweenPoints: $distanceBetweenPoints,
                    manager: manager,
                    fx: 500.0,
                    fy: 500.0,
                    cx: 160.0,
                    cy: 120.0
                )
                .edgesIgnoringSafeArea(.all)
              
                
                
            }
        }
    }
    

}

struct ARView: UIViewRepresentable {
    @Binding var verticalDistance: Float
       @Binding var distanceBetweenPoints: Float?
       var sceneView = ARSCNView()
       var manager: CameraManager // Pass manager here
       var fx: Float
       var fy: Float
       var cx: Float
       var cy: Float
       var spheres: [SCNNode] = []
       var tappedPoints: [SCNVector3] = []
       var lineNode: SCNNode?
       

    
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
            _ = cameraPosition.z
            
            
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
                parent.clearPoints()
            }
            
            parent.addPoint(position)
            
            if parent.tappedPoints.count == 2 {
                let distance = parent.tappedPoints[0].distance(to: parent.tappedPoints[1])
                parent.distanceBetweenPoints = distance
                parent.drawLineBetweenPoints()
                parent.drawDensePointCloudWithDepth()

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
        lineNode?.removeFromParentNode()
        lineNode = nil
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
    
    private mutating func drawDensePointCloudWithDepth() {
        guard tappedPoints.count == 2 else { return }
        guard let depthData = manager.capturedData.depth else { return } // Ensure depth data is available
        guard let depthData = manager.capturedData.depth else {
            print("Depth data is unavailable")
            return
        }

        let start = tappedPoints[0]
        let end = tappedPoints[1]

        
        let midPoint = SCNVector3(
            (start.x + end.x) / 2,
            (start.y + end.y) / 2,
            (start.z + end.z) / 2
        )
        let horizontalDirection = SCNVector3(
            end.x - start.x,0,
            end.z - start.z
        )
        let perpendicularDirection = SCNVector3(
            -horizontalDirection.z,
            0,
            horizontalDirection.x
        )
        let normalizedHorizontalDirection = normalize(vector: horizontalDirection)
        let normalizedPerpendicularDirection = normalize(vector: perpendicularDirection)
        let gridSize = 40
        let spacing = Float(start.distance(to: end)) / Float(gridSize) // Distance between points
        for row in 0..<gridSize {
            for column in 0..<gridSize {
                let x = midPoint.x + Float(row - gridSize / 2) * spacing * normalizedHorizontalDirection.x
                let z = midPoint.z + Float(row - gridSize / 2) * spacing * normalizedHorizontalDirection.z
                let position = SCNVector3(
                    x + Float(column - gridSize / 2) * spacing * normalizedPerpendicularDirection.x,
                    0,
                    z + Float(column - gridSize / 2) * spacing * normalizedPerpendicularDirection.z
                )
                let depthY = getDepthValue(for: position.x, z: position.z, depthData: depthData) ?? midPoint.y
                let adjustedPosition = SCNVector3(position.x, depthY, position.z)
                let pointNode = createPoint(at: adjustedPosition)
                sceneView.scene.rootNode.addChildNode(pointNode)
                spheres.append(pointNode)
            }
        }
    }

    private func getDepthValue(for x: Float, z: Float, depthData: MTLTexture) -> Float? {
        let depthWidth = depthData.width
        let depthHeight = depthData.height
        let u = Int((x - cx) / fx * Float(depthWidth))
        let v = Int((z - cy) / fy * Float(depthHeight))

        if u < 0 || u >= depthWidth || v < 0 || v >= depthHeight {
            print("Coordinates out of bounds: (\(u), \(v))")
            return nil
        }
        var depthValue: Float = 0.0
        let region = MTLRegionMake2D(u, v, 1, 1)
        depthData.getBytes(&depthValue, bytesPerRow: MemoryLayout<Float>.stride, from: region, mipmapLevel: 0)
        print("Depth value at (\(u), \(v)): \(depthValue)")
        return depthValue
    }


    private func normalize(vector: SCNVector3) -> SCNVector3 {
        let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        guard length > 0 else { return SCNVector3(0, 0, 0) }
        return SCNVector3(vector.x / length, vector.y / length, vector.z / length)
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
