//
//  ARMeasureView.swift
//  LiDARDepth
//
//  Created by Farkhod on 11/5/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftUI
import ARKit

struct ARMeasureView: UIViewControllerRepresentable {
    @Binding var distance: Float
        
        func makeUIViewController(context: Context) -> ARMeasureViewController {
            let viewController = ARMeasureViewController()
            viewController.distanceUpdated = { newDistance in
                self.distance = newDistance
            }
            return viewController
        }
    
    func updateUIViewController(_ uiViewController: ARMeasureViewController, context: Context) {
        
    }
}
