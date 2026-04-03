# RepDetect iOS（Swift）

本目录为 RepDetect 的 **iOS 原生** 实现：

- **姿态估计**：使用 Apple **Vision**（`VNDetectHumanBodyPoseRequest`），将人体关键点映射为与 Android 端 ML Kit 管线一致的 **33×3** 维数据。
- **动作分类 / 计数**：与 Android **相同** 的 **C** 核心（`pose_processor`、KNN CSV、跳绳检测），通过 `pose_bridge.c` 与 Swift 桥接头文件暴露给 Swift（无 JNI）。

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
