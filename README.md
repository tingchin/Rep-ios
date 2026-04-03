# RepDetect iOS（Swift）

本目录为 RepDetect 的 **iOS 原生** 实现：

- **姿态估计**：使用 Apple **Vision**（`VNDetectHumanBodyPoseRequest`），将人体关键点映射为与 Android 端 ML Kit 管线一致的 **33×3** 维数据。
- **动作分类 / 计数**：与 Android **相同** 的 **C** 核心（`pose_processor`、KNN CSV、跳绳检测），通过 `pose_bridge.c` 与 Swift 桥接头文件暴露给 Swift（无 JNI）。

## 应用功能

| 模块 | 说明 |
|------|------|
| **首页** | 查看今日未完成计划、最近锻炼记录（次数等）。 |
| **锻炼** | 使用相机实时识别人体姿态；**仅根据当前未完成计划**加载对应检测逻辑（跳绳与/或 KNN）；画面叠加层只显示计划内运动；显示当前进度（已完成次数 / 目标次数）。 |
| **计划** | 新建、编辑、删除锻炼计划（运动类型、目标次数、锻炼日）；保存后可在首页与锻炼页使用。 |
| **我的** | 关于本应用与实现说明（简要）。 |

**自动完成计划**：在锻炼中点击「开始」后，当某条计划对应动作的**检测累计次数 ≥ 计划目标次数**时，自动将该计划标记为已完成（跳绳与其它动作规则一致）。若计划同时包含跳绳与其它动作，会并行运行跳绳检测与 KNN 检测。

**使用前**：需授予相机权限；建议至少添加一条未完成计划后再开始锻炼，否则无法加载检测器。

## 可监测的运动

应用内可选运动与 Android 端一致；以下为 **中文名**（括号内为数据层使用的英文名称）。  
**跳绳** 使用专用波动检测；**其余** 使用基于 CSV 样本的 KNN 分类与重复计数（需将对应 `pose/*.csv` 打入应用包）。

| 中文名 | 英文名 | 备注 |
|--------|--------|------|
| 俯卧撑 | Push up | KNN |
| 弓步蹲 | Lunge | KNN（常与站立姿态 CSV 组合） |
| 深蹲 | Squat | KNN |
| 仰卧起坐 | Sit up | KNN |
| 卧推 | Chest press | KNN |
| 硬拉 | Dead lift | KNN |
| 肩上推举 | Shoulder press | KNN |
| 跳绳 | Jump rope | 专用检测（髋部等关键点，不依赖 CSV） |
| 战士式瑜伽 | Warrior yoga | KNN |
| 树式瑜伽 | Tree yoga | KNN |

> 实际识别效果受光线、全身入镜、相机角度及 Vision 与训练数据差异影响；若与真值有偏差，可在「计划」中调整目标次数或检查环境。

## 环境要求

- 安装 **Xcode 15+** 的 macOS
- 部署目标 **iOS 17**（SwiftData）
- 可选：使用 **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** 根据 `project.yml` 生成 Xcode 工程

## 生成 Xcode 工程

在本目录（`ios/RepDetect`）下执行：

```bash
brew install xcodegen
xcodegen generate
open RepDetect.xcodeproj
```

然后选择 **RepDetect** 方案，指定 iPhone 模拟器或真机，编译（⌘B）。

### 不使用 XcodeGen 时

1. 在 Xcode 中新建 **iOS App**（SwiftUI、SwiftData）。
2. 删除不需要的模板文件。
3. 将 `RepDetect`、`RepDetectNative`、`Resources` 文件夹拖入工程（独立工程可勾选「Copy items if needed」，或使用引用）。
4. 添加 **桥接头文件**：`RepDetect/RepDetect-Bridging-Header.h`，并在 **Build Settings → Objective-C Bridging Header** 中指向该路径。
5. 将 **Header Search Paths** / **User Header Search Paths** 设为 `$(SRCROOT)/RepDetectNative`（是否递归可选）。
6. 将 `RepDetectNative` 下所有 `.c` 文件加入应用目标的 **Compile Sources**。
7. 将 `Resources/pose` 以 **文件夹引用（folder reference）** 加入，使打包后的 Bundle 内路径为 `pose/*.csv`。
8. 如需，在 **Other Linker Flags** 中加入 `-lm`。
9. **Info.plist** 使用 `RepDetect/Info.plist`（已含相机权限说明）。

## 资源包结构

运行时，CSV 训练数据需能通过以下路径访问：

`Bundle.main/.../pose/<文件名>.csv`

`Resources/pose` 应以 **文件夹引用** 方式加入工程，以便 `CsvAssetCombiner` 按与 Android 相同的文件名加载（如 `squats.csv`、`pushups.csv` 等）。

## 与 Android 同步 C 代码

`ios/RepDetect/RepDetectNative` 来自 Android 工程中的 `app/src/main/cpp`（不含 `pose_jni.c`），并额外包含 `pose_bridge.c` / `pose_bridge.h`。  
若你修改了 Android 侧的 C 源码，请重新复制更新后的 `.c` / `.h`；并保持 `jumprope_detector.c` 在双端可用（iOS 侧在非 `__ANDROID__` 时使用 `fprintf` 等输出）。

## 与 Android 的差异与限制

- 界面为精简版（Tab、计划、锻炼相机）；图表、GIF、语音播报、引导页等未完全对齐 Android。
- Vision 与 ML Kit 的关键点存在差异，识别效果可能与 Android 不完全一致。
- 上架 App Store 前请在 `Assets.xcassets` 中配置正式的 **应用图标**。
