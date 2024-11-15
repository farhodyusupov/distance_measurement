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
                    //                    Circle()
                    //                        .fill(Color.red)
                    //                        .frame(width: 10, height: 10)
                    //                        .position(x: location1.x, y: location1.y)
                }
                if let location2 = tapLocation2 {
                    //                    Circle()
                    //                        .fill(Color.blue)
                    //                        .frame(width: 10, height: 10)
                    //                        .position(x: location2.x, y: location2.y)
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
        private var feedbackCircles: [UIView] = []
        
        init(_ parent: ARView) {
            self.parent = parent
        }
        
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
                    // 세션이 초기화되고 앵커가 추가된 후 첫 번째 메시지 표시
                    if anchors.isEmpty == false {
                       // DispatchQueue.main.async {
                            self.parent.showToast(message: "공을 클릭해주세요")
                            print("공을 클릭해주세요")
                        //}
                    }
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
                clearFeedbackCircles()
                parent.baseLayer?.removeFromSuperlayer()
                parent.circleView?.removeFromSuperview()
            }
            
            parent.addPoint(position)
            showTap(at: CGPoint(x: CGFloat(parent.sceneView.projectPoint(position).x),
                                y: CGFloat(parent.sceneView.projectPoint(position).y)))
            if parent.tappedPoints.count == 1 {
                            // 첫 번째 클릭: '홀컵을 클릭하세요' 메시지 표시
                            parent.showToast(message: "홀컵을 클릭해주세요")
                        }
            
            if parent.tappedPoints.count == 2 {
                let distance = parent.tappedPoints[0].distance(to: parent.tappedPoints[1])
                parent.distanceBetweenPoints = distance
                parent.drawCurveBetweenPoints()
                parent.drawSquareBetweenPoints()
                //                parent.drawDensePointCloudBetweenPoints()
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
    
    func showToast(message : String, font: UIFont = UIFont.systemFont(ofSize: 14.0)) {
        let toastLabel = UILabel(frame:
                                    CGRect(x: sceneView.bounds.width + UIScreen.main.bounds.width/2 - 75,
                                           y: sceneView.frame.size.height + UIScreen.main.bounds.height/5 * 2,
                                           width: 150,
                                           height: 35)
                                 
        )
        toastLabel.backgroundColor = UIColor.black
        toastLabel.textColor = UIColor.white
        toastLabel.font = font
        toastLabel.textAlignment = .center;
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        sceneView.addSubview(toastLabel)
        UIView.animate(withDuration: 3.0, delay: 1.0, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
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



