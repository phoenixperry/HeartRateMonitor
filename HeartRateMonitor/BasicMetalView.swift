import SwiftUI
import MetalKit

struct BasicMetalView: NSViewRepresentable {
//    NSViewRepresentable, which is a protocol that lets you wrap a traditional AppKit view (in this case, an MTKView for Metal) so it can be used within SwiftUI.
    func makeNSView(context: Context) -> MTKView {
        //makeNSView(context:) - Creates the initial MTKView that will display your Metal content
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Nothing to update
        //updateNSView(_:context:) - Called when the view needs to update (currently empty)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
        //makeCoordinator() - Creates a coordinator object that will handle Metal rendering
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice!
        var commandQueue: MTLCommandQueue!
        var pipelineState: MTLRenderPipelineState!
        
        override init() {
            super.init()
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Device not created")
            }
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            do {
                // Create pipeline state
                let library = try device.makeDefaultLibrary(bundle: Bundle.main)
                let vertexFunction = library.makeFunction(name: "vertexShader")
                let fragmentFunction = library.makeFunction(name: "fragmentShader")
                
                let pipelineDescriptor = MTLRenderPipelineDescriptor()
                pipelineDescriptor.vertexFunction = vertexFunction
                pipelineDescriptor.fragmentFunction = fragmentFunction
                pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
                
                self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            } catch {
                print("Failed to create pipeline state: \(error)")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
