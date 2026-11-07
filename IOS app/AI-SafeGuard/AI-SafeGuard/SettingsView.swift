import SwiftUI

// 🌟 內建翻譯引擎 (已補齊所有彈窗提示)
struct TR {
    static let dict: [String: [String: String]] = [
        "en": [
            "Settings": "Settings", "Profile Settings": "Profile Settings",
            "USERNAME": "USERNAME", "ROLE PERMISSION": "ROLE PERMISSION",
            "Language Preference": "Language Preference",
            "User Management": "User Management",
            "Username or Email": "Username or Email", "Password": "Password", "Add": "Add",
            "User (Name/Email)": "User (Name/Email)", "Role": "Role", "Action": "Action",
            "Loading users...": "Loading users...",
            "Database Cleanup Rules": "Database Cleanup Rules",
            "System will auto-delete records older than specified days.": "System will auto-delete records older than specified days.",
            "Keep events for:": "Keep events for:", "Days": "Days", "Save": "Save",
            "Danger Zone": "Danger Zone", "Clear All Data": "Clear All Data", "LOGOUT": "LOGOUT",
            "Confirm Logout": "Confirm Logout", "Cancel": "Cancel",
            "Are you sure you want to log out?": "Are you sure you want to log out?",
            "Dangerous Operation": "Dangerous Operation",
            "This will permanently delete all logs and photos. Continue?": "This will permanently delete all logs and photos. Continue?",
            "Confirm Clear (Cannot be undone)": "Confirm Clear (Cannot be undone)",
            "Success": "Success", "Failed": "Failed", "OK": "OK",
            
            // 彈跳視窗的具體訊息
            "Data wiped successfully.": "Data wiped successfully.",
            "Server error or rejected.": "Server error or rejected.",
            "User created!": "User created!",
            "Failed to create user.": "Failed to create user.",
            "User deleted.": "User deleted.",
            "Failed to delete.": "Failed to delete.",
            "Settings saved successfully.": "Settings saved successfully.",
            "Saved locally (Backend API pending).": "Saved locally (Backend API pending)."
        ],
        "zh-Hant": [
            "Settings": "系統設定", "Profile Settings": "個人資料",
            "USERNAME": "使用者帳號", "ROLE PERMISSION": "系統權限",
            "Language Preference": "語言偏好設定",
            "User Management": "用戶與權限管理",
            "Username or Email": "帳號名稱", "Password": "密碼", "Add": "新增",
            "User (Name/Email)": "用戶名稱", "Role": "身分", "Action": "操作",
            "Loading users...": "載入用戶名單中...",
            "Database Cleanup Rules": "資料庫自動清理規則",
            "System will auto-delete records older than specified days.": "系統將自動刪除超過指定天數的歷史紀錄與照片。",
            "Keep events for:": "保留歷史紀錄：", "Days": "天", "Save": "儲存變更",
            "Danger Zone": "危險操作區域", "Clear All Data": "清空所有資料", "LOGOUT": "登出指揮中心",
            "Confirm Logout": "確認登出", "Cancel": "取消",
            "Are you sure you want to log out?": "您確定要登出系統嗎？",
            "Dangerous Operation": "警告：危險操作",
            "This will permanently delete all logs and photos. Continue?": "這將永久刪除資料庫中所有的警報與感測器紀錄，確定要繼續嗎？",
            "Confirm Clear (Cannot be undone)": "確定清空 (無法還原)",
            "Success": "操作成功", "Failed": "操作失敗", "OK": "我知道了",
            
            // 彈跳視窗的具體訊息
            "Data wiped successfully.": "🔥 資料庫與影像已徹底清空！",
            "Server error or rejected.": "伺服器錯誤或拒絕請求。",
            "User created!": "👤 新用戶創建成功！",
            "Failed to create user.": "新增用戶失敗，請檢查帳號是否重複。",
            "User deleted.": "🗑️ 用戶已刪除",
            "Failed to delete.": "刪除用戶失敗。",
            "Settings saved successfully.": "✅ 資料庫清理規則已儲存！",
            "Saved locally (Backend API pending).": "✅ 已儲存至手機本地 (伺服器端尚未實作)。"
        ],
        "zh-Hans": [
            "Settings": "系统设置", "Profile Settings": "个人资料",
            "USERNAME": "用户账号", "ROLE PERMISSION": "系统权限",
            "Language Preference": "语言偏好设置",
            "User Management": "用户与权限管理",
            "Username or Email": "账号名称", "Password": "密码", "Add": "新增",
            "User (Name/Email)": "用户名称", "Role": "身份", "Action": "操作",
            "Loading users...": "加载用户名单中...",
            "Database Cleanup Rules": "数据库自动清理规则",
            "System will auto-delete records older than specified days.": "系统将自动删除超过指定天数的历史记录与照片。",
            "Keep events for:": "保留历史记录：", "Days": "天", "Save": "保存更改",
            "Danger Zone": "危险操作区域", "Clear All Data": "清空所有数据", "LOGOUT": "退出指挥中心",
            "Confirm Logout": "确认退出", "Cancel": "取消",
            "Are you sure you want to log out?": "您确定要退出系统吗？",
            "Dangerous Operation": "警告：危险操作",
            "This will permanently delete all logs and photos. Continue?": "这将永久删除数据库中所有的警报与传感器记录，确定要继续吗？",
            "Confirm Clear (Cannot be undone)": "确定清空 (无法还原)",
            "Success": "操作成功", "Failed": "操作失败", "OK": "我知道了",
            
            // 弹跳视窗的具体讯息
            "Data wiped successfully.": "🔥 数据库与影像已彻底清空！",
            "Server error or rejected.": "服务器错误或拒绝请求。",
            "User created!": "👤 新用户创建成功！",
            "Failed to create user.": "新增用户失败，请检查账号是否重复。",
            "User deleted.": "🗑️ 用户已删除",
            "Failed to delete.": "删除用户失败。",
            "Settings saved successfully.": "✅ 数据库清理规则已保存！",
            "Saved locally (Backend API pending).": "✅ 已保存至手机本地 (服务端尚未实现)。"
        ]
    ]
    static func t(_ key: String, lang: String) -> String { return dict[lang]?[key] ?? key }
}

struct AlertInfo: Identifiable { let id = UUID(); let title: String; let message: String }

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("app_language") private var appLanguage: String = "en"
    let availableLanguages = [("en", "English", "US"), ("zh-Hant", "繁體中文", "TW"), ("zh-Hans", "简体中文", "CN")]
    
    @AppStorage("local_retention_days") private var retentionDays: Int = 7
    let daysOptions = [1, 3, 7, 14, 30]
    @State private var showDaysDropdown = false
    
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var selectedRole = "USER"
    let roles = ["USER", "ADMIN"]
    @State private var showRoleDropdown = false
    
    @State private var realUsers: [SGUserProfile] = []
    
    @State private var showLogoutConfirm = false
    @State private var showClearConfirm = false
    @State private var feedbackAlert: AlertInfo?
    
    @State private var isAddingUser = false
    @State private var isSavingSettings = false
    @State private var isClearingData = false
    
    var isAdmin: Bool {
        let role = authViewModel.currentUser?.role.uppercased() ?? ""
        return role == "ADMIN" || role == "SUPER_ADMIN"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea().onTapGesture {
                    hideKeyboard()
                    withAnimation { showDaysDropdown = false; showRoleDropdown = false }
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        profileSection
                        languageSection
                        
                        if isAdmin {
                            userManagementSection
                            databaseCleanupSection
                            dangerZoneSection
                        }
                        
                        Button(action: { showLogoutConfirm = true }) {
                            Text(TR.t("LOGOUT", lang: appLanguage))
                                .font(.headline).fontWeight(.bold).foregroundColor(.gray)
                                .frame(maxWidth: .infinity).padding().background(Color.themeCard)
                                .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
                        }
                    }
                    .padding(20).padding(.bottom, 120)
                }
            }
            .navigationTitle(TR.t("Settings", lang: appLanguage))
            .onAppear {
                if isAdmin {
                    Task {
                        await fetchUsersFromDB()
                        if let days = try? await AISafeGuardAPIClient.shared.fetchCleanupSettings() { retentionDays = days }
                    }
                }
            }
            .alert(TR.t("Confirm Logout", lang: appLanguage), isPresented: $showLogoutConfirm) {
                Button(TR.t("Cancel", lang: appLanguage), role: .cancel) { }
                Button(TR.t("LOGOUT", lang: appLanguage), role: .destructive) { authViewModel.logout() }
            } message: { Text(TR.t("Are you sure you want to log out?", lang: appLanguage)) }
            
            .alert(TR.t("Dangerous Operation", lang: appLanguage), isPresented: $showClearConfirm) {
                Button(TR.t("Cancel", lang: appLanguage), role: .cancel) { }
                Button(TR.t("Confirm Clear (Cannot be undone)", lang: appLanguage), role: .destructive) {
                    Task {
                        isClearingData = true
                        do {
                            try await AISafeGuardAPIClient.shared.clearAllData()
                            feedbackAlert = AlertInfo(title: TR.t("Success", lang: appLanguage), message: TR.t("Data wiped successfully.", lang: appLanguage))
                        } catch {
                            feedbackAlert = AlertInfo(title: TR.t("Failed", lang: appLanguage), message: TR.t("Server error or rejected.", lang: appLanguage))
                        }
                        isClearingData = false
                    }
                }
            } message: { Text(TR.t("This will permanently delete all logs and photos. Continue?", lang: appLanguage)) }
            
            .alert(item: $feedbackAlert) { info in
                Alert(title: Text(info.title), message: Text(info.message), dismissButton: .default(Text(TR.t("OK", lang: appLanguage))))
            }
        }
    }
    
    private func fetchUsersFromDB() async {
        do {
            // 🌟 核心修復：明確告訴編譯器，我們要的是 [SGUserProfile] 版本的 API 回傳值！
            let users: [SGUserProfile] = try await AISafeGuardAPIClient.shared.fetchAllUsers()
            withAnimation { self.realUsers = users }
        } catch { print("🚨 抓取用戶列表失敗") }
    }
    
    // MARK: - Sections
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "person.crop.circle", title: TR.t("Profile Settings", lang: appLanguage), lang: appLanguage)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(TR.t("USERNAME", lang: appLanguage)).font(.caption).foregroundColor(.gray)
                    Text(authViewModel.currentUser?.displayName ?? "User").font(.title3).fontWeight(.bold).foregroundColor(.white)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassCardStyle()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(TR.t("ROLE PERMISSION", lang: appLanguage)).font(.caption).foregroundColor(.gray)
                    RoleBadge(role: authViewModel.currentUser?.role ?? "USER")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).glassCardStyle()
            }
        }
    }
    
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "globe", title: TR.t("Language Preference", lang: appLanguage), lang: appLanguage)
            VStack(spacing: 0) {
                ForEach(availableLanguages, id: \.0) { lang in
                    Button(action: { withAnimation { appLanguage = lang.0 } }) {
                        HStack(spacing: 16) {
                            Text(lang.2).font(.title2)
                            Text(lang.1).font(.headline).foregroundColor(appLanguage == lang.0 ? .white : .gray)
                            Spacer()
                            if appLanguage == lang.0 { Image(systemName: "checkmark.circle.fill").foregroundColor(.themeEmerald).font(.system(size: 20)) }
                        }.padding(.vertical, 16).padding(.horizontal, 20).background(appLanguage == lang.0 ? Color.themeEmerald.opacity(0.1) : Color.clear)
                    }
                    if lang.0 != availableLanguages.last?.0 { Divider().background(Color.themeBorder) }
                }
            }.background(Color.black.opacity(0.2)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
    }
    
    private var userManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "person.2.fill", title: TR.t("User Management", lang: appLanguage), lang: appLanguage)
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    CustomTextField(placeholder: TR.t("Username or Email", lang: appLanguage), text: $newUsername)
                    CustomTextField(placeholder: TR.t("Password", lang: appLanguage), text: $newPassword, isSecure: true)
                    
                    VStack(spacing: 0) {
                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showRoleDropdown.toggle(); showDaysDropdown = false } }) {
                            HStack { Text(selectedRole).foregroundColor(.white); Spacer(); Image(systemName: "chevron.down").rotationEffect(.degrees(showRoleDropdown ? -180 : 0)).foregroundColor(.gray).font(.caption) }
                            .padding(.horizontal, 12).frame(width: 90, height: 44).background(Color.themeBg).cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(showRoleDropdown ? Color.themeIndigo : Color.themeBorder, lineWidth: 1))
                        }
                        if showRoleDropdown {
                            VStack(spacing: 0) {
                                ForEach(roles, id: \.self) { role in
                                    Button(action: { selectedRole = role; withAnimation { showRoleDropdown = false } }) {
                                        Text(role).foregroundColor(.white).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    }
                                    if role != roles.last { Divider().background(Color.themeBorder) }
                                }
                            }
                            .background(Color.themeBg).cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.themeBorder, lineWidth: 1)).padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }.zIndex(2)
                    
                    Button(action: {
                        guard !newUsername.isEmpty, !newPassword.isEmpty else { return }
                        Task {
                            isAddingUser = true
                            do {
                                try await AISafeGuardAPIClient.shared.addUser(account: newUsername, role: selectedRole, password: newPassword)
                                feedbackAlert = AlertInfo(title: TR.t("Success", lang: appLanguage), message: TR.t("User created!", lang: appLanguage))
                                newUsername = ""; newPassword = ""
                                await fetchUsersFromDB()
                            } catch {
                                feedbackAlert = AlertInfo(title: TR.t("Failed", lang: appLanguage), message: TR.t("Failed to create user.", lang: appLanguage))
                            }
                            isAddingUser = false
                        }
                    }) { HStack(spacing: 4) { if isAddingUser { ProgressView().tint(.white) } else { Image(systemName: "person.badge.plus"); Text(TR.t("Add", lang: appLanguage)) } }.font(.subheadline).foregroundColor(.white).frame(width: 70, height: 44).background(Color.themeEmerald).cornerRadius(6) }.disabled(isAddingUser)
                }.padding(20)
                
                Divider().background(Color.themeBorder)
                HStack { Text(TR.t("User (Name/Email)", lang: appLanguage)).frame(maxWidth: .infinity, alignment: .leading); Text(TR.t("Role", lang: appLanguage)).frame(width: 60, alignment: .leading); Text(TR.t("Action", lang: appLanguage)).frame(width: 50, alignment: .trailing) }.font(.headline).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 20).padding(.vertical, 16)
                Divider().background(Color.themeBorder)
                
                if realUsers.isEmpty { Text(TR.t("Loading users...", lang: appLanguage)).foregroundColor(.gray).padding(30) } else {
                    LazyVStack(spacing: 0) {
                        ForEach(realUsers, id: \.id) { user in
                            HStack {
                                Text(user.displayName).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading)
                                RoleBadge(role: user.role).frame(width: 60, alignment: .leading)
                                
                                Button(action: {
                                    Task {
                                        do {
                                            try await AISafeGuardAPIClient.shared.deleteUser(id: user.id)
                                            feedbackAlert = AlertInfo(title: TR.t("Success", lang: appLanguage), message: TR.t("User deleted.", lang: appLanguage))
                                            await fetchUsersFromDB()
                                        } catch {
                                            feedbackAlert = AlertInfo(title: TR.t("Failed", lang: appLanguage), message: TR.t("Failed to delete.", lang: appLanguage))
                                        }
                                    }
                                }) { Image(systemName: "person.crop.circle.badge.minus").foregroundColor(Color.themeRose).font(.system(size: 18)) }.frame(width: 50, alignment: .trailing)
                            }.padding(.horizontal, 20).padding(.vertical, 16)
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }.background(Color.themeCard.opacity(0.8)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
        }
    }
    
    private var databaseCleanupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "cylinder.split.1x2").foregroundColor(.yellow)
                    Text(TR.t("Database Cleanup Rules", lang: appLanguage)).font(.title3).fontWeight(.bold).foregroundColor(.white)
                }
                Text(TR.t("System will auto-delete records older than specified days.", lang: appLanguage)).font(.subheadline).foregroundColor(.gray)
                
                HStack(alignment: .top, spacing: 16) {
                    Text(TR.t("Keep events for:", lang: appLanguage)).font(.subheadline).fontWeight(.bold).foregroundColor(.gray).padding(.top, 14)
                    
                    VStack(spacing: 0) {
                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showDaysDropdown.toggle(); showRoleDropdown = false } }) {
                            HStack { Text("\(retentionDays) \(TR.t("Days", lang: appLanguage))").foregroundColor(.white); Spacer(); Image(systemName: "chevron.down").rotationEffect(.degrees(showDaysDropdown ? -180 : 0)).foregroundColor(.gray).font(.caption) }
                            .padding(.horizontal, 16).frame(width: 120, height: 44).background(Color.themeBg).cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(showDaysDropdown ? Color.themeIndigo : Color.white.opacity(0.2), lineWidth: 1))
                        }
                        if showDaysDropdown {
                            VStack(spacing: 0) {
                                ForEach(daysOptions, id: \.self) { days in
                                    Button(action: { retentionDays = days; withAnimation { showDaysDropdown = false } }) {
                                        Text("\(days) \(TR.t("Days", lang: appLanguage))").foregroundColor(.white).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    }
                                    if days != daysOptions.last { Divider().background(Color.themeBorder) }
                                }
                            }
                            .background(Color.themeBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1)).padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }.zIndex(1)
                    
                    Button(action: {
                        Task {
                            isSavingSettings = true
                            do {
                                try await AISafeGuardAPIClient.shared.updateCleanupSettings(days: retentionDays)
                                feedbackAlert = AlertInfo(title: TR.t("Success", lang: appLanguage), message: TR.t("Settings saved successfully.", lang: appLanguage))
                            } catch {
                                feedbackAlert = AlertInfo(title: TR.t("Success", lang: appLanguage), message: TR.t("Saved locally (Backend API pending).", lang: appLanguage))
                            }
                            isSavingSettings = false
                        }
                    }) {
                        if isSavingSettings { ProgressView().tint(.white).frame(width: 80, height: 44) }
                        else { Text(TR.t("Save", lang: appLanguage)).fontWeight(.bold).foregroundColor(.white).frame(width: 80, height: 44).background(Color.themeBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1)) }
                    }
                }.padding(.top, 8)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color.themeCard.opacity(0.5)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
    }
    
    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield").foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                    Text(TR.t("Danger Zone", lang: appLanguage)).font(.title3).fontWeight(.bold).foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                }
                
                Button(action: { showClearConfirm = true }) {
                    HStack(spacing: 8) {
                        if isClearingData { ProgressView().tint(.white) }
                        else { Image(systemName: "trash"); Text(TR.t("Clear All Data", lang: appLanguage)) }
                    }
                    .font(.headline).fontWeight(.bold).foregroundColor(.white)
                    .padding(.vertical, 14).padding(.horizontal, 24)
                    .background(Color(red: 0.8, green: 0.3, blue: 0.3)).cornerRadius(8)
                }.disabled(isClearingData)
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color(red: 0.15, green: 0.05, blue: 0.05)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeRose.opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - UI Components
struct SectionHeader: View { let icon: String; let title: String; var color: Color = .white; let lang: String; var body: some View { HStack(spacing: 8) { Image(systemName: icon).foregroundColor(color); Text(title).font(.title3).fontWeight(.bold).foregroundColor(color) } } }
struct RoleBadge: View { let role: String; var body: some View { let isAdm = role.uppercased() == "ADMIN" || role.uppercased() == "SUPER_ADMIN"; Text(role.uppercased()).font(.caption).fontWeight(.bold).padding(.horizontal, 12).padding(.vertical, 6).background(isAdm ? Color(red: 0.3, green: 0.3, blue: 0.6) : Color.gray.opacity(0.3)).foregroundColor(isAdm ? Color(red: 0.7, green: 0.7, blue: 1.0) : .white).cornerRadius(4) } }
struct CustomTextField: View { let placeholder: String; @Binding var text: String; var isSecure: Bool = false; var body: some View { Group { if isSecure { SecureField(placeholder, text: $text) } else { TextField(placeholder, text: $text).autocapitalization(.none) } }.frame(height: 44).padding(.horizontal, 12).foregroundColor(.white).background(Color.themeBg).cornerRadius(6).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.themeBorder, lineWidth: 1)) } }
