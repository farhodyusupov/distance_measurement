import SwiftUI
import Combine
import MetalKit
import Metal
import SceneKit

struct MetalTextureColorThresholdDepthView: UIViewRepresentable, MetalRepresentable {
    var rotationAngle: Double

    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    var capturedData: CameraCapturedData
    
    @Binding var tapLocation1: CGPoint?
    @Binding var tapLocation2: CGPoint?
    @Binding var distanceToPoint1: Float?
    @Binding var distanceToPoint2: Float?
    
    var fx: Float = 500.0
    var fy: Float = 500.0
    var cx: Float = 160.0
    var cy: Float = 120.0
//    var targetArea: CGRect
    func makeCoordinator() -> MTKColorThresholdDepthTextureCoordinator {
        MTKColorThresholdDepthTextureCoordinator(parent: self)
    }
    
    func renderDepthMapForSquare(from start: CGPoint, to end: CGPoint) {
        makeCoordinator().createDepthMapOfSquare(from: start, to: end)
    }
}

final class MTKColorThresholdDepthTextureCoordinator: MTKCoordinator<MetalTextureColorThresholdDepthView> {
    
    func createDepthMapOfSquare(from start: CGPoint, to end: CGPoint) {
        guard let depthTexture = parent.capturedData.depth else { return }
        
        // Define grid resolution within the square
        let gridCount = 10  // Adjust for density
        let widthStep = (end.x - start.x) / CGFloat(gridCount)
        let heightStep = (end.y - start.y) / CGFloat(gridCount)
        
        for i in 0..<gridCount {
            for j in 0..<gridCount {
                let x = start.x + CGFloat(i) * widthStep
                let y = start.y + CGFloat(j) * heightStep
                let point = CGPoint(x: x, y: y)
                
                if let depth = get3DDistanceAtPoint(point) {
                    visualizeDepthPoint(at: point, with: depth)
                }
            }
        }
    }

    private func visualizeDepthPoint(at point: CGPoint, with depth: Float) {
        var colorValue = min(1.0, max(0.0, (depth - parent.minDepth) / (parent.maxDepth - parent.minDepth)))
        let color = UIColor(hue: CGFloat(colorValue), saturation: 1.0, brightness: 1.0, alpha: 1.0)
        
        let metalX = Float(point.x / mtkView.drawableSize.width) * 2 - 1
        let metalY = Float(point.y / mtkView.drawableSize.height) * 2 - 1

        var vertexData: [Float] = [
            metalX - 0.01, metalY - 0.01, 0, 1,
            metalX + 0.01, metalY - 0.01, 1, 0,
            metalX - 0.01, metalY + 0.01, 0, 1,
            metalX + 0.01, metalY + 0.01, 1, 1
        ]

        guard let commandBuffer = metalCommandQueue.makeCommandBuffer(),
              let passDescriptor = mtkView.currentRenderPassDescriptor,
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }
        
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&colorValue, length: MemoryLayout<Float>.stride, index: 0)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        
        commandBuffer.present(mtkView.currentDrawable!)
        commandBuffer.commit()
    }

    private func get3DDistanceAtPoint(_ point: CGPoint) -> Float? {
        guard let depthTexture = parent.capturedData.depth else { return nil }
        
        let textureWidth = depthTexture.width
        let textureHeight = depthTexture.height
        let viewWidth = mtkView.drawableSize.width
        let viewHeight = mtkView.drawableSize.height

        let textureX = Int((point.x / viewWidth) * CGFloat(textureWidth))
        let textureY = Int((point.y / viewHeight) * CGFloat(textureHeight))

        guard textureX >= 0 && textureX < textureWidth && textureY >= 0 && textureY < textureHeight else {
            return nil
        }

        var depthValueRaw: UInt16 = 0
        let region = MTLRegionMake2D(textureX, textureY, 1, 1)
        depthTexture.getBytes(&depthValueRaw,
                              bytesPerRow: MemoryLayout<UInt16>.size * textureWidth,
                              from: region,
                              mipmapLevel: 0)

        let depthValue = float16to32(depthValueRaw)
        
        if depthValue <= 0.0 {
            return nil
        }

        let z = depthValue
        let x = (Float(textureX) - parent.cx) * z / parent.fx
        let y = (Float(textureY) - parent.cy) * z / parent.fy
        let convertedPoint = SCNVector3(x, y, z)
        print("Converted 3D Point:", convertedPoint)

        return sqrt(x * x + y * y + z * z)
    }

    override func preparePipelineAndDepthState() {
        guard let metalDevice = mtkView.device else { fatalError("Expected a Metal device.") }
        do {
            let library = MetalEnvironment.shared.metalLibrary
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "planeVertexShader")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: "planeFragmentShaderColorThresholdDepth")
            pipelineDescriptor.vertexDescriptor = createPlaneMetalVertexDescriptor()
            pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            let depthDescriptor = MTLDepthStencilDescriptor()
            depthDescriptor.isDepthWriteEnabled = true
            depthDescriptor.depthCompareFunction = .less
            depthState = metalDevice.makeDepthStencilState(descriptor: depthDescriptor)
        } catch {
            print("Unexpected error: \(error).")
        }
    }
    
    override func draw(in view: MTKView) {
        guard parent.capturedData.colorY != nil && parent.capturedData.colorCbCr != nil else {
            print("There's no content to display.")
            return
        }
        guard let commandBuffer = metalCommandQueue.makeCommandBuffer() else { return }
        guard let passDescriptor = view.currentRenderPassDescriptor else { return }
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else { return }

        let vertexData: [Float] = [
            -1, -1, 1, 1,
             1, -1, 1, 0,
            -1,  1, 0, 1,
             1,  1, 0, 0
        ]
        encoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&parent.minDepth, length: MemoryLayout<Float>.stride, index: 0)
        encoder.setFragmentBytes(&parent.maxDepth, length: MemoryLayout<Float>.stride, index: 1)
        encoder.setFragmentTexture(parent.capturedData.depth!, index: 2)
        encoder.setFragmentTexture(parent.capturedData.colorY!, index: 0)
        encoder.setFragmentTexture(parent.capturedData.colorCbCr!, index: 1)
        encoder.setDepthStencilState(depthState)
        encoder.setRenderPipelineState(pipelineState)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()

        if let tapLocation1 = parent.tapLocation1 {
            parent.distanceToPoint1 = get3DDistanceAtPoint(tapLocation1)
        }
        if let tapLocation2 = parent.tapLocation2 {
            parent.distanceToPoint2 = get3DDistanceAtPoint(tapLocation2)
        }
    }

    func float16to32(_ value: UInt16) -> Float {
        let exponent = Int((value >> 10) & 0x1F) - 15
        let fraction = Float(value & 0x3FF) / Float(1 << 10) + 1.0
        return (value & 0x8000 != 0 ? -1.0 : 1.0) * fraction * pow(2.0, Float(exponent))
    }
}
