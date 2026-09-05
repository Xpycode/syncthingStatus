import AppKit
import Combine

/// A native sheet with a scrollable, immutable review of the exact deletion set.
@MainActor
enum CleanupConfirmationDialog {
    static func present(_ review: CleanupConfirmation, controller: StuckDeletesController,
                        window: NSWindow, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Permanently delete \(review.names.count) selected folder\(review.names.count == 1 ? "" : "s")?"
        alert.informativeText = "Configured folder root:\n\(review.rootPath)\n\nThe folders listed below and everything inside them—including ignored files—will be permanently deleted. This cannot be undone."
        let delete = alert.addButton(withTitle: "Delete Permanently")
        delete.hasDestructiveAction = true
        delete.keyEquivalent = ""
        let cancel = alert.addButton(withTitle: "Cancel")
        cancel.keyEquivalent = "\r"

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 440, height: 160))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let names = NSTextView(frame: scroll.bounds)
        names.isEditable = false
        names.isSelectable = true
        names.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        names.string = review.names.joined(separator: "\n")
        names.textContainerInset = NSSize(width: 8, height: 8)
        names.isVerticallyResizable = true
        names.isHorizontallyResizable = false
        names.autoresizingMask = [.width]
        names.textContainer?.widthTracksTextView = true
        names.setAccessibilityLabel("Selected folders within \(review.rootPath)")
        scroll.documentView = names
        alert.accessoryView = scroll

        var observation: AnyCancellable?
        observation = controller.$confirmation.sink { current in
            delete.isEnabled = current == review
        }
        alert.beginSheetModal(for: window) { response in
            observation?.cancel()
            observation = nil
            completion(response == .alertFirstButtonReturn)
        }
    }
}
