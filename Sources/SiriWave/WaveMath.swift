import Foundation

/**
 * 波形数学计算工具类
 * 包含Siri波形动画所需的所有数学函数和常量
 */
struct WaveMath {

    // MARK: - 核心常量 / Core Constants
    /// 衰减因子：控制波形边缘的平滑程度，值越大边缘越平滑
    static let attenuationFactor: Double = 4.0
    /// 图形X轴范围：波形在X轴上的绘制范围 (-25 到 +25)
    static let graphX: Double = 25.0
    /// 振幅系数：控制波形的最大高度，iOS9+风格使用0.8
    static let amplitudeFactor: Double = 0.8
    /// 速度系数：控制波形动画的播放速度
    static let speedFactor: Double = 1.0
    /// 死区像素：当波形振幅小于此值时认为波形"死亡"，需要重新生成
    static let deadPixels: Double = 2.0
    /// 消散因子：控制波形淡入淡出的速度
    static let despawnFactor: Double = 0.02

    // MARK: - 默认参数范围 / Default Parameter Ranges
    /// 默认曲线数量范围：每个颜色组生成的曲线数量 (2-5个)
    static let defaultCurveRanges = (min: 2, max: 5)
    /// 默认振幅范围：单个曲线的振幅随机范围
    static let defaultAmplitudeRanges = (min: 0.3, max: 1.0)
    /// 默认偏移范围：曲线在X轴上的偏移范围，用于分散波形
    static let defaultOffsetRanges = (min: -3.0, max: 3.0)
    /// 默认宽度范围：控制波形的"压缩/拉伸"程度
    static let defaultWidthRanges = (min: 1.0, max: 3.0)
    /// 默认速度范围：单个曲线的动画速度随机范围
    static let defaultSpeedRanges = (min: 0.5, max: 1.0)
    /// 默认消散时间范围：曲线从出现到消失的时间 (500-2000毫秒)
    static let defaultDespawnTimeoutRanges = (min: 500.0, max: 2000.0)

    // MARK: - 全局衰减函数 / Global Attenuation Function
    /**
     * 全局衰减函数：在波形边界处平滑降低振幅
     *
     * 数学原理：使用高次幂函数创建平滑的衰减效果
     * 公式：pow(K / (K + pow(x, 2)), K)，其中K为衰减因子
     *
     * - 当x接近0时，函数值接近1（无衰减）
     * - 当x远离0时，函数值快速趋近0（强衰减）
     * - 这确保了波形在中心区域保持完整，边缘自然消失
     */
    static func globalAttenuation(x: Double) -> Double {
        return pow(attenuationFactor / (attenuationFactor + pow(x, 2)), attenuationFactor)
    }

    // MARK: - 随机数生成 / Random Range Generation
    /**
     * 在指定范围内生成随机双精度浮点数
     */
    static func randomInRange(min: Double, max: Double) -> Double {
        return min + Double.random(in: 0...1) * (max - min)
    }

    /**
     * 使用元组参数生成随机双精度浮点数
     */
    static func randomInRange(_ range: (min: Double, max: Double)) -> Double {
        return randomInRange(min: range.min, max: range.max)
    }

    /**
     * 在指定范围内生成随机整数
     */
    static func randomIntInRange(min: Int, max: Int) -> Int {
        return Int.random(in: min...max)
    }

    /**
     * 使用元组参数生成随机整数
     */
    static func randomIntInRange(_ range: (min: Int, max: Int)) -> Int {
        return randomIntInRange(min: range.min, max: range.max)
    }

    // MARK: - 波形位置计算 / Wave Position Calculations
    /**
     * 将数学坐标转换为屏幕X坐标
     *
     * - i: 数学坐标系中的X值 (范围通常为-25到+25)
     * - width: 屏幕宽度
     * - 返回: 对应的屏幕X坐标
     */
    static func xPosition(i: Double, width: Double) -> Double {
        return width * ((i + graphX) / (graphX * 2))
    }

    // MARK: - 插值计算 / Interpolation
    /**
     * 线性插值：在两个值之间平滑过渡
     *
     * - from: 起始值
     * - to: 目标值
     * - t: 插值系数 (0-1之间，0返回from，1返回to)
     * - 返回: 插值结果
     */
    static func lerp(from: Double, to: Double, t: Double) -> Double {
        return from * (1 - t) + to * t
    }

    // MARK: - 波形Y值计算 / Wave Calculation
    /**
     * 计算单个曲线在指定X坐标处的相对Y值
     *
     * 这是Siri波形动画的核心算法，实现了iOS9+风格的波形生成
     *
     * 算法步骤：
     * 1. 计算静态偏移t：确保每条曲线在空间上分散
     * 2. 添加动态偏移offset：增加随机性
     * 3. 应用宽度缩放k：控制波形的"密度"
     * 4. 计算正弦波值：使用verse参数控制方向
     * 5. 应用衰减函数：确保边缘平滑
     * 6. 取绝对值：iOS9+风格的特征，创造"尖峰"效果
     *
     * - i: X坐标
     * - amplitude: 当前振幅
     * - phase: 相位（控制波形位置）
     * - offset: 随机偏移
     * - width: 宽度参数
     * - verse: 方向参数（±1）
     * - curveIndex: 曲线索引
     * - totalCurves: 总曲线数
     */
    static func calculateCurveY(
        i: Double,
        amplitude: Double,
        phase: Double,
        offset: Double,
        width: Double,
        verse: Double,
        curveIndex: Int,
        totalCurves: Int
    ) -> Double {
        // 计算静态偏移t：将曲线分散到-4到+4的范围内
        // 公式：4 * (-1 + (index / (total-1)) * 2)
        // 这确保了多条曲线在空间上均匀分布
        var t = 4.0 * (-1.0 + (Double(curveIndex) / Double(totalCurves - 1)) * 2.0)

        // 添加动态偏移：增加随机性和自然感
        t += offset

        // 宽度缩放：控制波形的"频率"密度
        let k = 1.0 / width
        let x = i * k - t

        // 计算最终的Y值：正弦波 * 振幅 * 衰减
        // abs()是iOS9+风格的关键：创造尖锐的峰值效果
        return abs(amplitude * sin(verse * x - phase) * globalAttenuation(x: x))
    }

    /**
     * 标准化相位值：防止浮点数溢出
     *
     * 将相位值限制在0到2π之间，保持数值稳定性
     */
    static func normalizePhase(_ phase: Double) -> Double {
        return phase.truncatingRemainder(dividingBy: 2 * Double.pi)
    }
}