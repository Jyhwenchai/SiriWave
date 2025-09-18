import Foundation
import UIKit

/**
 * 单个波形曲线类
 * 表示Siri动画中的一个独立波形，包含其参数和生命周期管理
 */
public class WaveCurve {

    // MARK: - 波形参数 / Wave Parameters
    /// 相位：控制波形在时间轴上的位置，随时间变化产生动画效果
    var phase: Double = 0.0
    /// 当前振幅：波形的实际高度，会随时间淡入淡出
    var amplitude: Double = 0.0
    /// 目标振幅：波形的最终振幅值，当前振幅会逐渐接近此值
    var finalAmplitude: Double = 0.0
    /// 速度：控制相位变化的速度，影响波形移动快慢
    var speed: Double = 0.0
    /// 宽度：控制波形的"密度"，值越大波形越稀疏
    var width: Double = 0.0
    /// 偏移：波形在X轴上的随机偏移，用于分散多个波形
    var offset: Double = 0.0
    /// 方向：波形的移动方向 (+1或-1)
    var verse: Double = 0.0
    /// 消散超时：波形从出现到开始消失的时间（毫秒）
    var despawnTimeout: Double = 0.0
    /// 生成时间：记录波形创建的时间戳
    var spawnTime: TimeInterval = 0.0
    /// 曲线索引：在同组曲线中的位置索引
    var curveIndex: Int = 0
    /// 波形颜色：当前曲线的颜色类型
    var waveColor: WaveColor

    // MARK: - 波形颜色定义 / Wave Color Definition
    /**
     * 波形颜色枚举
     * 定义了Siri动画支持的四种颜色类型
     */
    public enum WaveColor {
        case red, green, blue, supportLine

        /// 基础UI颜色，匹配JavaScript原版的RGB值
        public var uiColor: UIColor {
            switch self {
            case .red:
                // 深红色：与原版SiriWave.js保持一致
                return UIColor(red: 173/255.0, green: 57/255.0, blue: 76/255.0, alpha: 1.0)
            case .green:
                // 青绿色：与原版SiriWave.js保持一致
                return UIColor(red: 48/255.0, green: 220/255.0, blue: 155/255.0, alpha: 1.0)
            case .blue:
                // 深蓝色：与原版SiriWave.js保持一致
                return UIColor(red: 15/255.0, green: 82/255.0, blue: 169/255.0, alpha: 1.0)
            case .supportLine:
                // 支持线：白色半透明
                return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
            }
        }

        /**
         * 动态颜色计算
         * 根据振幅调整颜色的透明度（当前简化实现，直接返回基础颜色）
         */
        public func dynamicColor(amplitude: Double) -> UIColor {
            return uiColor
            // 注释掉的代码：原本用于根据振幅调整透明度
            // 可以根据需要启用动态透明度效果
        }
    }

    // MARK: - 初始化 / Initialization
    /**
     * 创建新的波形曲线
     * - index: 曲线在组内的索引
     * - color: 波形颜色类型
     */
    public init(index: Int, color: WaveColor) {
        self.curveIndex = index
        self.waveColor = color
        spawn()
    }

    // MARK: - 生成逻辑 / Spawning Logic
    /**
     * 初始化曲线参数
     * 为曲线生成随机的物理参数，创造自然的波形效果
     */
    func spawn() {
        // 重置基础参数
        phase = 0.0
        amplitude = 0.0
        spawnTime = CACurrentMediaTime()

        // 生成随机参数：模拟真实物理波形的多样性
        despawnTimeout = WaveMath.randomInRange(WaveMath.defaultDespawnTimeoutRanges)
        offset = WaveMath.randomInRange(WaveMath.defaultOffsetRanges)
        speed = WaveMath.randomInRange(WaveMath.defaultSpeedRanges)
        finalAmplitude = WaveMath.randomInRange(WaveMath.defaultAmplitudeRanges)
        width = WaveMath.randomInRange(WaveMath.defaultWidthRanges)
        verse = WaveMath.randomInRange(min: -1.0, max: 1.0)
    }

    // MARK: - 动画更新 / Animation Update
    /**
     * 更新曲线状态（每帧调用）
     * 处理振幅的淡入淡出和相位的时间推进
     *
     * - globalSpeed: 全局动画速度
     * - totalCurves: 同组曲线总数
     */
    func update(globalSpeed: Double, totalCurves: Int) {
        let currentTime = CACurrentMediaTime()
        let elapsedTime = (currentTime - spawnTime) * 1000 // 转换为毫秒

        // 处理振幅的生命周期：淡入 -> 保持 -> 淡出
        if elapsedTime >= despawnTimeout {
            // 淡出阶段：逐渐减小振幅
            amplitude = max(0, amplitude - WaveMath.despawnFactor)
        } else {
            // 淡入阶段：逐渐增大到目标振幅
            amplitude = min(finalAmplitude, amplitude + WaveMath.despawnFactor)
        }

        // 更新相位：创造波形移动的动画效果
        // 相位的变化速度由全局速度、个体速度和速度因子共同决定
        phase = WaveMath.normalizePhase(
            phase + globalSpeed * speed * WaveMath.speedFactor
        )
    }

    // MARK: - 波形计算 / Wave Calculation
    /**
     * 计算波形在指定X坐标处的Y值
     *
     * - x: X坐标
     * - totalCurves: 总曲线数
     * - curveIndex: 可选的曲线索引覆盖值
     * - 返回: 该点的Y坐标值
     */
    func calculateY(at x: Double, totalCurves: Int, curveIndex: Int? = nil) -> Double {
        let useIndex = curveIndex ?? self.curveIndex
        return WaveMath.calculateCurveY(
            i: x,
            amplitude: amplitude,
            phase: phase,
            offset: offset,
            width: width,
            verse: verse,
            curveIndex: useIndex,
            totalCurves: totalCurves
        )
    }

    // MARK: - 生命周期管理 / Lifecycle Management
    /**
     * 检查曲线是否需要重新生成
     * 当振幅降为0且超过消散时间时，认为需要重新生成
     */
    func shouldRespawn() -> Bool {
        return amplitude <= 0 && CACurrentMediaTime() - spawnTime > despawnTimeout / 1000.0
    }

    /**
     * 重新生成曲线
     * 重置所有参数，开始新的生命周期
     */
    func respawn() {
        spawn()
    }
}

/**
 * 波形曲线管理器
 * 管理三组独立的彩色波形曲线，实现iOS9+风格的多色波形效果
 */
public class WaveCurveManager {

    // MARK: - 曲线组属性 / Curve Group Properties
    /// 红色曲线组：存储所有红色波形曲线
    private var redCurves: [WaveCurve] = []
    /// 绿色曲线组：存储所有绿色波形曲线
    private var greenCurves: [WaveCurve] = []
    /// 蓝色曲线组：存储所有蓝色波形曲线
    private var blueCurves: [WaveCurve] = []
    /// 支持线曲线：中心线条（可选）
    private var supportCurve: WaveCurve?

    /// 各颜色组的曲线数量
    private var numberOfRedCurves: Int = 0
    private var numberOfGreenCurves: Int = 0
    private var numberOfBlueCurves: Int = 0
    /// 上次重新生成检查的时间（性能优化）
    private var lastRespawnCheck: TimeInterval = 0

    // MARK: - 全局配置 / Global Configuration
    /// 全局动画速度：影响所有波形的移动速度
    var globalSpeed: Double = 0.2
    /// 全局振幅：影响所有波形的整体高度
    var globalAmplitude: Double = 1.0

    // MARK: - 初始化 / Initialization
    public init() {
        spawnAllCurves()
    }

    // MARK: - 曲线管理 / Curve Management
    /**
     * 生成所有颜色组的曲线
     * 为红、绿、蓝三种颜色各自创建独立的曲线组
     */
    private func spawnAllCurves() {
        spawnColorGroup(.red)
        spawnColorGroup(.green)
        spawnColorGroup(.blue)
        spawnSupportCurve()
    }

    /**
     * 生成指定颜色的曲线组
     * 每个颜色组随机生成2-5个曲线，确保视觉效果的丰富性
     */
    private func spawnColorGroup(_ color: WaveCurve.WaveColor) {
        let numberOfCurves = WaveMath.randomIntInRange(WaveMath.defaultCurveRanges)

        switch color {
        case .red:
            numberOfRedCurves = numberOfCurves
            redCurves.removeAll()
            for i in 0..<numberOfCurves {
                let curve = WaveCurve(index: i, color: .red)
                redCurves.append(curve)
            }
        case .green:
            numberOfGreenCurves = numberOfCurves
            greenCurves.removeAll()
            for i in 0..<numberOfCurves {
                let curve = WaveCurve(index: i, color: .green)
                greenCurves.append(curve)
            }
        case .blue:
            numberOfBlueCurves = numberOfCurves
            blueCurves.removeAll()
            for i in 0..<numberOfCurves {
                let curve = WaveCurve(index: i, color: .blue)
                blueCurves.append(curve)
            }
        case .supportLine:
            break // 支持线单独处理
        }
    }

    /**
     * 生成支持线曲线
     */
    private func spawnSupportCurve() {
        supportCurve = WaveCurve(index: 0, color: .supportLine)
    }

    // MARK: - 动画更新 / Animation Update
    /**
     * 更新所有曲线组（每帧调用）
     * 分别更新三个颜色组的所有曲线
     */
    public func update() {
        // 更新红色曲线组
        for curve in redCurves {
            curve.update(globalSpeed: globalSpeed, totalCurves: numberOfRedCurves)
        }

        // 更新绿色曲线组
        for curve in greenCurves {
            curve.update(globalSpeed: globalSpeed, totalCurves: numberOfGreenCurves)
        }

        // 更新蓝色曲线组
        for curve in blueCurves {
            curve.update(globalSpeed: globalSpeed, totalCurves: numberOfBlueCurves)
        }

        // 更新支持线
        supportCurve?.update(globalSpeed: globalSpeed, totalCurves: 1)

        // 定期检查是否需要重新生成曲线（避免每帧检查，优化性能）
        let currentTime = CACurrentMediaTime()
        if currentTime - lastRespawnCheck > 0.1 { // 每100毫秒检查一次
            checkForRespawning()
            lastRespawnCheck = currentTime
        }
    }

    /**
     * 检查各颜色组是否需要重新生成
     * 当某个颜色组的所有曲线都"死亡"时，重新生成该组
     */
    private func checkForRespawning() {
        // 检查红色曲线组
        let deadRedCurves = redCurves.filter { $0.shouldRespawn() }
        if deadRedCurves.count == redCurves.count {
            spawnColorGroup(.red)
        }

        // 检查绿色曲线组
        let deadGreenCurves = greenCurves.filter { $0.shouldRespawn() }
        if deadGreenCurves.count == greenCurves.count {
            spawnColorGroup(.green)
        }

        // 检查蓝色曲线组
        let deadBlueCurves = blueCurves.filter { $0.shouldRespawn() }
        if deadBlueCurves.count == blueCurves.count {
            spawnColorGroup(.blue)
        }
    }

    // MARK: - 公共接口 / Public API
    /**
     * 设置动画速度（支持插值过渡）
     */
    public func setSpeed(_ speed: Double) {
        globalSpeed = speed
    }

    /**
     * 设置动画振幅（支持插值过渡）
     */
    public func setAmplitude(_ amplitude: Double) {
        globalAmplitude = amplitude
    }

    /**
     * 获取红色曲线组
     */
    func getRedCurves() -> [WaveCurve] {
        return redCurves
    }

    /**
     * 获取绿色曲线组
     */
    func getGreenCurves() -> [WaveCurve] {
        return greenCurves
    }

    /**
     * 获取蓝色曲线组
     */
    func getBlueCurves() -> [WaveCurve] {
        return blueCurves
    }

    /**
     * 获取支持线曲线
     */
    func getSupportCurve() -> WaveCurve? {
        return supportCurve
    }

    /**
     * 获取所有活跃曲线的总数
     */
    func getTotalCurveCount() -> Int {
        return redCurves.count + greenCurves.count + blueCurves.count
    }
}
