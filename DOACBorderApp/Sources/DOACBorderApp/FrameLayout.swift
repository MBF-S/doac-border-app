import CoreGraphics

enum PageMode: Equatable {
    case free
    case a4
    case a5

    var pageSizeMM: (width: Double, height: Double)? {
        switch self {
        case .free: return nil
        case .a4: return (210, 297)
        case .a5: return (148, 210)
        }
    }
}

struct FrameLayout: Equatable {
    let scale: CGFloat
    let left: Int
    let top: Int
    let right: Int
    let bottom: Int
    let bottomRight: Int
    let canvasWidth: Int
    let canvasHeight: Int
    let holeWidth: Int
    let holeHeight: Int

    static func make(mode: PageMode, imageSize: CGSize, spec: TemplateSpec,
                      pct: CGFloat = 0.08, minPx: CGFloat = 60, dpi: CGFloat = 300) -> FrameLayout {
        guard let mm = mode.pageSizeMM else {
            return freeForm(imageSize: imageSize, spec: spec, pct: pct, minPx: minPx)
        }
        var mmW = mm.width, mmH = mm.height
        if imageSize.width > imageSize.height { swap(&mmW, &mmH) }
        let canvasWidth = Int((mmW / 25.4 * dpi).rounded())
        let canvasHeight = Int((mmH / 25.4 * dpi).rounded())

        let scale = max(pct * CGFloat(min(canvasWidth, canvasHeight)), minPx) / spec.left
        let left = Int((spec.left * scale).rounded())
        let top = Int((spec.top * scale).rounded())
        let right = Int((spec.right * scale).rounded())
        let bottom = Int((spec.bottom * scale).rounded())
        let bottomRight = Int((spec.bottomRight * scale).rounded())

        return FrameLayout(
            scale: scale, left: left, top: top, right: right, bottom: bottom, bottomRight: bottomRight,
            canvasWidth: canvasWidth, canvasHeight: canvasHeight,
            holeWidth: canvasWidth - left - right, holeHeight: canvasHeight - top - bottom
        )
    }

    static func freeForm(imageSize: CGSize, spec: TemplateSpec, pct: CGFloat = 0.08, minPx: CGFloat = 60) -> FrameLayout {
        let leftTarget = max(pct * min(imageSize.width, imageSize.height), minPx)
        let scale = leftTarget / spec.left
        let left = Int((spec.left * scale).rounded())
        let top = Int((spec.top * scale).rounded())
        let right = Int((spec.right * scale).rounded())
        let bottom = Int((spec.bottom * scale).rounded())
        let bottomRight = Int((spec.bottomRight * scale).rounded())
        let holeWidth = Int(imageSize.width.rounded())
        let holeHeight = Int(imageSize.height.rounded())
        return FrameLayout(
            scale: scale, left: left, top: top, right: right, bottom: bottom, bottomRight: bottomRight,
            canvasWidth: left + holeWidth + right, canvasHeight: top + holeHeight + bottom,
            holeWidth: holeWidth, holeHeight: holeHeight
        )
    }
}
