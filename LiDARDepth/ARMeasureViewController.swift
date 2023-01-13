import ARKit
import SceneKit
import UIKit

class ARMeasureViewController: UIViewController, ARSCNViewDelegate {
    
    var sceneView: ARSCNView!
    var startPoint: SCNNode?
    var endPoint: SCNNode?
    var lineNode: SCNNode?
    
    var distanceUpdated: ((Float) -> Void)? // Closure to update the SwiftUI view with the calculated distance
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the ARSCNView
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.scene = SCNScene()
        view.addSubview(sceneView)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        
        // Add tap gesture to detect user taps
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTap(gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        
        if let result = hitTestResults.first {
            // Create a 3D sphere at the tapped point
            let sphere = SCNSphere(radius: 0.01)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.red
            sphere.materials = [material]
            
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.position = SCNVector3(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
            sceneView.scene.rootNode.addChildNode(sphereNode)
            
            // Set the start and end points
            if startPoint == nil {
                startPoint = sphereNode
            } else if endPoint == nil {
                endPoint = sphereNode
                drawLineBetweenPoints()
                calculateDistance()
            } else {
                // Reset the points if both are already set
                startPoint?.removeFromParentNode()
                endPoint?.removeFromParentNode()
                lineNode?.removeFromParentNode()
                startPoint = sphereNode
                endPoint = nil
            }
        }
    }
    
    func drawLineBetweenPoints() {
        guard let start = startPoint, let end = endPoint else { return }
        
        // Create a line between the two points
        let line = SCNCylinder(radius: 0.001, height: CGFloat(distanceBetween(start: start.position, end: end.position)))
        line.firstMaterial?.diffuse.contents = UIColor.yellow
        
        lineNode = SCNNode(geometry: line)
        lineNode?.position = SCNVector3(
            (start.position.x + end.position.x) / 2,
            (start.position.y + end.position.y) / 2,
            (start.position.z + end.position.z) / 2
        )
        lineNode?.look(at: end.position)
        
        sceneView.scene.rootNode.addChildNode(lineNode!)
    }
    
    func calculateDistance() {
        guard let start = startPoint, let end = endPoint else { return }
        
        let distance = distanceBetween(start: start.position, end: end.position)
        
        // Pass the calculated distance to SwiftUI using the closure
        distanceUpdated?(distance * 100) // Convert to cm
    }
    
    func distanceBetween(start: SCNVector3, end: SCNVector3) -> Float {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dz = end.z - start.z
        return sqrtf(dx * dx + dy * dy + dz * dz)
    }
}
