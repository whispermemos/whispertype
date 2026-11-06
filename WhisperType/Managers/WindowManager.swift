import AppKit
import Combine

class WindowManager: ObservableObject {
    private var recordingWindow = RecordingWindow()

    func showRecordingWindow() {
        globalAnimationManager.isWindowVisible = true
        recordingWindow.makeKeyAndOrderFront(nil)
    }

    // The window is ordered out by `finishHidingWindow` once the hide animation ends.
    func hideRecordingWindow() {
        globalAnimationManager.isWindowVisible = false
    }

    func finishHidingWindow() {
        recordingWindow.orderOut(nil)
    }
}
