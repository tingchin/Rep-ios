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

        DispatchQueue.main.async {
            self.lastBodyPoseObservation = bodyObs
            self.lastPoseImageSize = CGSize(width: w, height: h)
        }

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

        publish(merged: merged)
    }

    private func merge(_ acc: inout [String: PostureResultSwift], _ part: [String: PostureResultSwift]) {
        for (k, v) in part {
            acc[k] = v
        }
    }

    private func publish(merged: [String: PostureResultSwift]) {
        let display = merged.filter { allowedClassifierKeys.contains($0.key) }
        let lines = display.sorted(by: { $0.key < $1.key }).map { k, v in
            let label = ExerciseDisplay.zh(classifierKey: k)
            return "\(label)：次数 \(v.repetitions)　置信度 \(String(format: "%.2f", v.confidence))"
        }
        let text: String
        if bridgesLoading, knnBridge == nil, jumpBridge == nil {
            text = "正在加载动作识别模型…"
        } else if lines.isEmpty {
            text = "识别中…"
        } else {
            text = lines.joined(separator: "\n")
        }
        DispatchQueue.main.async {
            self.overlayText = text
            self.postureResults = merged
            self.jumpropeRepetitions = merged["jumprope"]?.repetitions ?? 0
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

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.sublayers?.filter { $0 is AVCaptureVideoPreviewLayer }.forEach { $0.removeFromSuperlayer() }
        guard let layer else { return }
        layer.frame = uiView.bounds
        uiView.layer.insertSublayer(layer, at: 0)
    }
}
