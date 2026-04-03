# RepDetect iOS (Swift)

This folder contains a native iOS port of RepDetect:

- **Pose estimation**: Apple **Vision** (`VNDetectHumanBodyPoseRequest`), mapped to the same 33×3 landmark layout used by the Android ML Kit pipeline.
- **Classification / rep counting**: the same **C** core as Android (`pose_processor`, KNN CSV, jump-rope detector), exposed through `pose_bridge.c` and a Swift bridging header (no JNI).

## Requirements

- macOS with **Xcode 15+**
- **iOS 17** deployment target (SwiftData)
- Optional: **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** to generate the Xcode project from `project.yml`

## Generate the Xcode project

From this directory (`ios/RepDetect`):

```bash
brew install xcodegen
xcodegen generate
open RepDetect.xcodeproj
```

Then select the **RepDetect** scheme, choose an iPhone simulator or device, and build (⌘B).

### Without XcodeGen

1. Create a new **iOS App** in Xcode (SwiftUI, SwiftData).
2. Delete the default template files you do not need.
3. Drag the `RepDetect`, `RepDetectNative`, and `Resources` folders into the project (enable “Copy items if needed” for a self-contained project, or use references).
4. Add **Bridging Header**: `RepDetect/RepDetect-Bridging-Header.h`, and set **Build Settings → Objective-C Bridging Header** to that path.
5. Set **Header Search Paths** / **User Header Search Paths** to `$(SRCROOT)/RepDetectNative` (recursive optional).
6. Add all `.c` files under `RepDetectNative` to the app target (Compile Sources).
7. Add `Resources/pose` as a **folder reference** so CSV files appear in the bundle under `pose/*.csv`.
8. Set **Other Linker Flags** to `-lm` if needed.
9. Set **Info.plist** to `RepDetect/Info.plist` (camera usage string is already there).

## Bundle layout

CSV training files must be available at runtime as:

`Bundle.main/.../pose/<name>.csv`

The `Resources/pose` folder is copied as a **folder reference** so `CsvAssetCombiner` can load the same filenames as Android (`squats.csv`, `pushups.csv`, etc.).

## Keeping C code in sync

`ios/RepDetect/RepDetectNative` is a copy of `app/src/main/cpp` (without `pose_jni.c`), plus `pose_bridge.c` / `pose_bridge.h`.  
When you change the Android C sources, copy the updated `.c` / `.h` files again and keep `jumprope_detector.c` logging compatible with both platforms (the iOS copy uses `fprintf` when not `__ANDROID__`).

## Limitations vs Android

- UI parity is simplified (tabs, plans, workout camera). Charts, GIFs, TTS, and onboarding are not fully replicated.
- Vision landmarks differ slightly from ML Kit; accuracy may differ from the Android build.
- Add a real **App Icon** in `Assets.xcassets` before App Store submission.
