import CoreGraphics

struct TemplateSpec: Equatable, Hashable {
    let name: String
    let svgFilename: String
    let nativeSize: CGSize
    let left: CGFloat
    let top: CGFloat
    let right: CGFloat
    let bottom: CGFloat
    let bottomRight: CGFloat

    static func == (lhs: TemplateSpec, rhs: TemplateSpec) -> Bool { lhs.name == rhs.name }
    func hash(into hasher: inout Hasher) { hasher.combine(name) }

    static let v1 = TemplateSpec(
        name: "V1", svgFilename: "Template border V1.svg",
        nativeSize: CGSize(width: 1999, height: 1545),
        left: 203, top: 190, right: 235, bottom: 210, bottomRight: 380
    )
    static let v2 = TemplateSpec(
        name: "V2", svgFilename: "Template border V2.svg",
        nativeSize: CGSize(width: 1999, height: 1545),
        left: 99, top: 107, right: 99, bottom: 107, bottomRight: 325
    )
    static let all: [TemplateSpec] = [.v1, .v2]
}
