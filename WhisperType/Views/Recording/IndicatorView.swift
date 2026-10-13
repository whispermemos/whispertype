import SwiftUI
import Lottie

struct IndicatorView: View {
    let size = 30.0
    
    @State var isVisible = false
    
    var body: some View {
        VStack {
            if isVisible {
                LottieView(animation: .named("Loader2"))
                    .playing(loopMode: .loop)
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .opacity(0.8)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isVisible = true
            }
        }
    }
}

