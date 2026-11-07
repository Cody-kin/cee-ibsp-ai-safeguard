import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @StateObject private var notifManager = NotificationManager.shared
    @AppStorage("app_language") private var appLanguage: String = "en"
    
    @State private var showCalibration = false
    @State private var calibrationInput = ""
    @State private var showTodayTimeline = false
    @State private var selectedAlertEvent: SGEventObject?
    
    var isSystemTotallyOffline: Bool { !viewModel.isNanoOnline && !viewModel.isLoraOnline }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea().onTapGesture { hideKeyboard() }
                Circle().fill(Color.themeIndigo.opacity(0.15)).blur(radius: 100).frame(width: 350, height: 350).offset(x: -100, y: -150)
                
                ScrollView {
                    VStack(spacing: 24) {
                        aiAutomatedAnalysisCard
                        edgeNodesStatusRow
                        environmentSafetyCard
                        
                        HStack(spacing: 16) {
                            StatusMiniCard(title: dashboardText("Active Events", "活躍事件", "活跃事件"), value: "\(viewModel.totalEventsCount)", color: .white)
                            let sysState = isSystemTotallyOffline ? "OFFLINE" : viewModel.overallSystemState
                            let sysColor: Color = isSystemTotallyOffline ? .gray : (sysState == "SAFE" ? .themeEmerald : (sysState == "CRITICAL" ? .themeRose : .orange))
                            StatusMiniCard(title: dashboardText("Site Environment", "場域環境", "现场环境"), value: localizedState(sysState), color: sysColor)
                        }
                        
                        // 🌟 動態渲染授權的直播鏡頭 (完全修復！)
                        if !viewModel.availableCameras.isEmpty {
                            VStack(spacing: 16) {
                                ForEach(viewModel.availableCameras) { camera in
                                    // 就算 stream_url 是空的 (nil)，也強迫它用 "" 生成，然後自己顯示 SIGNAL LOST！
                                    SnapshotCameraView(
                                        cameraName: camera.id.replacingOccurrences(of: "NANO-001_", with: "CAM: ").uppercased(),
                                        streamUrl: camera.stream_url ?? ""
                                    )
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "eye.slash.fill").font(.largeTitle).foregroundColor(.gray)
                                Text(dashboardText("No Authorized Cameras Available", "目前沒有授權影像源", "目前没有授权影像源")).font(.subheadline).foregroundColor(.gray)
                            }.frame(height: 150).frame(maxWidth: .infinity).glassCardStyle()
                        }
                        
                        telemetrySection
                        
                        Button(action: { showTodayTimeline = true }) {
                            HStack { Image(systemName: "clock.arrow.circlepath"); Text(dashboardText("TODAY'S AUDIT TIMELINE", "今日稽核時間線", "今日审计时间线")); Spacer(); Image(systemName: "chevron.right") }
                            .font(.headline).fontWeight(.black).foregroundColor(.white).padding(20).glassCardStyle()
                        }
                    }
                    .padding(16).padding(.bottom, 120)
                }
                .refreshable {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    await viewModel.manualRefresh()
                }
                .safeAreaInset(edge: .top) { LiquidGlassNavigationBar(title: dashboardText("Command Center", "指揮中心", "指挥中心")) }
                
                if showCalibration { calibrationModal }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showTodayTimeline) { TodayTimelineSheet().presentationDetents([.fraction(0.85), .large]).presentationDragIndicator(.visible) }
            .onChange(of: notifManager.tappedEventId) { oldValue, eventId in
                if let id = eventId, let foundEvent = viewModel.events.first(where: { $0.id == id }) { selectedAlertEvent = foundEvent }
            }
            .sheet(item: $selectedAlertEvent) { event in DangerAlertDetailView(event: event) }
        }
    }
    
    private var edgeNodesStatusRow: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack { Circle().fill(viewModel.isNanoOnline ? Color.themeEmerald.opacity(0.2) : Color.themeRose.opacity(0.2)).frame(width: 40, height: 40); Image(systemName: "camera.viewfinder").foregroundColor(viewModel.isNanoOnline ? .themeEmerald : .themeRose) }
                VStack(alignment: .leading, spacing: 4) { Text(dashboardText("Nano Vision", "Nano 視覺", "Nano 视觉")).font(.caption).fontWeight(.bold).foregroundColor(.gray); Text(localizedOnline(viewModel.isNanoOnline)).font(.subheadline).fontWeight(.black).foregroundColor(viewModel.isNanoOnline ? .themeEmerald : .themeRose) }
                Spacer()
            }.padding(16).glassCardStyle()
            
            HStack(spacing: 12) {
                ZStack { Circle().fill(viewModel.isLoraOnline ? Color.themeEmerald.opacity(0.2) : Color.themeRose.opacity(0.2)).frame(width: 40, height: 40); Image(systemName: "antenna.radiowaves.left.and.right").foregroundColor(viewModel.isLoraOnline ? .themeEmerald : .themeRose) }
                VStack(alignment: .leading, spacing: 4) { Text(dashboardText("LoRa Sensor", "LoRa 感測", "LoRa 传感")).font(.caption).fontWeight(.bold).foregroundColor(.gray); Text(localizedOnline(viewModel.isLoraOnline)).font(.subheadline).fontWeight(.black).foregroundColor(viewModel.isLoraOnline ? .themeEmerald : .themeRose) }
                Spacer()
            }.padding(16).glassCardStyle()
        }
    }
    
    private var aiAutomatedAnalysisCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cpu.fill").foregroundColor(.themeIndigo)
                Text(dashboardText("Local AI Automated Analysis", "本地 AI 自動分析", "本地 AI 自动分析")).font(.headline).foregroundColor(.white)
                Spacer()
                Button(action: { Task { await viewModel.manualRefresh() } }) { Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(viewModel.isAnalyzing ? .gray : .themeEmerald) }.disabled(viewModel.isAnalyzing)
            }
            Text(viewModel.localAIReport(language: appLanguage))
                .font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundColor(isSystemTotallyOffline ? .themeRose : (viewModel.isManuallyAcknowledged ? .themeEmerald : .gray)).lineSpacing(6).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color.black.opacity(0.3)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(viewModel.isManuallyAcknowledged ? Color.themeEmerald.opacity(0.3) : Color.white.opacity(0.05), lineWidth: 1))
        }.padding(20).glassCardStyle().shadow(color: Color.themeIndigo.opacity(0.15), radius: 20, y: 10)
    }
    
    private var environmentSafetyCard: some View {
        let state = viewModel.overallSystemState
        let isOverridden = viewModel.isManuallyAcknowledged
        var stateColor: Color = .themeEmerald; var stateIcon = "shield.checkmark.fill"; var stateTitle = localizedState("SAFE"); var stateDesc = dashboardText("All edge nodes are operating inside normal thresholds.", "所有邊緣節點均在正常閾值內運作。", "所有边缘节点均在正常阈值内运行。")
        
        if isSystemTotallyOffline { stateColor = .gray; stateIcon = "network.slash"; stateTitle = dashboardText("SYSTEM OFFLINE", "系統離線", "系统离线"); stateDesc = dashboardText("All edge node links are unavailable.", "所有邊緣節點連線遺失，系統全盲暫停運作。", "所有边缘节点连接丢失，系统全盲暂停运行。")
        } else if isOverridden { stateColor = .themeEmerald; stateIcon = "shield.lefthalf.filled"; stateTitle = dashboardText("MANUALLY SECURED", "人工確認安全", "人工确认安全"); stateDesc = dashboardText("Alerts were manually cleared; monitoring continues.", "現場指揮官已確認安全並強制解除警報，雷達持續警戒中。", "现场指挥员已确认安全并强制解除警报，监控持续警戒中。")
        } else if state == "CRITICAL" { stateColor = .themeRose; stateIcon = "bolt.shield.fill"; stateTitle = dashboardText("CRITICAL WARNING", "危急警報", "危急警报"); stateDesc = dashboardText("Critical risk detected. Check live video and sensors immediately.", "偵測到極度危險！請立刻檢視畫面與感測器數據！", "检测到高度危险！请立刻查看画面与传感器数据！")
        } else if state == "WARNING" { stateColor = .orange; stateIcon = "exclamationmark.shield.fill"; stateTitle = dashboardText("POTENTIAL RISK", "潛在風險", "潜在风险"); stateDesc = dashboardText("Environmental signals are abnormal. Keep watching.", "環境出現異常波動，請持續關注。", "环境出现异常波动，请持续关注。") }
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ZStack { Circle().fill(stateColor.opacity(0.2)).frame(width: 56, height: 56); Image(systemName: stateIcon).font(.system(size: 28)).foregroundColor(stateColor) }
                VStack(alignment: .leading, spacing: 4) { Text(dashboardText("ENVIRONMENT STATUS", "環境狀態", "环境状态")).font(.caption).fontWeight(.bold).foregroundColor(.gray); Text(stateTitle).font(.title2).fontWeight(.black).foregroundColor(.white); Text(stateDesc).font(.caption2).foregroundColor(isOverridden ? .themeEmerald : .gray).fixedSize(horizontal: false, vertical: true) }
                Spacer()
            }
            if state != "SAFE" && !isSystemTotallyOffline && !isOverridden {
                Button(action: { let impact = UIImpactFeedbackGenerator(style: .heavy); impact.impactOccurred(); viewModel.acknowledgeWarning() }) {
                    HStack { Image(systemName: "checkmark.seal.fill"); Text(dashboardText("MARK AS SAFE", "強制確認安全", "强制确认安全")) }.font(.subheadline).fontWeight(.bold).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.themeEmerald.opacity(0.8)).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.themeEmerald, lineWidth: 1))
                }
            }
        }.padding(20).background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(stateColor.opacity(0.4), lineWidth: state == "SAFE" || isOverridden ? 1 : 2)).shadow(color: state == "SAFE" || isOverridden ? .clear : stateColor.opacity(0.2), radius: 15, y: 5)
    }
    
    private var telemetrySection: some View {
        let isSensorOffline = !viewModel.hasSensorTelemetry
        return VStack(alignment: .leading, spacing: 20) {
            HStack { Image(systemName: "sensor.tag.radiowaves.forward").foregroundColor(isSensorOffline ? .gray : .themeIndigo); Text(dashboardText("Sensor Telemetry", "感測器遙測", "传感器遥测")).font(.headline).foregroundColor(isSensorOffline ? .gray : .white); Spacer(); Text(isSensorOffline ? dashboardText("NO DATA", "無資料", "无数据") : dashboardText("SECURE", "穩定", "稳定")).font(.caption).fontWeight(.bold).padding(.horizontal, 8).padding(.vertical, 4).background(isSensorOffline ? Color.themeRose.opacity(0.2) : Color.themeEmerald.opacity(0.2)).foregroundColor(isSensorOffline ? .themeRose : .themeEmerald).cornerRadius(6) }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("MQ2").font(.subheadline).foregroundColor(.gray); Spacer(); Button(action: { calibrationInput = "\(viewModel.mq2Baseline)"; showCalibration = true }) { Image(systemName: "slider.horizontal.3").foregroundColor(isSensorOffline ? .gray : .white) }.disabled(isSensorOffline) }
                    if isSensorOffline { Text("--").font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(.gray).padding(.vertical, 4) } else { HStack(alignment: .firstTextBaseline, spacing: 4) { Text("\(viewModel.displayMq2Value)").font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(.white).contentTransition(.numericText()); Text("ppm").font(.caption).foregroundColor(.gray) } }
                    Text(isSensorOffline ? "--" : (viewModel.displayMq2Value < 400 ? dashboardText("NORMAL", "正常", "正常") : dashboardText("ALERT", "警報", "警报"))).font(.caption2).foregroundColor(isSensorOffline ? .gray : (viewModel.displayMq2Value < 400 ? .themeEmerald : .themeRose))
                }.padding(16).background(Color.black.opacity(0.2)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("MQ3").font(.subheadline).foregroundColor(.gray); Spacer() }
                    if isSensorOffline { Text("--").font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(.gray).padding(.vertical, 4) } else { HStack(alignment: .firstTextBaseline, spacing: 4) { Text(viewModel.mq3Value).font(.system(size: 32, weight: .black, design: .rounded)).foregroundColor(.white).contentTransition(.numericText()); Text("mg/L").font(.caption).foregroundColor(.gray) } }
                    Text(isSensorOffline ? "--" : ((Int(viewModel.mq3Value) ?? 0) > 200 ? dashboardText("DANGER", "危險", "危险") : dashboardText("NORMAL", "正常", "正常"))).font(.caption2).foregroundColor(isSensorOffline ? .gray : ((Int(viewModel.mq3Value) ?? 0) > 200 ? .themeRose : .themeEmerald))
                }.padding(16).background(Color.black.opacity(0.2)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
            }
        }.padding(20).glassCardStyle()
    }
    
    private var calibrationModal: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { hideKeyboard() }
            VStack(alignment: .leading, spacing: 20) {
                HStack { Text(dashboardText("Sensor Calibration", "感測器校準", "传感器校准")).font(.title3).fontWeight(.bold).foregroundColor(.white); Spacer(); Button(action: { showCalibration = false }) { Image(systemName: "xmark").foregroundColor(.gray) } }
                Text(dashboardText("Set a baseline to filter out background noise from the sensor.", "設定基準值以濾除感測器背景雜訊。", "设置基准值以过滤传感器背景噪声。")).font(.subheadline).foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 8) { Text(dashboardText("CURRENT BASELINE (PPM)", "目前基準值 (PPM)", "当前基准值 (PPM)")).font(.caption).fontWeight(.bold).foregroundColor(.gray); TextField("0", text: $calibrationInput).keyboardType(.numberPad).foregroundColor(.white).padding().background(Color.themeBg).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.themeBorder, lineWidth: 1)) }
                HStack(spacing: 16) { Spacer(); Button(dashboardText("Cancel", "取消", "取消")) { hideKeyboard(); showCalibration = false }.foregroundColor(.gray).fontWeight(.bold); Button(dashboardText("Save", "儲存", "保存")) { hideKeyboard(); if let newVal = Int(calibrationInput) { viewModel.mq2Baseline = newVal }; showCalibration = false }.foregroundColor(.white).fontWeight(.bold).padding(.vertical, 10).padding(.horizontal, 24).background(Color.themeIndigo).cornerRadius(8) }.padding(.top, 8)
            }.padding(24).background(Color.themeCard).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeBorder, lineWidth: 1)).padding(.horizontal, 32).shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        }.zIndex(100)
    }

    private func dashboardText(_ en: String, _ zhHant: String, _ zhHans: String) -> String {
        switch appLanguage {
        case "zh-Hant": return zhHant
        case "zh-Hans": return zhHans
        default: return en
        }
    }

    private func localizedOnline(_ isOnline: Bool) -> String {
        if isOnline { return dashboardText("ONLINE", "連線中", "在线") }
        return dashboardText("OFFLINE", "離線", "离线")
    }

    private func localizedState(_ state: String) -> String {
        switch state {
        case "SAFE": return dashboardText("SAFE", "安全", "安全")
        case "WARNING": return dashboardText("WARNING", "警告", "警告")
        case "CRITICAL": return dashboardText("CRITICAL", "危急", "危急")
        case "OFFLINE": return dashboardText("OFFLINE", "離線", "离线")
        default: return state
        }
    }
}

struct DangerAlertDetailView: View {
    let event: SGEventObject; @Environment(\.dismiss) var dismiss
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 80)).foregroundColor(.themeRose).padding(.top, 40)
                Text("CRITICAL INCIDENT").font(.title).fontWeight(.black).foregroundColor(.white)
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Text("TIME:").font(.caption).foregroundColor(.gray); Text(event.localTimeString).font(.subheadline).foregroundColor(.white) }
                    HStack { Text("TYPE:").font(.caption).foregroundColor(.gray); Text(event.event_name).font(.headline).foregroundColor(.themeRose) }
                    Divider().background(Color.white.opacity(0.2))
                    Text(event.description).font(.body).foregroundColor(.white).lineSpacing(6)
                }.padding(24).background(Color.themeCard).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeRose.opacity(0.5), lineWidth: 2)).padding(.horizontal, 20)
                Spacer()
                Button(action: { dismiss() }) { Text("Acknowledge & Dismiss").font(.headline).fontWeight(.bold).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.themeIndigo).cornerRadius(12).padding(.horizontal, 20).padding(.bottom, 30) }
            }
        }.preferredColorScheme(.dark)
    }
}

struct LiquidGlassNavigationBar: View {
    let title: String
    var body: some View {
        HStack { Text(title).font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7), .white.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)); Spacer(); Image(systemName: "wifi").font(.system(size: 18, weight: .bold)).foregroundColor(.themeIndigo).frame(width: 40, height: 40).background(Color.white.opacity(0.05)).clipShape(Circle()).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)) }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 16).background(ZStack { Rectangle().fill(.ultraThinMaterial); VStack { Spacer(); LinearGradient(colors: [.clear, Color.themeIndigo.opacity(0.4), .themeEmerald.opacity(0.2), .clear], startPoint: .leading, endPoint: .trailing).frame(height: 1) } }.ignoresSafeArea(edges: .top))
    }
}

struct StatusMiniCard: View {
    let title: String; let value: String; let color: Color
    var body: some View { VStack(alignment: .leading, spacing: 8) { Text(title).font(.caption).foregroundColor(.gray); Text(value).font(.title2).fontWeight(.black).foregroundColor(color) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).glassCardStyle() }
}

struct TodayTimelineSheet: View {
    @EnvironmentObject var viewModel: DashboardViewModel; @State private var selectedFilter = "All"
    let filters = ["All", "Critical", "High", "Info"]
    var todayEvents: [SGEventObject] { return viewModel.events.filter { event in guard Calendar.current.isDateInToday(event.parsedDate) else { return false }; if selectedFilter != "All" { return event.severity.lowercased() == selectedFilter.lowercased() }; return true } }
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea(); Color.themeCard.opacity(0.5).background(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) { Text("TODAY'S AUDIT TIMELINE").font(.title2).fontWeight(.black).foregroundColor(.white).padding(.horizontal, 20).padding(.top, 30); ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(filters, id: \.self) { filter in FilterChip(title: filter, isSelected: selectedFilter == filter) { withAnimation { selectedFilter = filter } } } }.padding(.horizontal, 20).padding(.bottom, 16) } }.background(Color.themeBg.opacity(0.8))
                if todayEvents.isEmpty { Spacer(); Image(systemName: "checkmark.shield.fill").font(.system(size: 40)).foregroundColor(.themeEmerald).padding(.bottom, 8); Text("今日尚無符合的日誌").foregroundColor(.gray); Spacer()
                } else { ScrollView { LazyVStack(spacing: 16) { ForEach(todayEvents) { event in SGEventCardMini(event: event) } }.padding(20) } }
            }
        }.preferredColorScheme(.dark)
    }
}

struct SGEventCardMini: View {
    let event: SGEventObject
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Circle().fill(event.severity == "critical" ? Color.themeRose : (event.severity == "warning" ? Color.orange : Color.themeEmerald)).frame(width: 8, height: 8); Text(event.event_name).font(.headline).foregroundColor(.white); Spacer(); Text(event.localTimeString).font(.caption).foregroundColor(.gray) }
            Text(event.description).font(.subheadline).foregroundColor(.gray)
            if let device = event.device_id { Text(device).font(.caption2).foregroundColor(.themeIndigo).padding(.top, 4) }
        }.padding(16).background(Color.black.opacity(0.3)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}
