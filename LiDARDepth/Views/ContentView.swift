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
    @State private var showBallToast = false
    @State private var showHoleCupToast = false
    @State private var isTapped = false
    
    @State private var horizontalDistance: Double = 0.0
    @State private var verticalDistance: Float = 0.0

    @State private var isInit: Bool = false
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
                                tapLocation1 = nil
                                tapLocation2 = nil
                            }
                        }
                )
                
                ARView(verticalDistance: $verticalDistance, distanceBetweenPoints: $distanceBetweenPoints, isTapped: $isTapped, showBallToast: $showBallToast, showHoleCupToast: $showHoleCupToast)
                    .edgesIgnoringSafeArea(.all)
                
                if showBallToast {
                    ToastView(message: "ballMsg".localized())
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showBallToast = false
                                }
                            }
                        }
                }
                
                if showHoleCupToast {
                    ToastView(message: "holeCupMsg".localized())
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showHoleCupToast = false
                                }
                            }
                        }
                }
                
                
             
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showBallToast = true
            }
        }
    }
    

}

struct ARView: UIViewRepresentable {
    @Binding var verticalDistance: Float

    @Binding var distanceBetweenPoints: Float?
    @Binding var isTapped: Bool
    @Binding var showBallToast: Bool
    @Binding var showHoleCupToast: Bool
    var sceneView = ARSCNView()
    var spheres: [SCNNode] = []
    var tappedPoints: [SCNVector3] = []
    var lineNode: SCNNode?
    var curveNode: SCNNode?
    var planeNode: SCNNode?
    var baseLayer: CAGradientLayer?
    var circleView: UIImageView?

    
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
        private var isSessionInitialized = false
        private var feedbackCircles: [UIView] = []
        
        init(_ parent: ARView) {
            self.parent = parent
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            
            let cameraTransform = frame.camera.transform
            let cameraPosition = cameraTransform.columns.3

            _ = cameraPosition.z
            
            
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
            if !parent.isTapped {
                parent.isTapped = true
                parent.showBallToast = false
                parent.showHoleCupToast = true
            }
            
            if parent.tappedPoints.count == 2 {

                parent.clearPoints()
                parent.clearPoints()  // Clear previous points and line
                clearFeedbackCircles()
                parent.baseLayer?.removeFromSuperlayer()
                parent.circleView?.removeFromSuperview()
            }
            
            parent.addPoint(position)
            showTap(at: CGPoint(x: CGFloat(parent.sceneView.projectPoint(position).x),
                                y: CGFloat(parent.sceneView.projectPoint(position).y)))
            
            if parent.tappedPoints.count == 2 {
                let distance = parent.tappedPoints[0].distance(to: parent.tappedPoints[1])
                parent.distanceBetweenPoints = distance
                parent.drawLineBetweenPoints()
                parent.drawDensePointCloudWithDepth()
                parent.drawCurveBetweenPoints()
                parent.drawSquareBetweenPoints()
                parent.drawDensePointCloudBetweenPoints()

            }
        }
        
        private func showTap(at point: CGPoint) {
            let feedbackCircle = UIView(frame: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
            feedbackCircle.backgroundColor = UIColor.red.withAlphaComponent(0.6)
            feedbackCircle.layer.cornerRadius = 10
            feedbackCircle.alpha = 1.0
            parent.sceneView.addSubview(feedbackCircle)
            
            feedbackCircles.append(feedbackCircle)
        }
        
        private func clearFeedbackCircles() {
            for circle in feedbackCircles {
                circle.removeFromSuperview()
            }
            feedbackCircles.removeAll() // 배열 초기화
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
        material.diffuse.contents = UIColor.clear
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
    
    mutating func drawCurveBetweenPoints() {
        guard tappedPoints.count == 2 else { return }
        
        let start3D = tappedPoints[0]
        let end3D = tappedPoints[1]
        
        // Convert 3D coordinates to 2D screen points
        let startScreenPoint = sceneView.projectPoint(start3D)
        let endScreenPoint = sceneView.projectPoint(end3D)
        
        print("startScreenPoint: \(startScreenPoint)")
        print("endScreenPoint: \(endScreenPoint)")
        
        guard !startScreenPoint.x.isNaN, !startScreenPoint.y.isNaN,
              !endScreenPoint.x.isNaN, !endScreenPoint.y.isNaN else {
            print("Invalid screen points")
            return
        }
        
        let start = CGPoint(x: CGFloat(startScreenPoint.x), y: CGFloat(startScreenPoint.y))
        let end = CGPoint(x: CGFloat(endScreenPoint.x), y: CGFloat(endScreenPoint.y))
        
        print("start: \(start)")
        print("end: \(end)")
        // Draw the curve with animation
        drawCurve(from: start, to: end, color: UIColor.red)
    }
    
    private mutating func drawCurve(from start: CGPoint, to end: CGPoint, color: UIColor) {
        
        let midY = (start.y + end.y) / 2
        let controlPoint = CGPoint(x: (start.x + end.x) / 2, y: midY - 100)
        //let controlPoint = CGPoint(x: 20, y: midY)
        
        let path = UIBezierPath()
        path.move(to: start)
        path.addQuadCurve(to: end, controlPoint: controlPoint)
        
        // CAShapeLayer for the curve path
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.lineWidth = 15
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeEnd = 0
        
        // CAGradientLayer for gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = sceneView.bounds
        gradientLayer.colors = [
            color.withAlphaComponent(1.0).cgColor,
            color.withAlphaComponent(0.2).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.4)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1.0)
        gradientLayer.mask = shapeLayer
        sceneView.layer.addSublayer(gradientLayer)
        
        animateRollingCircleAlongPath(path: path)
        animateCurve(layer: shapeLayer)
        baseLayer = gradientLayer
    }
    
    private func animateCurve(layer: CAShapeLayer) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 1.5
        animation.fillMode = .forwards
        animation.isRemovedOnCompletion = false
        layer.add(animation, forKey: "lineAnimation")
    }
    
    private mutating func animateRollingCircleAlongPath(path: UIBezierPath) {
        let circle = UIImageView(image: UIImage(named: "ball2"))
        circle.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        circle.layer.cornerRadius = 10
        circle.clipsToBounds = true
        circle.layer.shadowColor = UIColor.black.cgColor
        circle.layer.shadowOpacity = 0.5
        circle.layer.shadowOffset = CGSize(width: -3, height: -3)
        circle.layer.shadowRadius = 4
        circle.layer.zPosition = 1
        sceneView.addSubview(circle)
        
        let positionAnimation = CAKeyframeAnimation(keyPath: "position")
        positionAnimation.path = path.cgPath
        positionAnimation.duration = 1.5
        positionAnimation.rotationMode = .rotateAuto
        positionAnimation.fillMode = .forwards
        positionAnimation.isRemovedOnCompletion = false
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = Double.pi * 2
        rotationAnimation.duration = 1.5
        rotationAnimation.repeatCount = .infinity
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [positionAnimation, rotationAnimation]
        animationGroup.duration = 1.5
        animationGroup.fillMode = .forwards
        animationGroup.isRemovedOnCompletion = false
        
        circle.layer.add(animationGroup, forKey: "rollingCircleAnimation")
        
        circleView = circle
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


extension String {
    func localized(comment: String = "") -> String {
        return NSLocalizedString(self, comment: comment)
    }
    
}
