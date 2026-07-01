import CoreGraphics

struct PositionState: Equatable {
    var zoom: CGFloat = 0       // 0 = contain (default), 1 = cover (fills, may crop)
    var panX: CGFloat = 0.5     // 0...1, only takes effect once zoom creates overflow
    var panY: CGFloat = 0.5

    static let auto = PositionState()

    /// Rect (top-left-origin, in hole pixel space) to draw the full source
    /// image into, given the hole size and the image's own native size.
    func placement(imageSize: CGSize, holeSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let containScale = min(holeSize.width / imageSize.width, holeSize.height / imageSize.height)
        let coverScale = max(holeSize.width / imageSize.width, holeSize.height / imageSize.height)
        let scale = containScale + (coverScale - containScale) * min(max(zoom, 0), 1)

        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale

        let maxOffsetX = max(0, drawWidth - holeSize.width)
        let maxOffsetY = max(0, drawHeight - holeSize.height)
        let clampedPanX = min(max(panX, 0), 1)
        let clampedPanY = min(max(panY, 0), 1)

        let x = maxOffsetX > 0 ? -maxOffsetX * clampedPanX : (holeSize.width - drawWidth) / 2
        let y = maxOffsetY > 0 ? -maxOffsetY * clampedPanY : (holeSize.height - drawHeight) / 2

        return CGRect(x: x, y: y, width: drawWidth, height: drawHeight)
    }
}
