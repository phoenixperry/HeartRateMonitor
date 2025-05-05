import SwiftUI
import MetalKit

//// MARK: - Metal Shader View
//struct MetalShaderView: NSViewRepresentable {
//    var playerHeartRates: [Int]
//    var synchronizationLevel: Double
//    
//    func makeNSView(context: Context) -> MTKView {
//        let view = MTKView()
//        view.device = MTLCreateSystemDefaultDevice()
//        view.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
//        view.delegate = context.coordinator
//        view.drawableSize = view.frame.size
//        view.framebufferOnly = false
//        
//        context.coordinator.setup(view: view, heartRates: playerHeartRates, syncLevel: synchronizationLevel)
//        return view
//    }
//    
//    func updateNSView(_ nsView: MTKView, context: Context) {
//        context.coordinator.updateHeartRates(playerHeartRates)
//        context.coordinator.updateSyncLevel(synchronizationLevel)
//    }
//    
//    func makeCoordinator() -> Coordinator {
//        Coordinator()
//    }
//    
//    class Coordinator: NSObject, MTKViewDelegate {
//        private var device: MTLDevice!
//        private var commandQueue: MTLCommandQueue!
//        private var pipelineState: MTLRenderPipelineState!
//        private var vertices: MTLBuffer!
//        private var indices: MTLBuffer!
//        private var uniforms: MTLBuffer!
//        
//        // Timing and data
//        private var startTime: CFTimeInterval!
//        private var lastUpdateTime: CFTimeInterval = 0
//        private var heartRates: [Float] = [60, 60, 60]
//        private var lastPulseTimes: [CFTimeInterval] = [0, 0, 0]
//        private var syncLevel: Float = 0.5
//        
//        func setup(view: MTKView, heartRates: [Int], syncLevel: Double) {
//            self.device = view.device!
//            self.commandQueue = device.makeCommandQueue()
//            self.startTime = CACurrentMediaTime()
//            
//            setupRenderPipeline(view: view)
//            setupGeometry()
//            
//            updateHeartRates(heartRates)
//            updateSyncLevel(syncLevel)
//        }
//        
//        func updateHeartRates(_ rates: [Int]) {
//            for i in 0..<min(rates.count, 3) {
//                heartRates[i] = Float(max(rates[i], 1))
//            }
//        }
//        
//        func updateSyncLevel(_ level: Double) {
//            syncLevel = Float(level)
//        }
//        
//        // MARK: - MTKViewDelegate
//        
//        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
//            // Handle resize if needed
//        }
//        
//        func draw(in view: MTKView) {
//            guard let drawable = view.currentDrawable,
//                  let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
//            
//            let currentTime = Float(CACurrentMediaTime() - startTime)
//            
//            // Update uniforms
//            let uniformsPtr = uniforms.contents().bindMemory(to: Uniforms.self, capacity: 1)
//            uniformsPtr.pointee.time = currentTime
//            uniformsPtr.pointee.heartRates = heartRates
//            uniformsPtr.pointee.syncLevel = syncLevel
//            
//            // Check for pulse triggers
//            for i in 0..<3 {
//                let interval = 60.0 / Double(heartRates[i])
//                if CACurrentMediaTime() - lastPulseTimes[i] >= interval {
//                    // Trigger a pulse
//                    uniformsPtr.pointee.pulseTimers[i] = currentTime
//                    lastPulseTimes[i] = CACurrentMediaTime()
//                }
//            }
//            
//            // Create command buffer
//            guard let commandBuffer = commandQueue.makeCommandBuffer(),
//                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
//            
//            renderEncoder.setRenderPipelineState(pipelineState)
//            renderEncoder.setVertexBuffer(vertices, offset: 0, index: 0)
//            renderEncoder.setVertexBuffer(uniforms, offset: 0, index: 1)
//            renderEncoder.setFragmentBuffer(uniforms, offset: 0, index: 0)
//            renderEncoder.drawIndexedPrimitives(type: .triangle,
//                                               indexCount: 6,
//                                               indexType: .uint16,
//                                               indexBuffer: indices,
//                                               indexBufferOffset: 0)
//            
//            renderEncoder.endEncoding()
//            commandBuffer.present(drawable)
//            commandBuffer.commit()
//        }
//        
//        // MARK: - Setup Methods
//        
//        private func setupRenderPipeline(view: MTKView) {
//            let library = try! device.makeDefaultLibrary(bundle: Bundle.main)
//            let vertexFunction = library.makeFunction(name: "resonanceVertex")
//            let fragmentFunction = library.makeFunction(name: "resonanceFragment")
//            
//            let pipelineDescriptor = MTLRenderPipelineDescriptor()
//            pipelineDescriptor.vertexFunction = vertexFunction
//            pipelineDescriptor.fragmentFunction = fragmentFunction
//            pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
//            
//            self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
//        }
//        
//        private func setupGeometry() {
//            // Create a full-screen quad
//            let quadVertices: [Float] = [
//                -1.0, -1.0, 0.0, 0.0, 1.0,  // bottom left
//                 1.0, -1.0, 0.0, 1.0, 1.0,  // bottom right
//                 1.0,  1.0, 0.0, 1.0, 0.0,  // top right
//                -1.0,  1.0, 0.0, 0.0, 0.0   // top left
//            ]
//            
//            let quadIndices: [UInt16] = [
//                0, 1, 2,
//                0, 2, 3
//            ]
//            
//            vertices = device.makeBuffer(bytes: quadVertices,
//                                         length: quadVertices.count * MemoryLayout<Float>.size,
//                                         options: [])
//            
//            indices = device.makeBuffer(bytes: quadIndices,
//                                        length: quadIndices.count * MemoryLayout<UInt16>.size,
//                                        options: [])
//            
//            let uniformsSize = MemoryLayout<Uniforms>.size
//            uniforms = device.makeBuffer(length: uniformsSize, options: [])
//        }
//    }
//    
//    // MARK: - Uniform Structure (shared with shader)
//    struct Uniforms {
//        var time: Float = 0
//        var heartRates: [Float] = [60, 60, 60]
//        var pulseTimers: [Float] = [0, 0, 0]
//        var syncLevel: Float = 0
//    }
//}
