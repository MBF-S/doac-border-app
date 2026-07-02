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
    static func render(holeContent: CGImage, layout: FrameLayout, spec: TemplateSpec, svgURL: URL) throws -> CGImage {
        guard let svg = SwiftDraw.SVG(fileURL: svgURL) else { throw RenderError.svgLoadFailed }

        // Rasterize the border at a resolution independent of layout.scale.
        // The border is vector, so it can be rendered crisply at any size --
        // but layout.scale shrinks for thin borders (small images / small
        // pages), which would also shrink the small-but-detailed DOAC
        // wordmark in the bottom-right corner to a blocky, pixelated size.
        // Never rasterize below native SVG resolution; corners/edges below
        // downsample from this into the (possibly smaller) target size,
        // which stays crisp, instead of upsampling a low-res render.
        let renderScale = max(layout.scale, 1.0)
        let nW = Int((svg.size.width * renderScale).rounded())
        let nH = Int((svg.size.height * renderScale).rounded())

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
        ctx.interpolationQuality = .high

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

        // Destination margins are in the final layout's scale.
        let left = CGFloat(layout.left), top = CGFloat(layout.top)
        let right = CGFloat(layout.right), bottom = CGFloat(layout.bottom)
        let brW = CGFloat(layout.bottomRight)
        let cwF = CGFloat(cw)
        // Source margins are in the border raster's own (>= native) scale.
        let nWf = CGFloat(nW), nHf = CGFloat(nH)
        let srcLeft = spec.left * renderScale, srcTop = spec.top * renderScale
        let srcRight = spec.right * renderScale, srcBottom = spec.bottom * renderScale
        let srcBrW = spec.bottomRight * renderScale

        // corners (native to the render raster, downsampled to the target size)
        try paste(srcRect: CGRect(x: 0, y: 0, width: srcLeft, height: srcTop),
                  dstRect: CGRect(x: 0, y: 0, width: left, height: top))
        try paste(srcRect: CGRect(x: nWf - srcRight, y: 0, width: srcRight, height: srcTop),
                  dstRect: CGRect(x: cwF - right, y: 0, width: right, height: top))
        try paste(srcRect: CGRect(x: 0, y: nHf - srcBottom, width: srcLeft, height: srcBottom),
                  dstRect: CGRect(x: 0, y: chF - bottom, width: left, height: bottom))
        try paste(srcRect: CGRect(x: nWf - srcBrW, y: nHf - srcBottom, width: srcBrW, height: srcBottom),
                  dstRect: CGRect(x: cwF - brW, y: chF - bottom, width: brW, height: bottom))

        // edges (stretched only along their length)
        try paste(srcRect: CGRect(x: srcLeft, y: 0, width: nWf - srcRight - srcLeft, height: srcTop),
                  dstRect: CGRect(x: left, y: 0, width: cwF - left - right, height: top))
        let bottomEdgeW = cwF - left - brW
        try paste(srcRect: CGRect(x: srcLeft, y: nHf - srcBottom, width: nWf - srcBrW - srcLeft, height: srcBottom),
                  dstRect: CGRect(x: left, y: chF - bottom, width: bottomEdgeW, height: bottom))
        try paste(srcRect: CGRect(x: 0, y: srcTop, width: srcLeft, height: nHf - srcBottom - srcTop),
                  dstRect: CGRect(x: 0, y: top, width: left, height: chF - bottom - top))
        try paste(srcRect: CGRect(x: nWf - srcRight, y: srcTop, width: srcRight, height: nHf - srcBottom - srcTop),
                  dstRect: CGRect(x: cwF - right, y: top, width: right, height: chF - bottom - top))

        guard let result = ctx.makeImage() else { throw RenderError.finalImageFailed }
        return result
    }
}
