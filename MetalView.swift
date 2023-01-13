import SwiftUI
import MetalKit

struct MetalView: UIViewRepresentable {
    @Binding var renderer: Renderer?

    func makeUIView(context: Context) -> MTKView {
        // Create a Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }

        // Create a MetalKit view with the Metal device
        let mtkView = MTKView(frame: .zero, device: device)

        // Set the delegate (which is the renderer)
        mtkView.delegate = renderer
        mtkView.preferredFramesPerSecond = 60
        mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0) // Black background
        mtkView.colorPixelFormat = .bgra8Unorm // Pixel format for rendering

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        // Update the renderer if necessary
        if let renderer = renderer {
            uiView.delegate = renderer
        }
    }
}
