import Cocoa

extension NSOpenPanel {
    func beginSheetModal(for window: NSWindow?, completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {
        if let window {
            self.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(self.runModal())
        }
    }
}
