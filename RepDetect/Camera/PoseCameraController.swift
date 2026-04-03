import AVFoundation
import Combine
import SwiftUI
import Vision

/// 按当前计划并行运行 KNN / 跳绳检测；叠加层只显示「计划内」运动。
final class PoseSessionController: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var overlayText: String = ""
    @Published var errorMessage: String?
    /// 合并后的分类结果（用于达标判断），键为 C 端 class 名。
    @Published var postureResults: [String: PostureResultSwift] = [:]
    /// 跳绳累计次数（便于单独展示）。
    @Published var jumpropeRepetitions: Int = 0

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private let queue = DispatchQueue(label: "repdetect.pose.session")
    private var knnBridge: PoseClassifierBridge?
    private var jumpBridge: PoseClassifierBridge?
    /// 仅展示这些 key（来自当前未完成计划的映射）
    private var allowedClassifierKeys: Set<String> = []

    func configure(
        knn: PoseClassifierBridge?,
        jump: PoseClassifierBridge?,
        allowedKeys: Set<String>
    ) {
        knnBridge = knn
        jumpBridge = jump
        allowedClassifierKeys = allowedKeys
        DispatchQueue.main.async {
            self.jumpropeRepetitions = 0
            self.postureResults = [:]
        }
    }

    func flipCamera() {
        devicePosition = devicePosition == .back ? .front : .back
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
        }
    }

    private var devicePosition: AVCaptureDevice.Position = .back

    private func rebuildSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
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

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async {
            self.previewLayer = layer
        }

        if !session.isRunning {
            session.startRunning()
        }
    }

    private func handle(sampleBuffer: CMSampleBuffer) {
        guard knnBridge != nil || jumpBridge != nil else {
            DispatchQueue.main.async { self.overlayText = "请先在「计划」中添加锻炼项目" }
            return
        }

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

        var merged: [String: PostureResultSwift] = [:]

        if let obs = request.results?.first as? VNHumanBodyPoseObservation {
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
        let text = lines.isEmpty ? "识别中…" : lines.joined(separator: "\n")
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
