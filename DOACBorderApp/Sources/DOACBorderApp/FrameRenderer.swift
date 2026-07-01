import CoreGraphics
import AppKit
import SwiftDraw

enum FrameRenderer {
    enum RenderError: Error {
        case svgLoadFailed
        case contextCreationFailed
        case cropFailed
        case finalImageFailed
    }

    /// Renders `holeContent` inside the frame described by `layout`, using the
    /// SVG at `svgURL`. `holeContent` must already be exactly
    /// layout.holeWidth x layout.holeHeight.
    static func render(holeContent: CGImage, layout: FrameLayout, svgURL: URL) throws -> CGImage {
        guard let svg = SwiftDraw.SVG(fileURL: svgURL) else { throw RenderError.svgLoadFailed }

        let nW = Int((svg.size.width * layout.scale).rounded())
        let nH = Int((svg.size.height * layout.scale).rounded())

        guard let borderCtx = CGContext(
            data: nil, width: nW, height: nH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw RenderError.contextCreationFailed }
        // SVG content assumes top-left origin; flip so it draws right-side up.
        borderCtx.translateBy(x: 0, y: CGFloat(nH))
        borderCtx.scaleBy(x: 1, y: -1)
        borderCtx.draw(svg, in: CGRect(x: 0, y: 0, width: nW, height: nH))
        guard let border = borderCtx.makeImage() else { throw RenderError.finalImageFailed }

        let cw = layout.canvasWidth, ch = layout.canvasHeight
        guard let ctx = CGContext(
            data: nil, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw RenderError.contextCreationFailed }

        // Do NOT flip this context -- see Global Constraints. Flip only the
        // Y-position of each destination rect; crop src rects stay as-is.
        let chF = CGFloat(ch)
        func flipDst(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: chF - rect.maxY, width: rect.width, height: rect.height)
        }

        ctx.draw(holeContent, in: flipDst(CGRect(x: layout.left, y: layout.top, width: layout.holeWidth, height: layout.holeHeight)))

        func paste(srcRect: CGRect, dstRect: CGRect) throws {
            guard let piece = border.cropping(to: srcRect) else { throw RenderError.cropFailed }
            ctx.draw(piece, in: flipDst(dstRect))
        }

        let left = CGFloat(layout.left), top = CGFloat(layout.top)
        let right = CGFloat(layout.right), bottom = CGFloat(layout.bottom)
        let brW = CGFloat(layout.bottomRight)
        let cwF = CGFloat(cw)
        let nWf = CGFloat(nW), nHf = CGFloat(nH)

        // corners (native, never stretched)
        try paste(srcRect: CGRect(x: 0, y: 0, width: left, height: top),
                  dstRect: CGRect(x: 0, y: 0, width: left, height: top))
        try paste(srcRect: CGRect(x: nWf - right, y: 0, width: right, height: top),
                  dstRect: CGRect(x: cwF - right, y: 0, width: right, height: top))
        try paste(srcRect: CGRect(x: 0, y: nHf - bottom, width: left, height: bottom),
                  dstRect: CGRect(x: 0, y: chF - bottom, width: left, height: bottom))
        try paste(srcRect: CGRect(x: nWf - brW, y: nHf - bottom, width: brW, height: bottom),
                  dstRect: CGRect(x: cwF - brW, y: chF - bottom, width: brW, height: bottom))

        // edges (stretched only along their length)
        try paste(srcRect: CGRect(x: left, y: 0, width: nWf - right - left, height: top),
                  dstRect: CGRect(x: left, y: 0, width: cwF - left - right, height: top))
        let bottomEdgeW = cwF - left - brW
        try paste(srcRect: CGRect(x: left, y: nHf - bottom, width: nWf - brW - left, height: bottom),
                  dstRect: CGRect(x: left, y: chF - bottom, width: bottomEdgeW, height: bottom))
        try paste(srcRect: CGRect(x: 0, y: top, width: left, height: nHf - bottom - top),
                  dstRect: CGRect(x: 0, y: top, width: left, height: chF - bottom - top))
        try paste(srcRect: CGRect(x: nWf - right, y: top, width: right, height: nHf - bottom - top),
                  dstRect: CGRect(x: cwF - right, y: top, width: right, height: chF - bottom - top))

        guard let result = ctx.makeImage() else { throw RenderError.finalImageFailed }
        return result
    }
}
