import Foundation
import UIKit
import MetalKit
import simd

/**
 * 基于 Metal 的 Siri 风格波形视图
 * 通过 GPU 渲染有效降低 CPU 占用并保持 60fps 动画
 */
public final class SiriWaveMetalView: MTKView {

    private struct SampleVertex {
        var values: SIMD2<Float>
    }

    private struct CurveParameters {
        var amplitude: Float
        var phase: Float
        var offset: Float
        var width: Float
        var verse: Float
        var padding: Float
        var index: Float
        var total: Float
    }

    private struct WaveUniforms {
        var height: Float
        var direction: Float
        var currentAmplitude: Float
        var graphX: Float
        var attenuationFactor: Float
        var amplitudeFactor: Float
        var sampleCount: UInt32
        var curveCount: UInt32
        var color: SIMD4<Float>
    }

    // MARK: - 常量
    private let maxCurvesPerColor: Int = WaveMath.defaultCurveRanges.max
    private let vertexSampleCount: Int = 512
    private let displayMargin: Float = 6.0

    // MARK: - Metal 资源
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?

    // MARK: - 动画状态
    private var curveManager = WaveCurveManager()
    private var isAnimating: Bool = false

    private var phase: Double = 0.0
    private var currentSpeed: Double = 0.2
    private var currentAmplitude: Double = 1.0
    private var targetSpeed: Double = 0.2
    private var targetAmplitude: Double = 1.0
    private let lerpSpeed: Double = 0.1

    // MARK: - 颜色
    private let redColor = SIMD4<Float>(173.0/255.0, 57.0/255.0, 76.0/255.0, 1.0)
    private let greenColor = SIMD4<Float>(48.0/255.0, 220.0/255.0, 155.0/255.0, 1.0)
    private let blueColor = SIMD4<Float>(15.0/255.0, 82.0/255.0, 169.0/255.0, 1.0)

    private var curveScratchBuffer: [CurveParameters] = []

    // MARK: - 初始化
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        let chosenDevice = device ?? MTLCreateSystemDefaultDevice()
        super.init(frame: frameRect, device: chosenDevice)
        commonInit()
    }

    public required init(coder: NSCoder) {
        let chosenDevice = MTLCreateSystemDefaultDevice()
        super.init(coder: coder)
        self.device = chosenDevice
        commonInit()
    }

    private func commonInit() {
        colorPixelFormat = .bgra8Unorm
        framebufferOnly = true
        isPaused = true
        enableSetNeedsDisplay = false
        preferredFramesPerSecond = 60
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        isOpaque = false

        delegate = self

        guard let device else {
            assertionFailure("Metal device is not available on this platform.")
            return
        }

        commandQueue = device.makeCommandQueue()
        buildPipeline(device: device)
        buildVertexBuffer(device: device)

        curveScratchBuffer = Array(
            repeating: CurveParameters(
                amplitude: 0,
                phase: 0,
                offset: 0,
                width: 1,
                verse: 1,
                padding: 0,
                index: 0,
                total: 1
            ),
            count: maxCurvesPerColor
        )
    }

    // MARK: - 公共 API
    public func start() {
        guard !isAnimating else { return }
        isAnimating = true
        isPaused = false
    }

    public func stop() {
        guard isAnimating else { return }
        isAnimating = false
        isPaused = true
    }

    public func setAmplitude(_ amplitude: Double) {
        targetAmplitude = max(0, amplitude)
    }

    public func setSpeed(_ speed: Double) {
        targetSpeed = max(0, speed)
    }

    public var isRunning: Bool {
        return isAnimating
    }

    public var amplitude: Double {
        return currentAmplitude
    }

    public var speed: Double {
        return currentSpeed
    }

    // MARK: - 资源构建
    private func buildPipeline(device: MTLDevice) {
        let library: MTLLibrary?
#if SWIFT_PACKAGE
        do {
            library = try makeShaderLibrary(for: device)
        } catch {
            assertionFailure("Unable to compile Metal shader functions: \(error)")
            return
        }
#else
        library = device.makeDefaultLibrary()
#endif

        guard
            let library,
            let vertexFunction = library.makeFunction(name: "siriWaveVertex"),
            let fragmentFunction = library.makeFunction(name: "siriWaveFragment")
        else {
            assertionFailure("Unable to load Metal shader functions.")
            return
        }

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SampleVertex>.stride
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            assertionFailure("Failed to create pipeline state: \(error)")
        }
    }

#if SWIFT_PACKAGE
    private func makeShaderLibrary(for device: MTLDevice) throws -> MTLLibrary {
        guard let shaderURL = Bundle.module.url(forResource: "default", withExtension: "metallib") else {
            throw NSError(
                domain: "SiriWaveMetalView",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate SiriWaveShaders.metal in package resources."]
            )
        }
//
//        let source = try String(contentsOf: shaderURL, encoding: .utf8)
//        let options = MTLCompileOptions()
//        options.preprocessorMacros = [:]
//        return try device.makeLibrary(source: source, options: options)
      return try device.makeLibrary(URL: shaderURL)
    }
#endif

    private func buildVertexBuffer(device: MTLDevice) {
        var vertices: [SampleVertex] = []
        vertices.reserveCapacity(vertexSampleCount * 2)

        for index in 0..<vertexSampleCount {
            let sampleIndex = Float(index)
            vertices.append(SampleVertex(values: SIMD2<Float>(sampleIndex, 0))) // baseline
            vertices.append(SampleVertex(values: SIMD2<Float>(sampleIndex, 1))) // wave
        }

        let length = vertices.count * MemoryLayout<SampleVertex>.stride
        vertexBuffer = device.makeBuffer(bytes: vertices, length: length, options: [])
    }

    // MARK: - 渲染循环
    private func updateInterpolations() {
        if abs(currentAmplitude - targetAmplitude) > 0.001 {
            currentAmplitude = WaveMath.lerp(
                from: currentAmplitude,
                to: targetAmplitude,
                t: lerpSpeed
            )
        }

        if abs(currentSpeed - targetSpeed) > 0.001 {
            currentSpeed = WaveMath.lerp(
                from: currentSpeed,
                to: targetSpeed,
                t: lerpSpeed
            )
        }
    }

    private func drawColorGroup(
        _ curves: [WaveCurve],
        color: SIMD4<Float>,
        encoder: MTLRenderCommandEncoder,
        direction: Float
    ) {
        let count = min(curves.count, maxCurvesPerColor)

        if count > 0 {
            for (offset, curve) in curves.prefix(count).enumerated() {
                curveScratchBuffer[offset] = CurveParameters(
                    amplitude: Float(curve.amplitude),
                    phase: Float(curve.phase),
                    offset: Float(curve.offset),
                    width: max(Float(curve.width), 0.0001),
                    verse: Float(curve.verse),
                    padding: 0,
                    index: Float(curve.curveIndex),
                    total: Float(curves.count)
                )
            }
        }

        var uniforms = WaveUniforms(
            height: Float(max(drawableSize.height / 2.0 - Double(displayMargin), 1)),
            direction: direction,
            currentAmplitude: Float(currentAmplitude),
            graphX: Float(WaveMath.graphX),
            attenuationFactor: Float(WaveMath.attenuationFactor),
            amplitudeFactor: Float(WaveMath.amplitudeFactor),
            sampleCount: UInt32(vertexSampleCount),
            curveCount: UInt32(count),
            color: color
        )

        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<WaveUniforms>.stride, index: 1)

        if count > 0 {
            let length = count * MemoryLayout<CurveParameters>.stride
            curveScratchBuffer.withUnsafeBytes { rawBuffer in
                if let baseAddress = rawBuffer.baseAddress {
                    encoder.setVertexBytes(baseAddress, length: length, index: 2)
                }
            }
        } else {
            encoder.setVertexBuffer(nil, offset: 0, index: 2)
        }

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertexSampleCount * 2)
    }
}

// MARK: - MTKViewDelegate
extension SiriWaveMetalView: MTKViewDelegate {
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // 当前实现不需要额外处理，保留方法以备未来扩展
    }

    public func draw(in view: MTKView) {
        guard
            isAnimating,
            let commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let renderPass = currentRenderPassDescriptor,
            let pipelineState,
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass)
        else {
            return
        }

        updateInterpolations()

        curveManager.setSpeed(currentSpeed)
        curveManager.setAmplitude(currentAmplitude)
        curveManager.update()

        phase = WaveMath.normalizePhase(phase + (Double.pi / 2) * currentSpeed)

        encoder.setRenderPipelineState(pipelineState)

        drawColorGroup(curveManager.getRedCurves(), color: redColor, encoder: encoder, direction: 1)
        drawColorGroup(curveManager.getRedCurves(), color: redColor, encoder: encoder, direction: -1)

        drawColorGroup(curveManager.getGreenCurves(), color: greenColor, encoder: encoder, direction: 1)
        drawColorGroup(curveManager.getGreenCurves(), color: greenColor, encoder: encoder, direction: -1)

        drawColorGroup(curveManager.getBlueCurves(), color: blueColor, encoder: encoder, direction: 1)
        drawColorGroup(curveManager.getBlueCurves(), color: blueColor, encoder: encoder, direction: -1)

        encoder.endEncoding()

        if let drawable = currentDrawable {
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }
}

// MARK: - 便捷创建
extension SiriWaveMetalView {
    public static func create(in container: UIView, autoStart: Bool = true) -> SiriWaveMetalView {
        let view = SiriWaveMetalView(frame: container.bounds)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(view)

        if autoStart {
            view.start()
        }

        return view
    }
}
