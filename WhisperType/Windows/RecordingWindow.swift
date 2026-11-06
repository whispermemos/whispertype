import AppKit
import SwiftUI

let windowWidth = 240.0
let windowHeight = 50.0
let smallSize = 65.0
let hideOffset = 50.0

private func calculateWindowPosition() -> NSPoint {
    let screenFrame = NSScreen.main?.frame ?? .zero
    let x = (screenFrame.width - windowWidth) / 2
    let y = screenFrame.height * 0.2  // 20% from bottom
    return NSPoint(x: x, y: y)
}

class RecordingWindow: NSWindow {
    private var screenObserver: Any?
    
    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func updateWindowPosition() {
        self.setFrameOrigin(calculateWindowPosition())
    }
    
    init() {
        // Create a rect that's wider than it is tall, similar to volume control
        let height: CGFloat = windowHeight + hideOffset

        // Position near bottom of screen
        let position = calculateWindowPosition()
        
        super.init(
            contentRect: NSRect(x: position.x, y: position.y, width: windowWidth, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Configure window properties
        self.level = .screenSaver  // Higher level than .floating to ensure always on top
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false

        // Make it non-activating (won't steal focus)
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = true

        // Set the SwiftUI view as content
        let hostingView = NSHostingView(rootView: RecordingWindowView())
        self.contentView = hostingView
        
        // Observe screen parameter changes
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateWindowPosition()
        }
    }
}

struct RecordingWindowView: View {
    var body: some View {
        RecordingWindowInnerView()
            .environmentObject(globalRecordingManager)
            .environmentObject(globalAnimationManager)
    }
}

struct RecordingWindowInnerView: View {
    @EnvironmentObject var animationManager: AnimationManager
    @EnvironmentObject var recordingManager: RecordingManager

    enum WindowSize {
        case full
        case small
    }

    enum AnimationStage {
        case hidden
        case halfway
        case shown

        var opacity: Double {
            switch self {
            case .hidden: return 0.1
            case .halfway: return 0.4
            case .shown: return 1
            }
        }

        var contentsOpacity: Double {
            self == .shown ? 1 : 0
        }

        var offset: CGFloat {
            switch self {
            case .hidden: return 40
            case .halfway: return 10
            case .shown: return 0
            }
        }
    }

    @State var size: WindowSize = .full
    @State var stage: AnimationStage = .hidden

    var body: some View {
        ZStack {
            ZStack {
                VisualEffectView(material: .fullScreenUI, blendingMode: .withinWindow)
                Color.black.opacity(0.8)
            }

            RecordingView()
                .opacity(stage.contentsOpacity)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(
            width: size == .small ? smallSize : windowWidth,
            height: size == .small ? smallSize : windowHeight,
            alignment: .top
        )
        .opacity(stage.opacity)
        .offset(y: stage.offset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: recordingManager.state) { _, newState in
            // Shrink to a small square while transcribing. The widget keeps this size after
            // hiding, so the next recording widens back out, which we like.
            withAnimation(.linear(duration: 0.075)) {
                if newState == .transcribing {
                    size = .small
                } else if newState == .recording || newState == .preparing {
                    size = .full
                }
            }
        }
        .onChange(of: animationManager.isWindowVisible) { _, isVisible in
            if isVisible {
                // Show instantly, so the widget appears right after the shortcut.
                stage = .shown
            } else {
                hide()
            }
        }
    }

    // Shrinks, then slides down and fades out, then orders the window out.
    private func hide() {
        withAnimation(.linear(duration: 0.1)) {
            stage = .halfway
        } completion: {
            withAnimation(.linear(duration: 0.07)) {
                stage = .hidden
            } completion: {
                globalWindowManager.finishHidingWindow()
            }
        }
    }
}
