import AppKit

enum Exporter {
    enum ExportError: Error { case encodingFailed }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ExportError.encodingFailed
        }
        try data.write(to: url)
    }
}
