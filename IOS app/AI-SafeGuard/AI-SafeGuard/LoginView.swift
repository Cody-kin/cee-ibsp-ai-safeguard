import SwiftUI

struct LoginView: View {
    // 🌟 接收全域的登入大腦
    @EnvironmentObject var viewModel: AuthViewModel
    
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            // 背景裝飾光暈
            Circle()
                .fill(Color.themeIndigo.opacity(0.15))
                .blur(radius: 60)
                .frame(width: 300, height: 300)
                .offset(x: -100, y: -200)
            
            VStack(spacing: 40) {
                // 頂部 Logo 與標題
                VStack(spacing: 12) {
                    // 🌟 已經修復為系統正確的圖示名稱
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.themeEmerald)
                    
                    Text("AI-SafeGuard")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Secure Edge-AI Monitoring")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 40)
                
                // 登入卡片
                VStack(spacing: 20) {
                    // 帳號欄位
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(.gray)
                        TextField("Username / Email", text: $viewModel.username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.themeBg).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
                    
                    // 🔐 密碼欄位 (含小眼睛)
                    HStack {
                        Image(systemName: "lock.fill").foregroundColor(.gray)
                        
                        if isPasswordVisible {
                            TextField("Password", text: $viewModel.password)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .foregroundColor(.white)
                        } else {
                            SecureField("Password", text: $viewModel.password)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .foregroundColor(.white)
                        }
                        
                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                .foregroundColor(.gray)
                                .animation(.easeInOut, value: isPasswordVisible)
                        }
                    }
                    .padding()
                    .background(Color.themeBg).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeBorder, lineWidth: 1))
                    
                    // 錯誤訊息顯示
                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundColor(.themeRose)
                            .font(.caption)
                    }
                    
                    // 登入按鈕
                    Button(action: {
                        Task {
                            isLoading = true
                            await viewModel.loadUserIdentity()
                            isLoading = false
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("INITIALIZE CONNECTION")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                            }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.themeIndigo).foregroundColor(.white).cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
                .padding(24).glassCardStyle().padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        // 🌟 移除了會造成閃爍的 fullScreenCover，現在由 RootView 統一調度畫面！
    }
}
