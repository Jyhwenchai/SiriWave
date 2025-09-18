import UIKit
import QuartzCore

/**
 * 自定义Siri风格波形动画视图
 * 完美复刻SiriWave.js中的iOS9+波形效果
 * Custom UIView that renders Siri-style wave animation
 * Replicates the iOS9+ wave effect from SiriWave.js
 */
class SiriWaveView: UIView {

    // MARK: - 属性 / Properties
    /// 显示链接：用于60fps动画循环
    private var displayLink: CADisplayLink?
    /// 曲线管理器：管理所有颜色组的波形曲线
    private var curveManager: WaveCurveManager
    /// 动画状态：标记动画是否正在运行
    private var isAnimating: Bool = false

    // MARK: - 动画属性 / Animation Properties
    /// 全局相位：控制整体动画的时间进度
    private var phase: Double = 0.0
    /// 当前速度：动画的实际播放速度
    private var currentSpeed: Double = 0.2
    /// 当前振幅：动画的实际振幅大小
    private var currentAmplitude: Double = 1.0

    // MARK: - 插值目标 / Interpolation Targets
    /// 目标速度：插值动画的目标速度值
    private var targetSpeed: Double = 0.2
    /// 目标振幅：插值动画的目标振幅值
    private var targetAmplitude: Double = 1.0

    // MARK: - 配置参数 / Configuration
    /// 像素精度：控制波形绘制的X轴步进精度，值越小越平滑
    private let pixelDepth: Double = 0.02
    /// 插值速度：控制参数变化的平滑过渡速度
    private let lerpSpeed: Double = 0.1
    /// 最大高度：波形可用的最大垂直空间
    private var heightMax: CGFloat = 0

    // MARK: - 颜色配置 / Color Configuration
    /// 支持线颜色：中心辅助线的颜色（与JavaScript版本保持一致）
    private let supportLineColor = UIColor.white.withAlphaComponent(0.5)

    // MARK: - 初始化 / Initialization
    override init(frame: CGRect) {
        curveManager = WaveCurveManager()
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        curveManager = WaveCurveManager()
        super.init(coder: coder)
        setup()
    }

    /**
     * 初始化视图配置
     * 设置透明背景和重绘模式
     */
    private func setup() {
        backgroundColor = UIColor.clear
        contentMode = .redraw

        // 设置初始尺寸参数
        updateDimensions()
    }

    // MARK: - 布局 / Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        updateDimensions()
    }

    /**
     * 更新尺寸参数
     * 计算波形可用的最大高度（视图高度的一半减去边距）
     */
    private func updateDimensions() {
        heightMax = bounds.height / 2 - 6
    }

    // MARK: - 动画控制 / Animation Control
    /**
     * 开始波形动画
     * 创建CADisplayLink实现60fps的平滑动画
     * Start the wave animation
     */
    func start() {
        guard !isAnimating else { return }

        isAnimating = true
        phase = 0

        // 创建显示链接，绑定到主线程的common模式确保平滑动画
        displayLink = CADisplayLink(target: self, selector: #selector(animationStep))
        displayLink?.add(to: .main, forMode: .common)
    }

    /**
     * 停止波形动画
     * 清理显示链接并重置状态
     * Stop the wave animation
     */
    func stop() {
        guard isAnimating else { return }

        isAnimating = false
        phase = 0

        // 销毁显示链接，避免内存泄漏
        displayLink?.invalidate()
        displayLink = nil

        // 触发最后一次重绘，清除波形
        setNeedsDisplay()
    }

    /**
     * 设置动画振幅（支持平滑插值过渡）
     * Set animation amplitude with interpolation
     */
    func setAmplitude(_ amplitude: Double) {
        targetAmplitude = max(0, amplitude)
    }

    /**
     * 设置动画速度（支持平滑插值过渡）
     * Set animation speed with interpolation
     */
    func setSpeed(_ speed: Double) {
        targetSpeed = max(0, speed)
    }

    // MARK: - 动画循环 / Animation Loop
    /**
     * 动画步进函数（每帧调用）
     * 处理参数插值、曲线更新和重绘触发
     */
    @objc private func animationStep() {
        // 插值计算：平滑过渡到目标值
        interpolateValues()

        // 更新曲线管理器：传递最新的速度和振幅
        curveManager.setSpeed(currentSpeed)
        curveManager.setAmplitude(currentAmplitude)
        curveManager.update()

        // 更新全局相位：推进动画时间
        phase = WaveMath.normalizePhase(phase + (Double.pi / 2) * currentSpeed)

        // 触发重绘：更新视觉效果
        setNeedsDisplay()
    }

    /**
     * 参数插值计算
     * 使用线性插值实现振幅和速度的平滑过渡
     */
    private func interpolateValues() {
        // 振幅插值：平滑过渡到目标振幅
        if abs(currentAmplitude - targetAmplitude) > 0.001 {
            currentAmplitude = WaveMath.lerp(
                from: currentAmplitude,
                to: targetAmplitude,
                t: lerpSpeed
            )
        }

        // 速度插值：平滑过渡到目标速度
        if abs(currentSpeed - targetSpeed) > 0.001 {
            currentSpeed = WaveMath.lerp(
                from: currentSpeed,
                to: targetSpeed,
                t: lerpSpeed
            )
        }
    }

    // MARK: - 绘制 / Drawing
    /**
     * 主绘制函数
     * 设置绘图上下文并调用波形绘制
     */
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 清除上下文，设置透明背景
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(rect)

        // 设置全局透明度
        context.setAlpha(1.0)

        // 设置混合模式：使用lighten模式实现颜色叠加效果
      context.setBlendMode(.plusLighter)

        // 绘制所有波形曲线
        drawWaves(in: context)
    }

    /**
     * 绘制支持线（中心辅助线）
     * 使用渐变效果创建1像素高的水平线
     */
    private func drawSupportLine(in context: CGContext) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.clear.cgColor,
                supportLineColor.cgColor,
                supportLineColor.cgColor,
                UIColor.clear.cgColor
            ] as CFArray,
            locations: [0.0, 0.1, 0.9, 1.0]
        )

        guard let gradientRef = gradient else { return }

        // 保存图形状态
        context.saveGState()

        // 创建1像素高的矩形作为支持线区域
        let supportRect = CGRect(x: 0, y: heightMax - 0.5, width: bounds.width, height: 1)

        // 裁剪到支持线矩形区域
        context.clip(to: supportRect)

        // 在裁剪区域内绘制水平渐变
        let startPoint = CGPoint(x: 0, y: heightMax)
        let endPoint = CGPoint(x: bounds.width, y: heightMax)

        context.drawLinearGradient(
            gradientRef,
            start: startPoint,
            end: endPoint,
            options: []
        )

        // 恢复图形状态
        context.restoreGState()
    }

    /**
     * 绘制所有波形
     * 分别绘制红、绿、蓝三个颜色组，每组内的曲线合并为单个波形
     */
    private func drawWaves(in context: CGContext) {
        // 绘制每个颜色组为单个合并波形
        drawMergedColorGroup(curveManager.getRedCurves(), color: WaveCurve.WaveColor.red.uiColor, in: context)
        drawMergedColorGroup(curveManager.getGreenCurves(), color: WaveCurve.WaveColor.green.uiColor, in: context)
        drawMergedColorGroup(curveManager.getBlueCurves(), color: WaveCurve.WaveColor.blue.uiColor, in: context)

        // 最后绘制支持线
        if curveManager.getSupportCurve() != nil {
            drawSupportLine(in: context)
        }
    }

    /**
     * 绘制合并的颜色组
     * 将同色的多个曲线合并为一个波形，实现更自然的分布
     */
    private func drawMergedColorGroup(_ curves: [WaveCurve], color: UIColor, in context: CGContext) {
        guard !curves.isEmpty else { return }

        // 计算该组的平均振幅
        let groupAmplitude = curves.reduce(0.0) { $0 + $1.amplitude } / Double(curves.count)

        // 根据第一个曲线的颜色类型获取动态颜色
        let finalColor: UIColor
        if let firstCurve = curves.first {
            finalColor = firstCurve.waveColor.dynamicColor(amplitude: groupAmplitude)
        } else {
            finalColor = color
        }

        // 绘制正负两个方向的波形（镜像对称）
        for sign in [1.0, -1.0] {
            drawMergedWaveWithColor(curves, color: finalColor, sign: sign, in: context)
        }
    }

    /**
     * 绘制具有指定颜色的合并波形
     * 核心算法：将同组内所有曲线的Y值相加后取平均，模拟JavaScript版本的实现
     */
    private func drawMergedWaveWithColor(_ curves: [WaveCurve], color: UIColor, sign: Double, in context: CGContext) {
        context.beginPath()

        // 通过合并组内所有曲线来计算波形点
        var x = -WaveMath.graphX
        while x <= WaveMath.graphX {
            let xPos = WaveMath.xPosition(i: x, width: Double(bounds.width))

            // 计算该组内所有曲线的组合Y值（与JavaScript版本一致）
            var combinedY: Double = 0
            for (index, curve) in curves.enumerated() {
                let relativeY = curve.calculateY(at: x, totalCurves: curves.count, curveIndex: index)
                combinedY += relativeY
            }

            // 按曲线数量标准化（如JavaScript中的: y / this.noOfCurves）
            combinedY = combinedY / Double(curves.count)

            // 计算最终的Y坐标：应用振幅因子、高度限制、当前振幅和全局衰减
            let yPos = WaveMath.amplitudeFactor *
                      Double(heightMax) *
                      currentAmplitude *
                      combinedY *
                      WaveMath.globalAttenuation(x: (x / WaveMath.graphX) * 2)

            let finalY = Double(heightMax) - sign * yPos

            // 构建路径：第一个点移动到，后续点连线到
            if x == -WaveMath.graphX {
                context.move(to: CGPoint(x: xPos, y: finalY))
            } else {
                context.addLine(to: CGPoint(x: xPos, y: finalY))
            }

            x += pixelDepth
        }

        // 用指定颜色填充合并的波形
        context.closePath()
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    /**
     * 绘制单个波形曲线（备用函数，当前未使用）
     * 用于绘制独立的单条曲线，不进行合并
     */
    private func drawSingleWaveWithColor(_ curve: WaveCurve, color: UIColor, sign: Double, in context: CGContext) {
        context.beginPath()

        let totalCurves = curveManager.getTotalCurveCount()

        // 计算波形点
        var x = -WaveMath.graphX
        while x <= WaveMath.graphX {
            let xPos = WaveMath.xPosition(i: x, width: Double(bounds.width))

            // 仅计算此单个曲线的Y值
            let relativeY = curve.calculateY(at: x, totalCurves: totalCurves)

            let yPos = WaveMath.amplitudeFactor *
                      Double(heightMax) *
                      currentAmplitude *
                      relativeY *
                      WaveMath.globalAttenuation(x: (x / WaveMath.graphX) * 2)

            let finalY = Double(heightMax) - sign * yPos

            if x == -WaveMath.graphX {
                context.move(to: CGPoint(x: xPos, y: finalY))
            } else {
                context.addLine(to: CGPoint(x: xPos, y: finalY))
            }

            x += pixelDepth
        }

        // 用指定颜色填充波形
        context.closePath()
        context.setFillColor(color.cgColor)
        context.fillPath()
    }

    // MARK: - 清理 / Cleanup
    deinit {
        stop()
    }
}

// MARK: - 公共API扩展 / Public API Extension
extension SiriWaveView {

    /**
     * 便捷方法：创建并配置波形视图
     * Convenience method to create and configure wave view
     */
    static func create(in container: UIView, autoStart: Bool = true) -> SiriWaveView {
        let waveView = SiriWaveView(frame: container.bounds)
        waveView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(waveView)

        if autoStart {
            waveView.start()
        }

        return waveView
    }

    /**
     * 检查动画是否正在运行
     * Check if animation is currently running
     */
    var isRunning: Bool {
        return isAnimating
    }

    /**
     * 获取当前振幅值
     * Get current amplitude value
     */
    var amplitude: Double {
        return currentAmplitude
    }

    /**
     * 获取当前速度值
     * Get current speed value
     */
    var speed: Double {
        return currentSpeed
    }
}
