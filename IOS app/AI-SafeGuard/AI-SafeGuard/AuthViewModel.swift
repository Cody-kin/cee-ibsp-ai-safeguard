import Foundation
import Combine
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String = ""
    @Published var isCheckingAuth: Bool = true
    
    @Published var currentUser: SGUserProfile?
    
    func checkLoginStatus() async {
        let token = UserDefaults.standard.string(forKey: "aisafeguard_access_token")
        guard let token = token, !token.isEmpty else {
            self.isLoggedIn = false
            self.isCheckingAuth = false
            return
        }
        
        do {
            let profile = try await AISafeGuardAPIClient.shared.fetchMe()
            self.currentUser = profile
            
            // 🌟 完美修復：改用我們寫好的 displayName (保證一定有值，絕對不會報錯)
            self.username = profile.displayName
            self.isLoggedIn = true
        } catch {
            print("🚨 Token 失效，需要重新登入")
            self.logout()
        }
        self.isCheckingAuth = false
    }
    
    func loadUserIdentity() async {
        do {
            self.errorMessage = ""
            try await AISafeGuardAPIClient.shared.login(username: self.username, password: self.password)
            
            let profile = try await AISafeGuardAPIClient.shared.fetchMe()
            self.currentUser = profile
            
            // 🌟 完美修復：改用 displayName
            self.username = profile.displayName
            self.isLoggedIn = true
            
            print("✅ 成功獲取真實身分：\(profile.displayName) (\(profile.role))")
        } catch {
            print("🚨 登入失敗：\(error.localizedDescription)")
            self.isLoggedIn = false
            self.currentUser = nil
            self.errorMessage = "帳號或密碼錯誤，或是伺服器無回應。"
        }
    }
    
    func logout() {
        self.currentUser = nil
        self.isLoggedIn = false
        self.username = ""
        self.password = ""
        self.errorMessage = ""
        UserDefaults.standard.removeObject(forKey: "aisafeguard_access_token")
    }
}

