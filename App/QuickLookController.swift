import AppKit
import Quartz

/// App delegate whose job is Quick Look: the panel walks the responder chain
/// (which ends at the application delegate) to find a controller, so this is
/// the one place a SwiftUI app can reliably own it.
@MainActor
final class StudioAppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var shared: StudioAppDelegate?

    private var items: [URL] = []
    private var currentIndex = 0

    override init() {
        super.init()
        Self.shared = self
    }

    /// Shows `urls` in the Quick Look panel starting at `index`; arrow keys
    /// page through the rest. No-ops when there is nothing to show.
    static func preview(_ urls: [URL], at index: Int = 0) {
        guard let delegate = shared, !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        delegate.items = urls
        delegate.currentIndex = min(max(index, 0), urls.count - 1)
        if panel.isVisible {
            panel.reloadData()
            panel.currentPreviewItemIndex = delegate.currentIndex
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
        panel.currentPreviewItemIndex = currentIndex
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
}

extension StudioAppDelegate: @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        items.count
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        items.indices.contains(index) ? items[index] as NSURL : nil
    }
}
