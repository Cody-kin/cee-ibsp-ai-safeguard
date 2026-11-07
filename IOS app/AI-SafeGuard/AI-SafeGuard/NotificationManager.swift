import Foundation
import UserNotifications
import Combine

// 🌟 負責處理系統級推播與點擊跳轉的神經中樞
class NotificationManager: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    // 單例模式 (Singleton)，確保全 App 共用同一個通知管理員
    static let shared = NotificationManager()
    
    // 當使用者點擊通知時，這個變數會發佈被點擊的 Event ID
    @Published var tappedEventId: Int?
    
    private override init() {
        super.init()
        // 🛡️ 將自己註冊為 iOS 通知中心的代理人
        // 必須要在 App 啟動時立刻執行 (已在 AI_SafeGuardApp.swift 內喚醒)
        UNUserNotificationCenter.current().delegate = self
    }
    
    // 🔑 要求推播權限 (通常在登入後或首頁呼叫)
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ [系統] 推播通知權限已授權")
            } else if let error = error {
                print("🚨 [系統] 推播權限遭拒：\(error.localizedDescription)")
            }
        }
    }
    
    // 📣 發送本地推播警告 (給 ViewModel 呼叫)
    func sendDangerAlert(title: String, body: String, eventId: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default // Critical alerts require a separate Apple entitlement.
        content.userInfo = ["eventId": eventId] // 夾帶事件 ID，使用者點擊時才能跳轉到正確的詳情頁
        
        // trigger 設為 nil，代表「不要等，立刻馬上彈出！」
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - UNUserNotificationCenterDelegate 實作
    
    // 👆 動作一：當使用者「點擊」了通知橫幅時觸發 (Deep Link 跳轉)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let eventId = userInfo["eventId"] as? Int {
            DispatchQueue.main.async {
                // 將點擊的 ID 廣播出去，Dashboard 收到後就會彈出該事件的詳情卡片
                self.tappedEventId = eventId
            }
        }
        completionHandler() // 必須呼叫，告訴系統處理完畢
    }
    
    // 📱 動作二：打破 iOS 的「前景防擾規則」
    // 如果沒有實作這個方法，當使用者正看著 App 時，通知會被系統吃掉。
    // 加上這段，就是命令 iOS：「就算我在用 App，也給我把聲音跟橫幅彈出來！」
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}
