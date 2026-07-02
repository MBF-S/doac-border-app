import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var photoURL: URL?
    @Published var photo: CGImage?
    @Published var template: TemplateSpec = .v1
    @Published var mode: PageMode = .free
    @Published var position: PositionState = .auto
    @Published var orientation: PageOrientation = .portrait
    @Published var customWidthMM: Double = 210
    @Published var customHeightMM: Double = 297
    @Published var rendered: CGImage?
    @Published var errorMessage: String?

    func load(url: URL) {
        guard let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data),
              let image = rep.cgImage else {
            errorMessage = "Couldn't read image: \(url.lastPathComponent)"
            return
        }
        photoURL = url
        photo = image
        position = .auto
        orientation = image.width > image.height ? .landscape : .portrait
        rerender()
    }

    func rerender() {
        guard let photo else { rendered = nil; return }
        guard let svgURL = Bundle.main.resourceURL?.appendingPathComponent(template.svgFilename) else {
            errorMessage = "Missing frame resource: \(template.svgFilename)"
            return
        }
        do {
            rendered = try BorderedImage.make(photo: photo, mode: mode, spec: template, svgURL: svgURL, position: position,
                                               customSizeMM: (customWidthMM, customHeightMM), orientation: orientation)
            errorMessage = nil
        } catch {
            errorMessage = "\(error)"
        }
    }
}
