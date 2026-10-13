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

class RecordingWindow: AnimatedWindow {
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

let slowDown = 1.0

struct RecordingWindowInnerView: View {
    @EnvironmentObject var animationManager: AnimationManager
    @EnvironmentObject var recordingManager: RecordingManager
    @State var isVisible = false
    
    enum WindowSize {
        case full
        case small
    }

    enum AnimationStage {
        case hidden
        case firstStage
        case fullyShown

        var opacity: Double {
            switch self {
            case .hidden: return 0.1
            case .firstStage: return 0.4
            case .fullyShown: return 1
            }
        }
        
        var contentsOpacity: Double {
            switch self {
            case .hidden: return 0
            case .firstStage: return 0
            case .fullyShown: return 1
            }
        }

        var scale: Double {
            switch self {
            case .hidden: return 0.5
            case .firstStage: return 0.7
            case .fullyShown: return 1
            }
        }

        var offset: CGFloat {
            switch self {
            case .hidden: return 40.0
            case .firstStage: return 10
            case .fullyShown: return 0
            }
        }
    }

    @State var size: WindowSize = .full
    @State var stage: AnimationStage = .hidden

    var body: some View {
        Group {
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
//            .scaleEffect(stage.scale)
            .offset(y: stage.offset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: recordingManager.state, { oldValue, newValue in
            withAnimation(.linear(duration: 0.1 * slowDown)) {
                if newValue == .transcribing {
                    size = .small
                } else if newValue == .recording || newValue == .preparing {
                    size = .full
                }
            }
        })
        .onChange(
            of: animationManager.isWindowVisible,
            { oldValue, newValue in
                if newValue {
                    // Show animation sequence
                    stage = .hidden

                    // First stage: move up and fade in partially
                    withAnimation(.linear(duration: 0.07 * slowDown)) {
                        stage = .firstStage
                    } completion: {
                        // Second stage: scale up to full size
                        withAnimation(.easeOut(duration: 0.1 * slowDown)) {
                            stage = .fullyShown
                        }
                    }
                } else {
                    // Hide animation sequence
                    withAnimation(.linear(duration: 0.1 * slowDown)) {
                        // First shrink
                        stage = .firstStage
                    } completion: {
                        // Then move down and fade out
                        withAnimation(.linear(duration: 0.07 * slowDown)) {
                            stage = .hidden
                        } completion: {
                            globalWindowManager.finishHidingWindow()
                        }
                    }
                }
            })
    }
}
