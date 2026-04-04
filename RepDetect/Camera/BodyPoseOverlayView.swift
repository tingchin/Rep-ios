import SwiftUI
import Vision

/// 在相机预览区域上绘制人体骨骼（与 Vision 检测结果对齐）。
struct BodyPoseOverlayView: View {
    var observation: VNHumanBodyPoseObservation?
    var imageSize: CGSize
    var isFrontCamera: Bool

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard let obs = observation, imageSize.width > 0, imageSize.height > 0 else { return }
                let lineWidth: CGFloat = 3
                let jointColor = Color.green.opacity(0.95)
                let lineColor = Color.cyan.opacity(0.9)

                for (a, b) in Self.connections {
                    guard let pa = try? obs.recognizedPoint(a), pa.confidence > 0.1,
                          let pb = try? obs.recognizedPoint(b), pb.confidence > 0.1,
                          let ca = mapToView(pa, viewSize: size),
                          let cb = mapToView(pb, viewSize: size)
                    else { continue }
                    var path = Path()
                    path.move(to: ca)
                    path.addLine(to: cb)
                    context.stroke(path, with: .color(lineColor), lineWidth: lineWidth)
                }

                for joint in Self.keyJoints {
                    guard let p = try? obs.recognizedPoint(joint), p.confidence > 0.1,
                          let c = mapToView(p, viewSize: size)
                    else { continue }
                    let r: CGFloat = 4
                    context.fill(
                        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                        with: .color(jointColor)
                    )
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// Vision 归一化坐标（左下原点）→ 视图坐标（左上原点），并按「放大裁切」对齐预览。
    private func mapToView(_ point: VNRecognizedPoint, viewSize: CGSize) -> CGPoint? {
        let w = imageSize.width
        let h = imageSize.height
        let ix = CGFloat(point.location.x) * w
        let iy = (1 - CGFloat(point.location.y)) * h
        var pt = mapImagePointToView(CGPoint(x: ix, y: iy), imageSize: imageSize, viewSize: viewSize)
        if isFrontCamera {
            pt.x = viewSize.width - pt.x
        }
        return pt
    }

    private func mapImagePointToView(_ imagePoint: CGPoint, imageSize: CGSize, viewSize: CGSize) -> CGPoint {
        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        let offsetX = (viewSize.width - scaledW) / 2
        let offsetY = (viewSize.height - scaledH) / 2
        return CGPoint(
            x: imagePoint.x * scale + offsetX,
            y: imagePoint.y * scale + offsetY
        )
    }

    private static let keyJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose, .neck, .root,
        .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist,
        .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle
    ]

    /// 骨架连线（与常见健身 App 类似）。
    private static let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .nose),
        (.leftShoulder, .neck), (.rightShoulder, .neck),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]
}
