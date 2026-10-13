import Cocoa
import Carbon

extension NSApplication {
    /// `true` when the process was started by a login item / SMLoginItem.
    var launchedAtLogin: Bool {
        guard
            let event = NSAppleEventManager.shared().currentAppleEvent,
            event.eventID == AEEventID(kAEOpenApplication),      // `'oapp'`
            let prop = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))
        else { return false }

        return prop.enumCodeValue == AEKeyword(keyAELaunchedAsLogInItem)
    }
}