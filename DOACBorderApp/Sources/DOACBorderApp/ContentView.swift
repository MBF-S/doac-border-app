import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var state = AppState()
    @State private var isDragging = false
    @State private var dragStartPan = CGPoint(x: 0.5, y: 0.5)
    @State private var isPinching = false
    @State private var pinchStartZoom: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            preview
            controls
            if let msg = state.errorMessage {
                Text(msg).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 560)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    DispatchQueue.main.async { state.load(url: url) }
                }
            }
            return true
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.1))
            if let rendered = state.rendered {
                GeometryReader { geo in
                    Image(decorative: rendered, scale: 1, orientation: .up)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        // GeometryReader doesn't center its child by default (it pins to
                        // top-leading), and scaledToFit's own reported size shrinks to the
                        // fitted content box rather than claiming the full proposed space --
                        // so without this the image sits at the top-left instead of centered.
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(dragToRepositionGesture(viewSize: geo.size).simultaneously(with: pinchToZoomGesture()))
                        .onHover { hovering in
                            guard state.mode != .free else { return }
                            (hovering ? NSCursor.openHand : NSCursor.arrow).set()
                        }
                }
            } else {
                VStack(spacing: 8) {
                    Text("Drop an image here").foregroundColor(.secondary)
                    Button("Choose Image…") { chooseFile() }
                }
            }
        }
        .frame(minHeight: 360)
    }

    // Drag-to-reposition: the image follows the finger/cursor (Photos.app-style
    // crop dragging), so the pan value — which represents how far into the
    // image the visible window looks — moves opposite the drag direction.
    // Only active in A4/A5 modes, matching where positioning is meaningful.
    private func dragToRepositionGesture(viewSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard state.mode != .free, viewSize.width > 0, viewSize.height > 0 else { return }
                if !isDragging {
                    isDragging = true
                    dragStartPan = CGPoint(x: state.position.panX, y: state.position.panY)
                    NSCursor.closedHand.set()
                }
                let dx = value.translation.width / viewSize.width
                let dy = value.translation.height / viewSize.height
                state.position.panX = min(max(dragStartPan.x - dx, 0), 1)
                state.position.panY = min(max(dragStartPan.y - dy, 0), 1)
                state.rerender()
            }
            .onEnded { _ in
                isDragging = false
                NSCursor.openHand.set()
            }
    }

    // Trackpad pinch-to-zoom: lets the image zoom past "cover" so both axes
    // overflow the hole and can be panned (see PositionState for why zoom<=1
    // only ever frees one axis on a non-square image).
    private func pinchToZoomGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard state.mode != .free else { return }
                if !isPinching {
                    isPinching = true
                    pinchStartZoom = state.position.zoom
                }
                state.position.zoom = min(max(pinchStartZoom * value, 0), PositionState.maxZoom)
                state.rerender()
            }
            .onEnded { _ in isPinching = false }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("Template", selection: $state.template) {
                ForEach(TemplateSpec.all, id: \.name) { spec in
                    Text(spec.name).tag(spec)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: state.template) { _ in state.rerender() }

            Picker("Mode", selection: $state.mode) {
                Text("Free size").tag(PageMode.free)
                Text("A4").tag(PageMode.a4)
                Text("A5").tag(PageMode.a5)
                Text("Custom").tag(PageMode.custom)
            }
            .pickerStyle(.segmented)
            .onChange(of: state.mode) { _ in state.rerender() }

            if state.mode != .free {
                pageSettings
                positioning
            }

            HStack {
                Button("Choose Image…") { chooseFile() }
                Spacer()
                Button("Export…") { export() }
                    .disabled(state.rendered == nil)
            }
        }
    }

    private var positioning: some View {
        Text("Drag or pinch the preview image to reposition and zoom")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    private var pageSettings: some View {
        VStack(spacing: 8) {
            if state.mode == .custom {
                HStack {
                    Text("Size (mm)")
                    TextField("Width", value: $state.customWidthMM, format: .number)
                        .frame(width: 56)
                        .onChange(of: state.customWidthMM) { _ in state.rerender() }
                    Text("×")
                    TextField("Height", value: $state.customHeightMM, format: .number)
                        .frame(width: 56)
                        .onChange(of: state.customHeightMM) { _ in state.rerender() }
                }
            }
            Picker("Orientation", selection: $state.orientation) {
                Text("Portrait").tag(PageOrientation.portrait)
                Text("Landscape").tag(PageOrientation.landscape)
            }
            .pickerStyle(.segmented)
            .onChange(of: state.orientation) { _ in state.rerender() }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            state.load(url: url)
        }
    }

    private func export() {
        guard let rendered = state.rendered, let sourceURL = state.photoURL else { return }
        let suffix: String
        switch state.mode {
        case .free: suffix = "bordered"
        case .a4: suffix = "a4"
        case .a5: suffix = "a5"
        case .custom: suffix = "custom"
        }
        let defaultName = sourceURL.deletingPathExtension().lastPathComponent + "_\(suffix).png"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = defaultName
        panel.directoryURL = sourceURL.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try Exporter.writePNG(rendered, to: url)
        } catch {
            state.errorMessage = "Export failed: \(error)"
        }
    }
}
