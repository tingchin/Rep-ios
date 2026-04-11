# RepDetect iOS（Swift）

本目录为 RepDetect 的 **iOS 原生** 实现，与 Android 端共用同一套 **C 核心**（姿态处理、KNN、跳绳检测），通过 `pose_bridge` 与 Swift 桥接。

## 技术栈

- **姿态估计**：Apple **Vision**（`VNDetectHumanBodyPoseRequest`），人体关键点映射为与 Android ML Kit 管线一致的 **33×3** 数据。
- **动作分类 / 计数**：`RepDetectNative` 中的 `pose_processor`、KNN（CSV 样本）、**跳绳**专用检测（`jumprope_detector.c`），经 `pose_bridge.c` 暴露给 Swift。
- **数据**：**SwiftData** 持久化计划与锻炼结果（iOS **17+**）。

## 应用功能

| 模块 | 说明 |
|------|------|
| **首页** | 展示**今日**且处于**锻炼日**、**未完成**的计划；进入详情后可开始锻炼。跨天后，在符合锻炼日规则的前提下，已完成计划会重新出现在今日列表（便于每日重复目标）。 |
| **计划** | 默认展示**全部计划**列表；右上角 **「+」** 进入**创建计划**（运动类型、可选**计划名称**、目标次数、锻炼日多选）。支持编辑、删除、标记完成。 |
| **计划详情** | 查看/修改计划名称、目标次数、锻炼日、完成状态；未完成时可 **「开始锻炼」** 进入全屏相机页。 |
| **锻炼（相机）** | 针对**当前这一条计划**加载跳绳与/或 KNN；实时预览、骨骼叠加、进度与叠字提示；达标后自动将计划标为完成。离开底部 Tab 时会重置对应导航栈，避免深层页面残留。 |
| **我的** | 应用说明；**历史运动**按日期分组展示（在相机页点击「停止」后写入：运动、次数、时间、估算热量与时长）。 |

**计划名称**：可自定义；留空时列表与导航标题使用运动中文名。

**自动完成计划**：检测累计次数达到计划目标次数时，自动标记该计划为已完成。

**历史记录**：每次点击「停止」写入一条 `WorkoutResultEntity`，在「我的」中查看。

**权限**：首次使用相机前需在系统设置中允许相机访问（`Info.plist` 已配置用途说明）。

## 可监测的运动

跳绳使用专用波动检测；其余动作使用 KNN + CSV 样本（打包于 `Resources/pose`）。

| 中文名 | 英文名 | 方式 |
|--------|--------|------|
| 俯卧撑 | Push up | KNN |
| 弓步蹲 | Lunge | KNN |
| 深蹲 | Squat | KNN |
| 仰卧起坐 | Sit up | KNN |
| 卧推 | Chest press | KNN |
| 硬拉 | Dead lift | KNN |
| 肩上推举 | Shoulder press | KNN |
| 跳绳 | Jump rope | 专用检测（髋与肩关键点序列；`jumprope_detector.c`） |
| 战士式瑜伽 | Warrior yoga | KNN |
| 树式瑜伽 | Tree yoga | KNN |

## 环境要求

- **macOS** + **Xcode 15+**
- 部署目标 **iOS 17.0**（SwiftData）
- 可选：**[XcodeGen](https://github.com/yonaskolb/XcodeGen)**，用本目录 `project.yml` 生成 Xcode 工程

## 部署：使用 XcodeGen（推荐）

在 **`ios/RepDetect`** 目录下执行：

```bash
brew install xcodegen
xcodegen generate
open RepDetect.xcodeproj
```

在 Xcode 中选择 **RepDetect** scheme，指定 **真机或模拟器**，**⌘B** 编译、**⌘R** 运行。

拉取代码后若新增/重命名了源文件，在本目录重新执行 `xcodegen generate` 再打开工程。

## 部署：手动创建 Xcode 工程

1. 在 Xcode 中新建 **iOS App**（SwiftUI、SwiftData），部署版本 **iOS 17**。
2. 将 **`RepDetect`**、**`RepDetectNative`**、**`Resources`** 拖入工程（按需勾选 Copy 或使用引用）。
3. **Bridging Header**：`RepDetect/RepDetect-Bridging-Header.h`，在 **Build Settings → Objective-C Bridging Header** 中填写路径。
4. **Header Search Paths** / **User Header Search Paths**：`$(SRCROOT)/RepDetectNative`。
5. 将 `RepDetectNative` 下所有 **`.c`** 加入应用目标的 **Compile Sources**。
6. **`Resources/pose`** 以 **Folder** 方式加入 **Copy Bundle Resources**，使运行时路径为 `pose/*.csv`。
7. **Other Linker Flags**：`-lm`。
8. **Info.plist**：使用仓库中的 `RepDetect/Info.plist`（含相机用途说明）。

## 资源与运行时路径

KNN 合并逻辑期望 Bundle 内存在：

`pose/<英文名>.csv`（如 `squats.csv`、`pushups.csv`）

与 Android 端文件名保持一致。

## 与 Android 同步 C 代码

`RepDetectNative` 应与 Android 工程中 `app/src/main/cpp` 对齐（不含 Android 专用 JNI），并保留 iOS 侧 **`pose_bridge.c` / `pose_bridge.h`**。修改 `jumprope_detector`、`pose_processor` 等后请在双端重新编译并验证。

## 与 Android 的差异

- 界面为精简版（Tab：首页 / 计划 / 我的）；未完全对齐 Android 的图表、GIF、语音等。
- Vision 与 ML Kit 关键点存在差异，识别表现可能略有不同。
- 上架前请在 `Assets.xcassets` 中配置正式 **App Icon**。

## 调试日志（可选）

Xcode 控制台中 **`[RepDetect] Camera:`** 日志可用于观察相机会话启动与首帧耗时；**`[JumpRope]`** 日志可用于观察跳绳检测器内部状态（需在 Debug 下查看 stderr）。
