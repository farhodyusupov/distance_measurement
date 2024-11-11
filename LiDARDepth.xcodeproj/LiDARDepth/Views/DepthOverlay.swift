/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view that shows the depth image on top of the color image with a slider
 to adjust the depth layer's opacity.
*/

import SwiftUI
import SwiftUI

struct DepthOverlay: View {
    @ObservedObject var manager: CameraManager
    
    var body: some View {
        VStack {
            if manager.dataAvailable {
                Text("Data is available")
                    .foregroundColor(.green)
            } else {
                Text("No data available")
                    .foregroundColor(.red)
            }
        }
    }
}

