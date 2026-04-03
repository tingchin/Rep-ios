import CoreGraphics
import Vision

/// Maps Apple Vision body pose to ML Kit–style 33×3 floats (pixel x,y; z=0), top-left origin.
/// Face indices 0–10 use `neck` as a proxy so normalization behaves similarly to ML Kit training data.
enum VisionBodyPoseMapper {
    static func landmarksXYZ99(
        from observation: VNHumanBodyPoseObservation,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> [Float] {
        var arr = [Float](repeating: 0, count: 99)

        func write(_ mlIndex: Int, _ joint: VNHumanBodyPoseObservation.JointName) {
            guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.05 else { return }
            let x = Float(p.location.x * imageWidth)
            let y = Float(imageHeight) * (1 - Float(p.location.y))
            let base = mlIndex * 3
            arr[base] = x
            arr[base + 1] = y
            arr[base + 2] = 0
        }

        if let p = try? observation.recognizedPoint(.neck), p.confidence > 0.05 {
            let x = Float(p.location.x * imageWidth)
            let y = Float(imageHeight) * (1 - Float(p.location.y))
            for i in 0..<11 {
                let base = i * 3
                arr[base] = x
                arr[base + 1] = y
                arr[base + 2] = 0
            }
        }

        write(11, .leftShoulder)
        write(12, .rightShoulder)
        write(13, .leftElbow)
        write(14, .rightElbow)
        write(15, .leftWrist)
        write(16, .rightWrist)

        write(23, .leftHip)
        write(24, .rightHip)
        write(25, .leftKnee)
        write(26, .rightKnee)
        write(27, .leftAnkle)
        write(28, .rightAnkle)

        func copyIfEmpty(_ dst: Int, _ src: Int) {
            let db = dst * 3
            let sb = src * 3
            if arr[db] == 0, arr[db + 1] == 0 {
                arr[db] = arr[sb]
                arr[db + 1] = arr[sb + 1]
                arr[db + 2] = arr[sb + 2]
            }
        }
        copyIfEmpty(29, 27)
        copyIfEmpty(30, 28)
        copyIfEmpty(31, 27)
        copyIfEmpty(32, 28)

        return arr
    }
}
