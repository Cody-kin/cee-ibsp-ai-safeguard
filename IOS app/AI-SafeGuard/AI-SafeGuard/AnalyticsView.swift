import SwiftUI
import WebKit

// MARK: - 資料模型
struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let role: String
    let text: String
}

struct SensorDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let mq2: Int
    let mq3: Int
}

struct ThreatDataPoint: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
}

// MARK: - 業務邏輯與狀態管理 (保留給 AI 助手讀取上下文)
@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var threatData: [ThreatDataPoint] = []
    @Published var chatHistory: [ChatMessage] = []
    @Published var chatInput: String = ""
    @Published var isAiTyping: Bool = false
    
    init() { loadChatHistory() }
    
    func loadData() async {
        do {
            let events = try await AISafeGuardAPIClient.shared.fetchEvents()
            processThreatData(events: events)
        } catch { print("🚨 獲取分析數據失敗") }
    }
    
    private func processThreatData(events: [SGEventObject]) {
        let threats = events.filter { $0.severity == "critical" || $0.severity == "high" || $0.event_type == "ai_vision" || $0.event_type == "voice_sos" }
        var map: [String: (count: Int, severity: String)] = [:]
        for e in threats {
            if map[e.event_name] != nil { map[e.event_name]!.count += 1 }
            else { map[e.event_name] = (count: 1, severity: e.severity) }
        }
        self.threatData = map.map { key, val in
            ThreatDataPoint(name: key, count: val.count, color: val.severity == "critical" ? Color(red: 239/255, green: 68/255, blue: 68/255) : Color(red: 245/255, green: 158/255, blue: 11/255))
        }.sorted(by: { $0.count > $1.count })
    }
    
    // MARK: - AI 聊天室邏輯
    private func loadChatHistory() {
        if let data = UserDefaults.standard.data(forKey: "aegis_ai_chat"),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) { self.chatHistory = saved }
        else { self.chatHistory = [ChatMessage(role: "ai", text: "你好，我是 AI-SafeGuard 戰術助手。所有邊緣節點已同步。今天需要什麼威脅情報協助？")] }
    }
    
    private func saveChatHistory() {
        if let data = try? JSONEncoder().encode(chatHistory) { UserDefaults.standard.set(data, forKey: "aegis_ai_chat") }
    }
    
    func clearChat() {
        self.chatHistory = [ChatMessage(role: "ai", text: "你好，我是 AI-SafeGuard 戰術助手。所有邊緣節點已同步。今天需要什麼威脅情報協助？")]
        saveChatHistory()
    }
    
    func sendMessage(isReportRequest: Bool = false) async {
        let userText = isReportRequest ? "生成綜合安全報告。" : chatInput
        if userText.trimmingCharacters(in: .whitespaces).isEmpty { return }
        if !isReportRequest { chatInput = "" }
        chatHistory.append(ChatMessage(role: "user", text: userText))
        isAiTyping = true
        
        var apiMessages: [[String: String]] = []
        let sysMsg = isReportRequest
            ? "你是一個安全 AI。請根據提供的數據生成極簡的中文安全報告。使用條列式，最多 50 字。"
            : "你是 AI-SafeGuard 戰術助手。請用簡潔、專業的中文回答安全問題。"
        apiMessages.append(["role": "system", "content": sysMsg])
        
        for msg in chatHistory.suffix(6) {
            apiMessages.append(["role": msg.role == "ai" ? "assistant" : "user", "content": msg.text])
        }
        
        if isReportRequest {
            let stateContext = "這是目前系統狀態。活躍威脅數量：\(threatData.reduce(0) { $0 + $1.count })。MQ2/MQ3 感測器運作中。請總結狀態。"
            apiMessages[apiMessages.count - 1] = ["role": "user", "content": stateContext]
        }
        
        do {
            let response = try await AISafeGuardAPIClient.shared.callAIProxy(messages: apiMessages)
            chatHistory.append(ChatMessage(role: "ai", text: isReportRequest ? "[報告已生成]\n\(response)" : response))
        } catch {
            chatHistory.append(ChatMessage(role: "ai", text: "連線失敗：無法連接 AI 分析引擎。請檢查網路或代理伺服器。"))
        }
        isAiTyping = false
        saveChatHistory()
    }
}

// MARK: - 🌟 外科手術式 WebView 2.0 (全面隱藏 + 絕對凍結)
struct ReactChartsWebView: UIViewRepresentable {
    let url: URL
    let token: String
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // 1. 注入 Token
        let tokenScript = WKUserScript(source: "localStorage.setItem('token', '\(token)');", injectionTime: .atDocumentStart, forMainFrameOnly: false)
        userContentController.addUserScript(tokenScript)
        
        // 2. 🌟 終極隱形剪刀：剪掉 Logo、導航列、並凍結網頁！
        let cssScriptString = """
        var style = document.createElement('style');
        style.innerHTML = `
            /* 🔪 剪掉外層的 Logo 標誌與右側漢堡導航按鈕 */
            nav, header, [role="navigation"], .sticky, .fixed, .z-50 { display: none !important; }
            
            /* 🔪 剪掉頁面內的標題與 AI 聊天室 */
            .max-w-\\\\[1600px\\\\] > div:nth-child(1) { display: none !important; }
            .max-w-\\\\[1600px\\\\] > div:nth-child(3) { display: none !important; }
            
            /* 🧊 絕對凍結術：禁止網頁上下滾動、移除背景色、消除多餘邊距 */
            body, html { 
                overflow: hidden !important; 
                overscroll-behavior: none !important; 
                background: transparent !important; 
                margin: 0 !important;
                padding: 0 !important;
            }
            
            /* 移除內圍容器的留白，讓圖表徹底撐滿 iOS 卡片 */
            .p-8 { padding: 0 !important; }
        `;
        document.head.appendChild(style);
        """
        let cssScript = WKUserScript(source: cssScriptString, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        userContentController.addUserScript(cssScript)
        
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // 🌟 物理凍結術：在 iOS 原生層級徹底禁用滾動與邊緣回彈！
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        // 讓 WebView 徹底透明，完美融入深色 UI
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}

// MARK: - 主視圖
struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @AppStorage("app_language") private var appLanguage: String = "en"
    @AppStorage("aisafeguard_access_token") private var token: String = ""
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    // 🎨 色碼
    let colorCardBg = Color(red: 19/255, green: 27/255, blue: 44/255)
    let colorChartBg = Color(red: 11/255, green: 15/255, blue: 25/255)
    let colorBorder = Color(red: 30/255, green: 41/255, blue: 59/255)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 15/255, green: 23/255, blue: 42/255).ignoresSafeArea().onTapGesture { hideKeyboard() }
                
                // 外層是我們 iOS 原生的 ScrollView，確保能順暢往下滑看 AI 助手
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        headerSection
                        
                        // 🌟 手術嵌合區：完美載入 React 圖表 (鎖死高度，內部絕對不會滾動)
                        if !token.isEmpty {
                            ReactChartsWebView(url: URL(string: "http://127.0.0.1/analytics")!, token: token)
                                .frame(height: 1020) // 給兩個圖表剛剛好的空間
                                .cornerRadius(24)
                        } else {
                            ProgressView().frame(height: 1020)
                        }
                        
                        // 🌟 原生的 AI 助手 (保留在底部)
                        aiCopilotCard
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(appLanguage == "en" ? "Data Analytics" : "數據分析")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await viewModel.loadData() } }
            .onReceive(timer) { _ in Task { await viewModel.loadData() } }
        }
    }
    
    // MARK: - 原生 Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "chart.xyaxis.line").font(.title).foregroundColor(Color(red: 129/255, green: 140/255, blue: 248/255))
                    Text(appLanguage == "en" ? "Analytics & Threats" : "數據分析與威脅情報")
                        .font(.title2).fontWeight(.black).foregroundColor(.white)
                }
                Text(appLanguage == "en" ? "Real-time telemetry & AI Copilot" : "即時遙測與 AI 戰術助手")
                    .font(.subheadline).foregroundColor(.gray)
            }
            Spacer()
            HStack {
                Circle().fill(Color(red: 16/255, green: 185/255, blue: 129/255)).frame(width: 8, height: 8).opacity(0.8)
                Text("LIVE").font(.caption).fontWeight(.bold).foregroundColor(Color(red: 16/255, green: 185/255, blue: 129/255))
            }.padding(.horizontal, 10).padding(.vertical, 6).background(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.1)).cornerRadius(20)
        }
    }
    
    // MARK: - 原生 AI Copilot
    private var aiCopilotCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles").foregroundColor(Color(red: 129/255, green: 140/255, blue: 248/255))
                Text(appLanguage == "en" ? "AI Tactical Assistant" : "AI 戰術助手").font(.headline).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Button(action: { viewModel.clearChat() }) { Image(systemName: "trash").foregroundColor(.gray) }
                Button(action: { Task { await viewModel.sendMessage(isReportRequest: true) } }) {
                    Text(appLanguage == "en" ? "Report" : "一鍵報告").font(.caption).fontWeight(.bold).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(red: 79/255, green: 70/255, blue: 229/255)).foregroundColor(.white).cornerRadius(6)
                }.disabled(viewModel.isAiTyping)
            }.padding(16).background(Color.black.opacity(0.3))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.chatHistory) { msg in
                            HStack(alignment: .top) {
                                if msg.role == "user" { Spacer() }
                                if msg.role == "ai" { Image(systemName: "brain.circuit").foregroundColor(Color(red: 129/255, green: 140/255, blue: 248/255)).padding(.top, 4) }
                                Text(msg.text).font(.subheadline).padding(14).foregroundColor(.white)
                                    .background(msg.role == "user" ? Color(red: 79/255, green: 70/255, blue: 229/255) : colorBorder)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                if msg.role == "ai" { Spacer() }
                            }.id(msg.id)
                        }
                        if viewModel.isAiTyping {
                            HStack {
                                ProgressView().tint(Color(red: 129/255, green: 140/255, blue: 248/255)).padding(.trailing, 4)
                                Text(appLanguage == "en" ? "AI is thinking..." : "AI 正在思考...").font(.subheadline).italic().foregroundColor(.gray)
                                Spacer()
                            }.padding(14).background(colorBorder).cornerRadius(16).id("typing")
                        }
                    }.padding(16)
                }
                .onChange(of: viewModel.chatHistory.count) { _ in withAnimation { proxy.scrollTo(viewModel.chatHistory.last?.id, anchor: .bottom) } }
                .onChange(of: viewModel.isAiTyping) { typing in if typing { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } } }
            }.frame(height: 350)
            
            HStack(spacing: 12) {
                TextField(appLanguage == "en" ? "Type a command..." : "輸入指令...", text: $viewModel.chatInput)
                    .padding(14).background(colorChartBg).cornerRadius(12).foregroundColor(.white)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(colorBorder, lineWidth: 1))
                    .disabled(viewModel.isAiTyping)
                Button(action: { Task { await viewModel.sendMessage() } }) {
                    Image(systemName: "paperplane.fill").foregroundColor(.white).padding(14).background(Color(red: 79/255, green: 70/255, blue: 229/255)).cornerRadius(12)
                }.disabled(viewModel.isAiTyping || viewModel.chatInput.isEmpty)
            }.padding(16).background(Color.black.opacity(0.3))
        }
        .background(colorCardBg).cornerRadius(24)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
