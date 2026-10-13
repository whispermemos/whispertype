import Cocoa

class AnimatedWindow: NSWindow {
    override init(
        contentRect: NSRect, styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)

        print("--> window was initialized")
    }

//    private func setupAnchorPoint() {
//        guard let layer = self.contentView?.layer else { return }
//        guard let contentView = self.contentView else { return }
//
//        print("bounds: \(contentView.bounds)")
//
//        // Set anchor point to center
//        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
//
//        // Adjust position to maintain visual location
//        layer.position = CGPoint(x: contentView.bounds.width / 2, y: contentView.bounds.height / 2)
//    }

//    func animateOnShow() {
//        setupAnchorPoint()
//
//        //        guard let layer = self.contentView?.layer else { return }
//        //        layer.opacity = 1.0
//        //        layer.transform = CATransform3DIdentity
//
//        guard let layer = self.contentView?.layer else { return }
//
//        // Set initial state
//        layer.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
//        layer.opacity = 0.0
//
//        // Create animations
//        let scaleAnimation = CABasicAnimation(keyPath: "transform")
//        scaleAnimation.fromValue = CATransform3DMakeScale(0.8, 0.8, 1.0)
//        scaleAnimation.toValue = CATransform3DIdentity
//
//        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
//        opacityAnimation.fromValue = 0.0
//        opacityAnimation.toValue = 1.0
//
//        let group = CAAnimationGroup()
//        group.animations = [scaleAnimation, opacityAnimation]
//        group.duration = 0.1  // Increased duration for bounce effect
//        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
//
//        // Set final values
//        layer.transform = CATransform3DIdentity
//        layer.opacity = 1.0
//
//        // Add animation
//        layer.add(group, forKey: "showAnimation")
//    }
//
//    func animateOnHide(completion: (() -> Void)? = nil) {
//        guard let layer = self.contentView?.layer else { return }
//
//        // Create animations
//        let scaleAnimation = CABasicAnimation(keyPath: "transform")
//        scaleAnimation.fromValue = layer.transform
//        scaleAnimation.toValue = CATransform3DMakeScale(0.8, 0.8, 1.0)
//
//        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
//        opacityAnimation.fromValue = layer.opacity
//        opacityAnimation.toValue = 0.0
//
//        let group = CAAnimationGroup()
//        group.animations = [scaleAnimation, opacityAnimation]
//        group.duration = 0.1
//        group.timingFunction = CAMediaTimingFunction(name: .easeIn)
//
//        // Set final values
//        layer.transform = CATransform3DMakeScale(0.8, 0.8, 1.0)
//        layer.opacity = 0.0
//
//        CATransaction.begin()
//        CATransaction.setCompletionBlock(completion)
//        layer.add(group, forKey: "hideAnimation")
//        CATransaction.commit()
//    }
}
