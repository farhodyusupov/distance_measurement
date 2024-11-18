//
//  ARMeasureViewController.swift
//  LiDARDepth
//
//  Created by Farkhod on 11/5/24.
//  Copyright © 2024 Apple. All rights reserved.
//


import ARKit
import SceneKit
import UIKit

class ARMeasureViewController: UIViewController, ARSCNViewDelegate {
    
    var sceneView: ARSCNView!
    var startPoint: SCNNode?
    var endPoint: SCNNode?
    var lineNode: SCNNode?
    
    var distanceUpdated: ((Float) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        sceneView = ARSCNView(frame: view.bounds)
        sceneView.delegate = self
        sceneView.scene = SCNScene()
        view.addSubview(sceneView)
        
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        

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
            
            
            if startPoint == nil {
                startPoint = sphereNode
            } else if endPoint == nil {
                endPoint = sphereNode
                drawLineBetweenPoints()
                calculateDistance()
            } else {
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
        
        // Calculate the vector between the start and end points
        let vector = SCNVector3(
            end.position.x - start.position.x,
            end.position.y - start.position.y,
            end.position.z - start.position.z
        )
        
        // Calculate the distance between the two points
        let distance = distanceBetween(start: start.position, end: end.position)
        
        // Create a cylinder with the calculated distance as its height
        let line = SCNCylinder(radius: 0.001, height: CGFloat(distance))
        line.firstMaterial?.diffuse.contents = UIColor.yellow
        
        // Create a node for the line and position it at the midpoint
        lineNode = SCNNode(geometry: line)
        lineNode?.position = SCNVector3(
            (start.position.x + end.position.x) / 2,
            (start.position.y + end.position.y) / 2,
            (start.position.z + end.position.z) / 2
        )
        
        // Calculate the rotation to align the cylinder along the vector
        let yAxis = SCNVector3(0, 1, 0)
        let axis = crossProduct(of: yAxis, and: vector)
        let angle = acos(dotProduct(of: yAxis, and: vector) / (length(of: yAxis) * length(of: vector)))
        lineNode?.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        
        // Add the line to the scene
        sceneView.scene.rootNode.addChildNode(lineNode!)
    }

    // Helper functions for vector math
    func crossProduct(of a: SCNVector3, and b: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        )
    }

    func dotProduct(of a: SCNVector3, and b: SCNVector3) -> Float {
        return a.x * b.x + a.y * b.y + a.z * b.z
    }

    func length(of vector: SCNVector3) -> Float {
        return sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    }

    
    func calculateDistance() {
        guard let start = startPoint, let end = endPoint else { return }
        
        let distance = distanceBetween(start: start.position, end: end.position)
        
        distanceUpdated?(distance * 100)
    }
    
    func distanceBetween(start: SCNVector3, end: SCNVector3) -> Float {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dz = end.z - start.z
        return sqrtf(dx * dx + dy * dy + dz * dz)
    }
}
