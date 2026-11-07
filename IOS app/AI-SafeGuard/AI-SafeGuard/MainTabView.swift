import SwiftUI

struct MainTabView: View {
    // 🌟 接收全域大腦
    @EnvironmentObject var sharedViewModel: DashboardViewModel
    
    // 🌟 追蹤目前使用者停留在哪一個分頁，預設為首頁
    @State private var selectedTab: String = "Dashboard"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            Tab("Dashboard", systemImage: "square.grid.2x2.fill", value: "Dashboard") {
                DashboardView()
            }
            
            Tab("Events", systemImage: "exclamationmark.triangle.fill", value: "Events") {
                EventsView()
                    .onAppear {
                        // 如果 App 一打開就在 Events 頁面，立刻清除紅點
                        sharedViewModel.clearUnreadBadge()
                    }
            }
            // 原生支援自動判斷 0 隱藏，>0 顯示數字
            .badge(sharedViewModel.unreadBadgeCount)
            
            // 🌟 數據分析與 AI 戰術助手
            Tab("Analytics", systemImage: "chart.xyaxis.line", value: "Analytics") {
                AnalyticsView()
            }
            
            // 🚀 【本次新增】設備與權限管理中心 (RBAC & Camera Config)
            Tab("Devices", systemImage: "server.rack", value: "Devices") {
                DeviceSettingsView()
            }
            
            Tab("Settings", systemImage: "gearshape.fill", value: "Settings") {
                SettingsView()
            }
        }
        // 🌟 開啟最新的自適應樣式 (iOS 18)
        .tabViewStyle(.sidebarAdaptable)
        .tint(.themeIndigo)
        .preferredColorScheme(.dark)
        .onAppear {
            // 啟動背景輪詢與通知授權
            sharedViewModel.startPolling()
            NotificationManager.shared.requestPermission()
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == "Events" {
                // 只要點擊切換到 Events 頁面，立刻標記所有事件為已讀，紅點瞬間消失
                sharedViewModel.clearUnreadBadge()
            }
        }
    }
}
