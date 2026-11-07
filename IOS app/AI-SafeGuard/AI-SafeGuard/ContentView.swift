import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSplash = true
    @State private var logoScale = 0.8
    @State private var logoOpacity = 0.0
    
    var body: some View {
        Group {
            if showSplash {
                // 🌟 啟動閃屏：完美遮蔽讀取狀態的瞬間
                ZStack {
                    Color.themeBg.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 80, weight: .thin))
                            .foregroundColor(.themeIndigo)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                        
                        Text("AI-SafeGuard")
                            .font(.title2).fontWeight(.black)
                            .foregroundColor(.white)
                            .tracking(4)
                            .opacity(logoOpacity)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5)) {
                        logoScale = 1.0
                        logoOpacity = 1.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
                }
            } else {
                if authViewModel.currentUser != nil {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
        }
    }
}
