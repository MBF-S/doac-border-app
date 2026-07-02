import CoreGraphics

struct PositionState: Equatable {
    // 0 = contain (default), 1 = cover (fills exactly, no gutter). Above 1, cover's
    // own aspect-locked axis still only just fills the hole, so only the other axis
    // has room to pan (a non-square image can only ever pan on one axis at zoom<=1).
    // Zoom is allowed past 1 (up to maxZoom) so both axes can overflow and pan freely.
    static let maxZoom: CGFloat = 4

    var zoom: CGFloat = 0
    var panX: CGFloat = 0.5     // 0...1, only takes effect once zoom creates overflow
    var panY: CGFloat = 0.5

    static let auto = PositionState()

    /// Rect (top-left-origin, in hole pixel space) to draw the full source
    /// image into, given the hole size and the image's own native size.
    func placement(imageSize: CGSize, holeSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let containScale = min(holeSize.width / imageSize.width, holeSize.height / imageSize.height)
        let coverScale = max(holeSize.width / imageSize.width, holeSize.height / imageSize.height)
        let scale = containScale + (coverScale - containScale) * min(max(zoom, 0), Self.maxZoom)

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
