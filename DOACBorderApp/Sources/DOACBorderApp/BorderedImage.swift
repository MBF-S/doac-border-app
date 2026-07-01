import CoreGraphics
import Foundation

enum BorderedImage {
    static func make(photo: CGImage, mode: PageMode, spec: TemplateSpec, svgURL: URL,
                      position: PositionState = .auto) throws -> CGImage {
        let photoSize = CGSize(width: photo.width, height: photo.height)
        let layout = FrameLayout.make(mode: mode, imageSize: photoSize, spec: spec)
        let holeSize = CGSize(width: layout.holeWidth, height: layout.holeHeight)

        let placement: CGRect = mode == .free
            ? CGRect(origin: .zero, size: holeSize) // whole image, untouched, no crop
            : position.placement(imageSize: photoSize, holeSize: holeSize)

        guard let holeCtx = CGContext(
            data: nil, width: layout.holeWidth, height: layout.holeHeight, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw FrameRenderer.RenderError.contextCreationFailed }

        holeCtx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        holeCtx.fill(CGRect(x: 0, y: 0, width: layout.holeWidth, height: layout.holeHeight))

        // placement is top-left-authored; flip Y the same way FrameRenderer's dst rects do.
        let holeHeightF = CGFloat(layout.holeHeight)
        let flippedPlacement = CGRect(
            x: placement.minX, y: holeHeightF - placement.maxY,
            width: placement.width, height: placement.height
        )
        holeCtx.draw(photo, in: flippedPlacement)
        guard let holeContent = holeCtx.makeImage() else { throw FrameRenderer.RenderError.finalImageFailed }

        return try FrameRenderer.render(holeContent: holeContent, layout: layout, svgURL: svgURL)
    }
}
