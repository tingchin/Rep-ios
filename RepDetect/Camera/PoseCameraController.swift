import AVFoundation
import Combine
import SwiftUI
import Vision

/// Runs Vision body pose + native KNN / jump-rope on camera frames.
final class PoseSessionController: NSObject, ObservableObject {
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var overlayText: String = ""
    @Published var errorMessage: String?

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private let queue = DispatchQueue(label: "repdetect.pose.session")
    private var bridge: PoseClassifierBridge?
    private var devicePosition: AVCaptureDevice.Position = .back

    func configure(bridge: PoseClassifierBridge?) {
        self.bridge = bridge
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
            DispatchQueue.main.async { self.errorMessage = "Camera unavailable" }
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
        guard let bridge else {
            DispatchQueue.main.async { self.overlayText = "Tap Start (after plans exist)" }
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

        if let obs = request.results?.first as? VNHumanBodyPoseObservation {
            let landmarks = VisionBodyPoseMapper.landmarksXYZ99(from: obs, imageWidth: w, imageHeight: h)
            let map = bridge.processFrame(landmarksXYZ99: landmarks, nowMs: t, hasPose: true)
            publish(map)
        } else {
            let flat = [Float](repeating: 0, count: 99)
            let map = bridge.processFrame(landmarksXYZ99: flat, nowMs: t, hasPose: false)
            publish(map)
        }
    }

    private func publish(_ map: [String: PostureResultSwift]) {
        let lines = map.sorted(by: { $0.key < $1.key }).map { k, v in
            "\(k): reps=\(v.repetitions) conf=\(String(format: "%.2f", v.confidence))"
        }
        let text = lines.isEmpty ? "Detecting…" : lines.joined(separator: "\n")
        DispatchQueue.main.async {
            self.overlayText = text
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
