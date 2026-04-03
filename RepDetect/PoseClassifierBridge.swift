import Foundation

struct PostureResultSwift {
    let className: String
    let confidence: Float
    let repetitions: Int
}

/// Swift wrapper around `pose_bridge` (same role as Android `PoseClassifierNative`).
final class PoseClassifierBridge {
    private var handle: PoseBridgeHandle?
    private(set) var isJumpRopeMode: Bool

    private init(handle: PoseBridgeHandle?, isJumpRopeMode: Bool) {
        self.handle = handle
        self.isJumpRopeMode = isJumpRopeMode
    }

    static func makeJumpRope() -> PoseClassifierBridge? {
        guard let h = pose_bridge_init_jumprope() else { return nil }
        return PoseClassifierBridge(handle: h, isJumpRopeMode: true)
    }

    static func makeKNN(csvPath: String, isStreamMode: Bool) -> PoseClassifierBridge? {
        guard let h = csvPath.withCString({ pose_bridge_init_knn_default($0, isStreamMode ? 1 : 0) }) else {
            return nil
        }
        return PoseClassifierBridge(handle: h, isJumpRopeMode: false)
    }

    deinit {
        if let handle {
            pose_bridge_destroy(handle)
        }
    }

    func processFrame(landmarksXYZ99: [Float], nowMs: Int64, hasPose: Bool) -> [String: PostureResultSwift] {
        guard let handle, landmarksXYZ99.count >= 99 else { return [:] }
        landmarksXYZ99.withUnsafeBufferPointer { buf in
            pose_bridge_process_frame(handle, buf.baseAddress, nowMs, hasPose ? 1 : 0)
        }
        var raw = (0..<20).map { _ in pose_bridge_result_zero() }
        let n = raw.withUnsafeMutableBufferPointer { buf in
            pose_bridge_get_results(handle, buf.baseAddress, Int32(buf.count))
        }
        var out: [String: PostureResultSwift] = [:]
        for i in 0..<Int(n) {
            let r = raw[i]
            let name = raw.withUnsafeBufferPointer { buf in
                String(cString: pose_bridge_result_class_name(buf.baseAddress! + i))
            }
            if r.confidence > 0 || r.repetitions > 0 {
                out[name] = PostureResultSwift(
                    className: name,
                    confidence: r.confidence,
                    repetitions: Int(r.repetitions)
                )
            }
        }
        return out
    }
}
