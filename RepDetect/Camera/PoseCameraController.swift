import AVFoundation
import SwiftUI
import Vision

/// 按当前计划并行运行 KNN / 跳绳检测；叠加层只显示「计划内」运动。
final class PoseSessionController: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var overlayText: String = ""
    @Published var errorMessage: String?
    @Published var postureResults: [String: PostureResultSwift] = [:]
    @Published var jumpropeRepetitions: Int = 0
    /// 用于骨骼叠加层（与 `lastPoseImageSize` 对应像素缓冲尺寸）。
    @Published var lastBodyPoseObservation: VNHumanBodyPoseObservation?
    @Published var lastPoseImageSize: CGSize = .zero
    @Published var isUsingFrontCamera = false
    /// `true` 表示 KNN/跳绳模型已就绪，可用于计数与自动完成计划。
    @Published private(set) var recognitionReady = false

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private let queue = DispatchQueue(label: "repdetect.pose.session")
    private var knnBridge: PoseClassifierBridge?
    private var jumpBridge: PoseClassifierBridge?
    private var allowedClassifierKeys: Set<String> = []
    private var devicePosition: AVCaptureDevice.Position = .back
    /// 已 `start()` 但 CSV/KNN 仍在后台加载，此期间只跑 Vision 画骨骼。
    private var bridgesLoading = false

    /// 用于在 Xcode 控制台观察相机冷启动耗时（从 `rebuildSession` 开始到首帧）。
    private var sessionStartMonotonic: CFAbsoluteTime = 0
    private var firstVideoFrameLogged = false

    /// 避免每帧多次 `DispatchQueue.main.async` 把主队列塞满，导致预览层迟迟不能显示（见 log 中 previewLayer 数秒后才赋值）。
    private var uiCoalesceScheduled = false
    private var pendingBodyObs: VNHumanBodyPoseObservation?
    private var pendingImageW: CGFloat = 0
    private var pendingImageH: CGFloat = 0
    private var pendingMerged: [String: PostureResultSwift] = [:]
    private var pendingOverlayText: String = ""

    /// 限制骨骼/叠字刷新频率。每帧都 `@Published` 会让 SwiftUI 狂刷，`CameraPreviewRepresentable` 若每次 `updateUIView` 都拆插预览层会长时间黑屏。
    private var lastUIEmitMonotonic: CFAbsoluteTime = 0
    /// 约 20fps 上限；骨骼略降帧通常仍可接受，主线程与预览层会轻松很多。
    private let minUIEmitInterval: CFTimeInterval = 1.0 / 20.0

    func configure(
        knn: PoseClassifierBridge?,
        jump: PoseClassifierBridge?,
        allowedKeys: Set<String>,
        bridgesLoading: Bool = false
    ) {
        knnBridge = knn
        jumpBridge = jump
        allowedClassifierKeys = allowedKeys
        self.bridgesLoading = bridgesLoading
        DispatchQueue.main.async {
            self.jumpropeRepetitions = 0
            self.postureResults = [:]
            self.lastBodyPoseObservation = nil
            let hasDetector = knn != nil || jump != nil
            self.recognitionReady = !bridgesLoading && hasDetector
        }
    }

    func flipCamera() {
        devicePosition = devicePosition == .back ? .front : .back
        DispatchQueue.main.async {
            self.isUsingFrontCamera = self.devicePosition == .front
        }
        queue.async { [weak self] in
            self?.rebuildSession()
        }
    }

    func start() {
        queue.async { [weak self] in
            self?.rebuildSession()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
            DispatchQueue.main.async {
                self?.lastBodyPoseObservation = nil
            }
        }
    }

    private func rebuildSession() {
        firstVideoFrameLogged = false
        sessionStartMonotonic = CFAbsoluteTimeGetCurrent()
        lastUIEmitMonotonic = 0

        /// 改配置前必须先停会话，否则 Fig 报错且 delegate 仍可能狂刷帧，主线程异步块堆积导致预览黑屏很久。
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        /// 使用 720p 通常比 `.high` 冷启动更快，仍足够做姿态识别。
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = .high
        }
        for input in session.inputs {
            session.removeInput(input)
        }
        for output in session.outputs {
            session.removeOutput(output)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: devicePosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            DispatchQueue.main.async { self.errorMessage = "无法使用相机，请检查权限或设备。" }
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let conn = videoOutput.connection(with: .video) {
            if conn.isVideoRotationAngleSupported(90) {
                conn.videoRotationAngle = 90
            }
        }

        session.commitConfiguration()

        let tBeforeStart = CFAbsoluteTimeGetCurrent()
        if !session.isRunning {
            session.startRunning()
        }
        let startRunningMs = (CFAbsoluteTimeGetCurrent() - tBeforeStart) * 1000
        let sinceRebuildMs = (CFAbsoluteTimeGetCurrent() - sessionStartMonotonic) * 1000
        print("[RepDetect] Camera: startRunning() \(String(format: "%.1f", startRunningMs)) ms; commit→running \(String(format: "%.1f", sinceRebuildMs)) ms")

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async {
            self.previewLayer = layer
            self.isUsingFrontCamera = self.devicePosition == .front
            let previewMs = (CFAbsoluteTimeGetCurrent() - self.sessionStartMonotonic) * 1000
            print("[RepDetect] Camera: previewLayer set \(String(format: "%.1f", previewMs)) ms after rebuild start")
        }
    }

    /// 在采集队列上计算叠字，合并为单次主线程刷新，避免主队列积压。
    private func overlayTextForMerged(_ merged: [String: PostureResultSwift]) -> String {
        let display = merged.filter { allowedClassifierKeys.contains($0.key) }
        let lines = display.sorted(by: { $0.key < $1.key }).map { k, v in
            let label = ExerciseDisplay.zh(classifierKey: k)
            return "\(label)：次数 \(v.repetitions)　置信度 \(String(format: "%.2f", v.confidence))"
        }
        if bridgesLoading, knnBridge == nil, jumpBridge == nil {
            return "正在加载动作识别模型…"
        }
        if lines.isEmpty {
            return "识别中…"
        }
        return lines.joined(separator: "\n")
    }

    private func scheduleUIPublish(
        merged: [String: PostureResultSwift],
        bodyObs: VNHumanBodyPoseObservation?,
        w: CGFloat,
        h: CGFloat
    ) {
        let text = overlayTextForMerged(merged)
        pendingBodyObs = bodyObs
        pendingImageW = w
        pendingImageH = h
        pendingMerged = merged
        pendingOverlayText = text
        if uiCoalesceScheduled { return }
        uiCoalesceScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.uiCoalesceScheduled = false
            self.lastBodyPoseObservation = self.pendingBodyObs
            self.lastPoseImageSize = CGSize(width: self.pendingImageW, height: self.pendingImageH)
            self.overlayText = self.pendingOverlayText
            self.postureResults = self.pendingMerged
            self.jumpropeRepetitions = self.pendingMerged["jumprope"]?.repetitions ?? 0
        }
    }

    private func handle(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest()
        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
            return
        }

        let w = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let h = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let t = Int64(Date().timeIntervalSince1970 * 1000)

        let bodyObs = request.results?.first as? VNHumanBodyPoseObservation

        var merged: [String: PostureResultSwift] = [:]

        let canClassify = knnBridge != nil || jumpBridge != nil
        if canClassify {
            if let obs = bodyObs {
                let landmarks = VisionBodyPoseMapper.landmarksXYZ99(from: obs, imageWidth: w, imageHeight: h)
                if let k = knnBridge {
                    let m = k.processFrame(landmarksXYZ99: landmarks, nowMs: t, hasPose: true)
                    merge(&merged, m)
                }
                if let j = jumpBridge {
                    let m = j.processFrame(landmarksXYZ99: landmarks, nowMs: t, hasPose: true)
                    merge(&merged, m)
                }
            } else {
                let flat = [Float](repeating: 0, count: 99)
                if let k = knnBridge {
                    let m = k.processFrame(landmarksXYZ99: flat, nowMs: t, hasPose: false)
                    merge(&merged, m)
                }
                if let j = jumpBridge {
                    let m = j.processFrame(landmarksXYZ99: flat, nowMs: t, hasPose: false)
                    merge(&merged, m)
                }
            }
        }

        let wall = CFAbsoluteTimeGetCurrent()
        let shouldEmitUI =
            lastUIEmitMonotonic == 0 || (wall - lastUIEmitMonotonic) >= minUIEmitInterval
        if shouldEmitUI {
            lastUIEmitMonotonic = wall
            scheduleUIPublish(merged: merged, bodyObs: bodyObs, w: w, h: h)
        }
    }

    private func merge(_ acc: inout [String: PostureResultSwift], _ part: [String: PostureResultSwift]) {
        for (k, v) in part {
            acc[k] = v
        }
    }
}

extension PoseSessionController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if !firstVideoFrameLogged {
            firstVideoFrameLogged = true
            let ms = (CFAbsoluteTimeGetCurrent() - sessionStartMonotonic) * 1000
            print("[RepDetect] Camera: first video frame \(String(format: "%.1f", ms)) ms after rebuild start")
        }
        handle(sampleBuffer: sampleBuffer)
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    var layer: AVCaptureVideoPreviewLayer?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var attached: AVCaptureVideoPreviewLayer?
    }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let layer else {
            context.coordinator.attached?.removeFromSuperlayer()
            context.coordinator.attached = nil
            return
        }
        /// 仅当会话重建、预览层实例变化时重新挂载。切勿在 SwiftUI 每次刷新时都 remove/insert，否则预览会长时间黑屏或闪烁。
        if context.coordinator.attached !== layer {
            context.coordinator.attached?.removeFromSuperlayer()
            context.coordinator.attached = layer
            uiView.layer.insertSublayer(layer, at: 0)
        }
        layer.frame = uiView.bounds
    }
}
