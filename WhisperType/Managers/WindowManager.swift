import AppKit
import Combine

class WindowManager: ObservableObject {
    //    static let shared = WindowManager()

    private var recordingWindow = RecordingWindow()

    func showRecordingWindow() {
        globalAnimationManager.isWindowVisible = true

        //        recordingWindow.alphaValue = 1
        recordingWindow.makeKeyAndOrderFront(nil)
        //        recordingWindow.animateOnShow()

        print("showed the window")
    }

    func hideRecordingWindow() {
        globalAnimationManager.isWindowVisible = false

        //        recordingWindow.animateOnHide {
        //            self.recordingWindow.orderOut(nil)
        //        }

    }

    func finishHidingWindow() {
        self.recordingWindow.orderOut(nil)
    }
}
