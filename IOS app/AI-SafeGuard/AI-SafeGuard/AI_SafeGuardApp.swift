import SwiftUI

@main // 🌟 程式的真正起點
struct AI_SafeGuardApp: App {
    // 建立全域大腦 (ViewModel)
    @StateObject private var sharedViewModel = DashboardViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("app_language") private var appLanguage: String = "en"
    
   
    // 單例模式 (Singleton) 預設會「賴床」，直到你第一次使用它才會初始化。
    // 如果不在這裡強制喚醒它，iOS 系統發送通知時會找不到代理人 (Delegate)，導致通知被默默吃掉。
    init() {
        _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sharedViewModel)
                .environmentObject(authViewModel)
                .environment(\.locale, .init(identifier: appLanguage))
        }
    }
}

// 🚦 路由器大交警 (負責判斷登入狀態與畫面導航)
struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("app_language") private var appLanguage: String = "en"
    
    var body: some View {
        Group {
            if authViewModel.isCheckingAuth {
                ZStack {
                    Color.themeBg.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.themeEmerald)
                        ProgressView().tint(.themeIndigo)
                    }
                }
            } else if authViewModel.isLoggedIn {
                MainTabView() // 🌟 這裡呼叫你的水滴導航列
                    .id(appLanguage)
            } else {
                LoginView()
            }
        }
        .task { await authViewModel.checkLoginStatus() }
    }
}
