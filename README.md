# SiriWave iOS 动画库

一个高性能的 iOS 原生 Siri 风格波形动画库，完美复刻了 SiriWave.js 的 iOS9+ 多彩波形效果。

## 效果预览

本库实现了与 iOS Siri 语音助手相同的视觉效果：
- **多彩波形**：红、绿、蓝三色独立波形
- **颜色混合**：通过叠加产生青、品红、黄等中间色
- **流畅动画**：60fps 的丝滑体验
- **原生性能**：使用 Core Graphics 优化渲染

## 快速开始

### 最简单的使用方式

```swift
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let waveView = SiriWaveView.create(in: view, autoStart: true)
    }
}
```

> 性能优化：如果希望将渲染计算转移到 GPU，可使用 `SiriWaveMetalView`。该版本基于 Metal 渲染，能显著降低主线程 CPU 占用。

```swift
import UIKit

class MetalViewController: UIViewController {
    private var waveView: SiriWaveMetalView!

    override func viewDidLoad() {
        super.viewDidLoad()

        waveView = SiriWaveMetalView.create(in: view, autoStart: true)
    }
}
```

### 基础配置示例

```swift
let waveView = SiriWaveView(frame: CGRect(x: 0, y: 0, width: 300, height: 200))
view.addSubview(waveView)

waveView.start()

waveView.setAmplitude(1.0)
waveView.setSpeed(0.2)
```

## 可配置参数详解

### 主要控制参数

| 参数 | 类型 | 范围 | 默认值 | 说明 |
|------|------|------|--------|------|
| `amplitude` | Double | 0.0 - 3.0 | 1.0 | 波形振幅，控制波形高度 |
| `speed` | Double | 0.0 - 2.0 | 0.2 | 动画速度，控制波形移动快慢 |

### 参数效果说明

#### 振幅 (Amplitude)
- `0.0`: 无波形，完全静止
- `0.5`: 轻柔的小波浪
- `1.0`: 标准波形高度
- `1.5`: 活跃的波形
- `2.0+`: 剧烈的波形（适合强烈音频）

#### 速度 (Speed)
- `0.0`: 波形静止
- `0.1`: 缓慢流动
- `0.2`: 默认速度
- `0.5`: 中等速度
- `1.0+`: 快速流动

## 使用示例

```swift
class GradientWaveViewController: UIViewController {
    private var waveView: SiriWaveView!

    override func viewDidLoad() {
        super.viewDidLoad()

        waveView = SiriWaveView.create(in: view)
        breathingAnimation()
    }

    func breathingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            let time = Date().timeIntervalSince1970
            let amplitude = 0.5 + 0.5 * sin(time * 2)
            let speed = 0.1 + 0.1 * sin(time * 1.5)

            self.waveView.setAmplitude(amplitude)
            self.waveView.setSpeed(speed)
        }
    }
}
```

## 公共 API 参考

### 属性

```swift
// 只读属性
var isRunning: Bool { get }      // 动画是否正在运行
var amplitude: Double { get }     // 当前振幅值
var speed: Double { get }         // 当前速度值
```

### 方法

```swift
// 动画控制
func start()                      // 开始动画
func stop()                       // 停止动画

// 参数设置（支持平滑过渡）
func setAmplitude(_ amplitude: Double)  // 设置振幅
func setSpeed(_ speed: Double)          // 设置速度

// 便捷创建方法
static func create(in container: UIView, autoStart: Bool = true) -> SiriWaveView
```

## 最佳实践

### 性能优化建议

1. **合理的视图大小**
   - 推荐高度：150-250 像素
   - 宽度：使用父视图宽度
   - 避免过大的视图以保持性能

2. **参数调整频率**
   - 音频联动：20-50ms 更新一次
   - 手势响应：实时更新
   - 动画过渡：使用内置插值系统

3. **生命周期管理**
   ```swift
   override func viewWillDisappear(_ animated: Bool) {
       super.viewWillDisappear(animated)
       waveView.stop()
   }

   override func viewWillAppear(_ animated: Bool) {
       super.viewWillAppear(animated)
       waveView.start()
   }
   ```

## 技术架构

- **WaveMath.swift** - 波形函数计算、全局衰减算法、坐标转换工具
- **WaveCurve.swift** - 单曲线生命周期、三色曲线组管理、参数随机生成
- **SiriWaveView.swift** - Core Graphics 绘制、CADisplayLink 动画、参数插值系统
- **SiriWaveMetalView.swift** - 基于 Metal 的 GPU 渲染实现，提供更低 CPU 占用

## 系统要求

- iOS 13.0+
- Xcode 12.0+
- Swift 5.0+

## 安装方法

### 手动安装

将以下文件拷贝到你的项目中：
- `WaveMath.swift`
- `WaveCurve.swift`
- `SiriWaveView.swift`

然后在需要使用的地方直接使用 `SiriWaveView`。

## 致谢

- 感谢 [SiriWave.js](https://github.com/kopiro/siriwave) 提供的数学模型参考
- 感谢 [FreeCodeCamp 文章](https://www.freecodecamp.org/news/how-i-built-siriwavejs-library-maths-and-code-behind-6971497ae5c1/) 的算法详解

## 许可证

MIT License - 详见 LICENSE 文件
