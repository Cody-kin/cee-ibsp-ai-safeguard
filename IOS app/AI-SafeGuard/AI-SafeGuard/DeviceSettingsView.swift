import SwiftUI

struct DeviceSettingsView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var devices: [SGDeviceNode] = []
    @State private var allUsers: [String] = []
    @State private var isLoading = true
    
    @State private var showNanoConsole = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                Circle().fill(Color.themeIndigo.opacity(0.15)).blur(radius: 120).frame(width: 400, height: 400).offset(x: 150, y: -200)
                Circle().fill(Color.themeEmerald.opacity(0.1)).blur(radius: 120).frame(width: 300, height: 300).offset(x: -150, y: 300)
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(.themeEmerald).scaleEffect(1.5)
                        Text("CONNECTING SECURE NODES...").font(.caption).fontWeight(.black).foregroundColor(.themeEmerald).tracking(2)
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            hostStatusSection
                            
                            ForEach($devices) { $node in
                                if node.type == "camera" {
                                    let isAdmin = viewModel.currentUser?.role == "admin" || viewModel.currentUser?.role == "super_admin"
                                    let isAssigned = node.config?.assignees.contains(viewModel.currentUser?.username ?? "") ?? false
                                    
                                    if isAdmin || isAssigned {
                                        CameraConfigCard(
                                            camera: $node,
                                            isAdmin: isAdmin,
                                            allUsers: allUsers,
                                            onSave: { updatedConfig in saveConfig(cameraId: node.id, config: updatedConfig) }
                                        )
                                    }
                                }
                            }
                            
                            if !devices.contains(where: { $0.type == "camera" && ((viewModel.currentUser?.role == "admin" || viewModel.currentUser?.role == "super_admin") || ($0.config?.assignees.contains(viewModel.currentUser?.username ?? "") ?? false)) }) {
                                VStack(spacing: 16) {
                                    Image(systemName: "eye.slash.fill").font(.system(size: 50)).foregroundColor(.gray.opacity(0.5))
                                    Text("NO AUTHORIZED NODES").font(.headline).fontWeight(.black).foregroundColor(.gray).tracking(2)
                                }.frame(height: 180).frame(maxWidth: .infinity).glassCardStyle()
                            }
                            
                        }.padding(20).padding(.bottom, 80)
                    }.refreshable { await loadData() }
                }
            }
            .navigationTitle("Device Matrix")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { Task { await loadData() } }
            .sheet(isPresented: $showNanoConsole) {
                NanoConsoleView()
                    .presentationDetents([.fraction(0.85), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color.black.opacity(0.9))
            }
        }
    }
    
    private var hostStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CORE INFRASTRUCTURE").font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(1.5)
            HStack(spacing: 16) {
                let nano = devices.first(where: { $0.id == "NANO-001" })
                let lora = devices.first(where: { $0.id == "LORA-001" || $0.id == "DEV-LORA-001" || $0.type == "gateway" })
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    showNanoConsole = true
                }) {
                    HostMiniCard(title: "NANO AI Node", isOnline: nano?.status == "online", icon: "brain.head.profile", isInteractive: true)
                }.buttonStyle(PlainButtonStyle())
                
                NavigationLink(destination: LoraGatewayDetailView(loraDevice: lora)) {
                    HostMiniCard(title: "LoRa Gateway", isOnline: viewModel.isLoraOnline, icon: "antenna.radiowaves.left.and.right", isInteractive: true)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // 🌟 只有 Admin 才看得到的 OTA 進入點
            if viewModel.currentUser?.role.lowercased() == "admin" || viewModel.currentUser?.role.lowercased() == "super_admin" {
                NavigationLink(destination: OTAManagementView()) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill").font(.title3)
                        Text("OTA FIRMWARE MANAGEMENT").font(.subheadline).fontWeight(.black).tracking(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.themeEmerald)
                    .padding(16)
                    .background(Color.themeEmerald.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeEmerald.opacity(0.3), lineWidth: 1))
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func loadData() async {
        do {
            async let fetchDev = AISafeGuardAPIClient.shared.fetchDevices()
            async let fetchUsr: [String] = AISafeGuardAPIClient.shared.fetchAssignableUsernames()
            let (devs, usrs) = try await (fetchDev, fetchUsr)
            
            let safeDevs = devs.map { node -> SGDeviceNode in
                var n = node
                if n.type == "camera" && n.config == nil { n.config = SGCameraConfig(fire: 0, smoke: 0, fall: 0, hardhat: 0, vest: 0, smoking: 0, phone: 0, assignees: []) }
                return n
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { self.devices = safeDevs; self.allUsers = usrs; self.isLoading = false }
        } catch {
            print("🚨 獲取設備資料失敗")
            withAnimation { isLoading = false }
        }
    }
    
    private func saveConfig(cameraId: String, config: SGCameraConfig) {
        Task { do { try await AISafeGuardAPIClient.shared.updateCameraConfig(cameraId: cameraId, config: config) } catch { print("🚨 更新失敗") } }
    }
}

struct LoraGatewayDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.openURL) private var openURL
    let loraDevice: SGDeviceNode?
    
    @State private var latest: SGLoraLatestResponse?
    @State private var isLoading = true
    @State private var isSending = false
    @State private var downlinkText = "SYS|START"
    @State private var statusMessage: String?
    
    private var effectiveLatest: SGLoraLatestResponse? { latest ?? viewModel.loraLatest }
    private var isOnline: Bool { viewModel.isLoraOnline || loraDevice?.status == "online" }
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    gatewayHeader
                    telemetrySection
                    downlinkSection
                    chirpStackSection
                }
                .padding(20)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("LoRa Gateway")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshLatest() }
        .refreshable { await refreshLatest() }
    }
    
    private var gatewayHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Color.themeEmerald.opacity(0.16)).frame(width: 52, height: 52)
                    Image(systemName: "antenna.radiowaves.left.and.right").font(.title2).foregroundColor(.themeEmerald)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(loraDevice?.name ?? "LoRa 緊急通訊網關").font(.headline).fontWeight(.black).foregroundColor(.white)
                    Text(loraDevice?.id ?? "LORA-001").font(.caption).fontWeight(.bold).foregroundColor(.gray).tracking(1)
                }
                
                Spacer()
                
                Text(isOnline ? "ONLINE" : "OFFLINE")
                    .font(.caption).fontWeight(.black).foregroundColor(isOnline ? .themeEmerald : .themeRose)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((isOnline ? Color.themeEmerald : Color.themeRose).opacity(0.15))
                    .cornerRadius(10)
            }
            
            if let received = effectiveLatest?.receivedDate {
                InfoLine(title: "Last Uplink", value: received.formatted(date: .abbreviated, time: .standard))
            } else {
                InfoLine(title: "Last Uplink", value: "Waiting for ChirpStack uplink")
            }
            
            InfoLine(title: "DevEUI", value: effectiveLatest?.dev_eui ?? "00000000000000000000000000000000")
        }
        .padding(20)
        .background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var telemetrySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LATEST UPLINK").font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(1.5)
                Spacer()
                if isLoading { ProgressView().tint(.themeEmerald) }
            }
            
            HStack(spacing: 12) {
                MetricTile(title: "MQ2", value: effectiveLatest?.parsed?.mq3 ?? "--", subtitle: "Smoke/Gas")
                MetricTile(title: "MQ3", value: effectiveLatest?.parsed?.mq2 ?? "--", subtitle: "Alcohol")
            }
            
            InfoLine(title: "Event Type", value: effectiveLatest?.parsed?.event_type ?? effectiveLatest?.status ?? "--")
            InfoLine(title: "Severity", value: effectiveLatest?.parsed?.severity ?? "--")
            InfoLine(title: "Frame Counter", value: effectiveLatest?.f_cnt.map { "\($0)" } ?? "--")
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Payload").font(.caption2).fontWeight(.bold).foregroundColor(.gray).tracking(1)
                Text(effectiveLatest?.payload_text ?? effectiveLatest?.message ?? "No LoRaWAN uplink received yet")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var downlinkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DOWNLINK COMMAND").font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(1.5)
            
            TextField("SYS|START", text: $downlinkText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .padding(14)
                .background(Color.black.opacity(0.35))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.themeEmerald.opacity(0.25), lineWidth: 1))
            
            Button(action: sendDownlink) {
                HStack {
                    if isSending { ProgressView().tint(.themeBg) }
                    else { Image(systemName: "paperplane.fill") }
                    Text(isSending ? "SENDING..." : "SEND VIA CHIRPSTACK")
                }
                .font(.subheadline).fontWeight(.black)
                .foregroundColor(.themeBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.themeEmerald)
                .cornerRadius(14)
            }
            .disabled(isSending || downlinkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            
            if let message = statusMessage {
                Text(message).font(.caption).fontWeight(.bold).foregroundColor(.gray)
            }
            
            if let downlink = effectiveLatest?.downlink {
                InfoLine(title: "Last Downlink", value: downlink.sent == true ? "Sent" : (downlink.reason ?? downlink.error ?? "Not sent"))
            }
        }
        .padding(20)
        .background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    private var chirpStackSection: some View {
        Button(action: { openURL(AISafeGuardAPIClient.shared.chirpStackURL) }) {
            HStack(spacing: 12) {
                Image(systemName: "network").font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("OPEN CHIRPSTACK CONSOLE").font(.subheadline).fontWeight(.black).tracking(1)
                    Text(AISafeGuardAPIClient.shared.chirpStackURL.absoluteString).font(.caption2).foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "arrow.up.forward.square")
            }
            .foregroundColor(.themeEmerald)
            .padding(18)
            .background(Color.themeEmerald.opacity(0.1))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeEmerald.opacity(0.3), lineWidth: 1))
        }
    }
    
    private func refreshLatest() async {
        isLoading = true
        defer { isLoading = false }
        do {
            latest = try await AISafeGuardAPIClient.shared.fetchLoraLatest()
        } catch {
            statusMessage = "Unable to fetch latest LoRaWAN uplink."
        }
    }
    
    private func sendDownlink() {
        let command = downlinkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task {
            isSending = true
            defer { isSending = false }
            do {
                let response = try await AISafeGuardAPIClient.shared.sendLoraDownlink(command: command)
                statusMessage = response.downlink?.sent == true ? "Downlink accepted by MQTT bridge." : (response.downlink?.error ?? response.message ?? "Downlink queued with unknown status.")
                await refreshLatest()
            } catch {
                statusMessage = "Downlink request failed."
            }
        }
    }
}

struct InfoLine: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title).font(.caption).fontWeight(.bold).foregroundColor(.gray).frame(width: 96, alignment: .leading)
            Text(value).font(.caption).fontWeight(.bold).foregroundColor(.white.opacity(0.9)).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(1)
            Text(value).font(.title2).fontWeight(.black).foregroundColor(.white)
            Text(subtitle).font(.caption2).fontWeight(.bold).foregroundColor(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.black.opacity(0.35))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

struct HostMiniCard: View {
    let title: String; let isOnline: Bool; let icon: String; var isInteractive: Bool = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon).font(.title2).foregroundColor(isOnline ? .themeEmerald : .themeRose)
                Spacer()
                if isInteractive {
                    Image(systemName: "chevron.right").font(.caption2).foregroundColor(.gray)
                } else {
                    Circle().fill(isOnline ? Color.themeEmerald : Color.themeRose).frame(width: 8, height: 8).shadow(color: isOnline ? .themeEmerald : .themeRose, radius: 5)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption2).fontWeight(.bold).foregroundColor(.gray).textCase(.uppercase)
                Text(isOnline ? "ONLINE" : "OFFLINE").font(.subheadline).fontWeight(.black).foregroundColor(isOnline ? .white : .themeRose)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isInteractive ? Color.themeIndigo.opacity(0.6) : (isOnline ? Color.themeEmerald.opacity(0.3) : Color.themeRose.opacity(0.3)), lineWidth: isInteractive ? 2 : 1))
        .shadow(color: isInteractive ? Color.themeIndigo.opacity(0.3) : .clear, radius: 10)
    }
}

// 🚀 Nano 遠端控制終端機
struct NanoConsoleView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage("nano_console_clear_time") private var localClearTime: Double = 0
    @State private var isSendingCommand = false
    
    var consoleLogs: [SGEventObject] {
        viewModel.events.filter { event in
            event.event_type == "system_log" && event.parsedDate.timeIntervalSince1970 > localClearTime
        }.sorted { $0.id < $1.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "terminal.fill").foregroundColor(.themeEmerald)
                Text("NANO COMMAND SHELL").font(.headline).fontWeight(.black).foregroundColor(.themeEmerald).tracking(2)
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    localClearTime = Date().timeIntervalSince1970
                }) {
                    Image(systemName: "trash").font(.subheadline).foregroundColor(.gray)
                }
            }
            .padding(20)
            .background(Color(white: 0.1))
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        Text("AI-SafeGuard Core System v2.1").foregroundColor(.gray)
                        Text("Connected to DEV-NANO-001 via LoRa...").foregroundColor(.gray)
                        Text("Listening for system_log events...").foregroundColor(.gray)
                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 8)
                        
                        if consoleLogs.isEmpty {
                            Text(">> No recent logs available.").foregroundColor(.white.opacity(0.5)).italic()
                        } else {
                            ForEach(consoleLogs) { log in
                                let time = log.localTimeString.split(separator: " ").last ?? ""
                                let color = log.severity == "critical" ? Color.themeRose : (log.severity == "warning" ? Color.yellow : Color.themeEmerald)
                                
                                HStack(alignment: .top, spacing: 8) {
                                    Text("[\(time)]").foregroundColor(.gray)
                                    Text("[\(log.severity.uppercased())]").foregroundColor(color).bold()
                                    Text(log.description).foregroundColor(.white.opacity(0.9))
                                }
                                .font(.system(size: 13, design: .monospaced))
                                .id(log.id)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 16)
                .onChange(of: consoleLogs.count) { oldValue, newValue in
                    if let lastId = consoleLogs.last?.id {
                        withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                    }
                }
            }
            
            VStack(spacing: 12) {
                Text("REMOTE EXECUTION PROTOCOLS").font(.caption2).fontWeight(.bold).foregroundColor(.gray).tracking(2)
                
                HStack(spacing: 16) {
                    Button(action: { sendCommand("STOP") }) {
                        HStack {
                            if isSendingCommand { ProgressView().tint(.white) }
                            else { Image(systemName: "powersleep"); Text("DEEP SLEEP") }
                        }
                        .font(.subheadline).fontWeight(.black).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(red: 0.7, green: 0.2, blue: 0.2)).cornerRadius(12)
                    }
                    .disabled(isSendingCommand)
                    
                    Button(action: { sendCommand("START") }) {
                        HStack {
                            if isSendingCommand { ProgressView().tint(.white) }
                            else { Image(systemName: "bolt.fill"); Text("WAKE UP") }
                        }
                        .font(.subheadline).fontWeight(.black).foregroundColor(.themeBg).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.themeEmerald).cornerRadius(12)
                    }
                    .disabled(isSendingCommand)
                }
            }
            .padding(20)
            .background(Color(white: 0.1))
        }
    }
    
    private func sendCommand(_ cmd: String) {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        Task {
            isSendingCommand = true
            do {
                try await AISafeGuardAPIClient.shared.sendNanoSystemCommand(command: cmd)
                await viewModel.manualRefresh()
            } catch { print("🚨 指令發送失敗") }
            isSendingCommand = false
        }
    }
}

// --- 相機卡片與其他元件 ---

struct CameraConfigCard: View {
    @Binding var camera: SGDeviceNode
    let isAdmin: Bool
    let allUsers: [String]
    var onSave: (SGCameraConfig) -> Void
    
    @State private var showAssigneeSheet = false
    @State private var isSaved = false
    
    var body: some View {
        if camera.config != nil { cardContent }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            aiParametersSection
            assigneesSection
            if isAdmin { saveButtonSection }
        }
        .padding(24)
        .background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial))
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 15)
        .sheet(isPresented: $showAssigneeSheet) {
            AssigneeSearchSheet(currentAssignees: Binding(get: { camera.config?.assignees ?? [] }, set: { camera.config?.assignees = $0 }), allUsers: allUsers)
            .presentationDetents([.fraction(0.7), .large]).presentationDragIndicator(.visible).presentationBackground(.clear)
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.themeIndigo.opacity(0.2)).frame(width: 48, height: 48)
                RoundedRectangle(cornerRadius: 12).stroke(Color.themeIndigo.opacity(0.5), lineWidth: 1).frame(width: 48, height: 48)
                Image(systemName: "camera.viewfinder").foregroundColor(.themeIndigo).font(.title2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(camera.id).font(.headline).fontWeight(.black).foregroundColor(.white).textCase(.uppercase)
                Text("AI DETECTION MATRIX").font(.caption2).fontWeight(.bold).foregroundColor(.gray).tracking(1)
            }
            Spacer()
        }
    }
    
    private var aiParametersSection: some View {
        VStack(spacing: 16) {
            AISensitivityRow(title: "🔥 Fire", value: Binding(get: { camera.config?.fire ?? 0 }, set: { camera.config?.fire = $0 }), isAdmin: isAdmin)
            AISensitivityRow(title: "💨 Smoke", value: Binding(get: { camera.config?.smoke ?? 0 }, set: { camera.config?.smoke = $0 }), isAdmin: isAdmin)
            AISensitivityRow(title: "🧍 Fall Down", value: Binding(get: { camera.config?.fall ?? 0 }, set: { camera.config?.fall = $0 }), isAdmin: isAdmin)
            AISensitivityRow(title: "👷 Hardhat", value: Binding(get: { camera.config?.hardhat ?? 0 }, set: { camera.config?.hardhat = $0 }), isAdmin: isAdmin)
            AISensitivityRow(title: "🦺 Vest", value: Binding(get: { camera.config?.vest ?? 0 }, set: { camera.config?.vest = $0 }), isAdmin: isAdmin)
            AISensitivityRow(title: "🚬 Smoking", value: Binding(get: { camera.config?.smoking ?? 0 }, set: { camera.config?.smoking = $0 }), isAdmin: isAdmin)
            AISensitivityRow(title: "📱 Phone", value: Binding(get: { camera.config?.phone ?? 0 }, set: { camera.config?.phone = $0 }), isAdmin: isAdmin)
        }
        .padding(20).background(Color.black.opacity(0.4)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    @ViewBuilder
    private var assigneesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ACCESS PROTOCOL").font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(1)
                Spacer()
                if isAdmin {
                    Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); showAssigneeSheet = true }) {
                        HStack(spacing: 6) { Image(systemName: "plus"); Text("ASSIGN") }
                        .font(.caption).fontWeight(.bold).foregroundColor(.themeIndigo).padding(.horizontal, 12).padding(.vertical, 6).background(Color.themeIndigo.opacity(0.2)).cornerRadius(20)
                    }
                }
            }
            if let assignees = camera.config?.assignees {
                let displayAssignees = assignees.filter { $0.lowercased() != "admin" && $0.lowercased() != "super_admin" }
                if displayAssignees.isEmpty { Text("NO SPECIFIC CLEARANCE. ADMIN ACCESS ONLY.").font(.caption2).fontWeight(.bold).foregroundColor(.themeRose.opacity(0.8)) } else {
                    FlowLayout(items: displayAssignees) { user in
                        return HStack(spacing: 6) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                            Text(user).font(.caption).fontWeight(.bold).foregroundColor(.white)
                            if isAdmin { Button(action: { UIImpactFeedbackGenerator(style: .light).impactOccurred(); withAnimation(.spring()) { camera.config?.assignees.removeAll(where: { $0 == user }) } }) { Image(systemName: "xmark").font(.system(size: 10, weight: .black)).foregroundColor(.gray).padding(4).background(Color.black.opacity(0.3)).clipShape(Circle()) } }
                        }.padding(.leading, 12).padding(.trailing, isAdmin ? 6 : 12).padding(.vertical, 8).background(LinearGradient(colors: [Color.themeIndigo.opacity(0.5), Color.themeIndigo.opacity(0.3)], startPoint: .leading, endPoint: .trailing)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.themeIndigo.opacity(0.5), lineWidth: 1))
                    }
                }
            }
        }
    }
    
    private var saveButtonSection: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            if let config = camera.config { onSave(config) }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isSaved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation(.spring()) { isSaved = false } }
        }) {
            HStack(spacing: 8) { Image(systemName: isSaved ? "checkmark.shield.fill" : "lock.fill").symbolEffect(.bounce, options: .nonRepeating, value: isSaved); Text(isSaved ? "PROTOCOL SECURED" : "ENFORCE PROTOCOL") }
            .font(.subheadline).fontWeight(.black).foregroundColor(.white).tracking(1).frame(maxWidth: .infinity).padding(.vertical, 16).background(isSaved ? Color.themeEmerald : Color.themeIndigo).cornerRadius(16).shadow(color: isSaved ? Color.themeEmerald.opacity(0.4) : Color.themeIndigo.opacity(0.4), radius: 10, y: 5)
        }.padding(.top, 8)
    }
}

struct AISensitivityRow: View {
    let title: String; @Binding var value: Double; let isAdmin: Bool; let haptic = UISelectionFeedbackGenerator()
    var body: some View {
        HStack(spacing: 16) {
            Text(title).font(.subheadline).fontWeight(.bold).foregroundColor(.white).frame(width: 100, alignment: .leading)
            if isAdmin { Slider(value: $value, in: 0...1, step: 0.05).tint(value > 0 ? .themeEmerald : .white.opacity(0.2)).onChange(of: value) { oldValue, newValue in haptic.selectionChanged() }.onAppear { haptic.prepare() } } else { ProgressView(value: value, total: 1.0).tint(value > 0 ? .themeEmerald : .white.opacity(0.2)) }
            ZStack { RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.5)).frame(width: 45, height: 24); Text(value == 0 ? "OFF" : String(format: "%.2f", value)).font(.caption2.monospacedDigit()).fontWeight(.black).foregroundColor(value > 0 ? .themeEmerald : .gray) }
        }
    }
}

struct AssigneeSearchSheet: View {
    @Binding var currentAssignees: [String]
    let allUsers: [String]
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss
    var searchResults: [String] { searchText.isEmpty ? allUsers : allUsers.filter { $0.localizedCaseInsensitiveContains(searchText) } }
    var body: some View {
        ZStack {
            Color.themeBg.opacity(0.8).ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) { Text("AUTHORIZATION").font(.title2).fontWeight(.black).foregroundColor(.white); Text("Select users to grant camera access").font(.caption).foregroundColor(.gray) }
                    Spacer()
                    Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5)) }
                }.padding(.horizontal, 24).padding(.top, 30)
                HStack { Image(systemName: "magnifyingglass").foregroundColor(.themeIndigo); TextField("Search operator ID...", text: $searchText).foregroundColor(.white).autocapitalization(.none) }.padding(16).background(Color.black.opacity(0.4)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeIndigo.opacity(0.5), lineWidth: 1)).padding(.horizontal, 24)
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(searchResults, id: \.self) { user in
                            let isSelected = currentAssignees.contains(user)
                            Button(action: { UISelectionFeedbackGenerator().selectionChanged(); withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { if isSelected { currentAssignees.removeAll(where: { $0 == user }) } else { currentAssignees.append(user) } } }) {
                                HStack(spacing: 16) { ZStack { Circle().fill(isSelected ? Color.themeIndigo : Color.white.opacity(0.05)).frame(width: 40, height: 40); Image(systemName: isSelected ? "person.badge.shield.checkmark.fill" : "person.fill").foregroundColor(isSelected ? .white : .gray) }; Text(user).font(.headline).fontWeight(.bold).foregroundColor(isSelected ? .white : .gray); Spacer(); if isSelected { Image(systemName: "checkmark.seal.fill").font(.title2).foregroundColor(.themeEmerald).transition(.scale.combined(with: .opacity)) } }.padding(16).background(isSelected ? Color.themeIndigo.opacity(0.2) : Color.black.opacity(0.2)).cornerRadius(20).overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.themeIndigo : Color.white.opacity(0.05), lineWidth: 1))
                            }
                        }
                    }.padding(.horizontal, 24).padding(.bottom, 40)
                }
            }
        }
    }
}

struct FlowLayout<Data: Hashable, Content: View>: View {
    let items: [Data]; @ViewBuilder let content: (Data) -> Content
    var body: some View { if #available(iOS 16.0, *) { Flow(alignment: .leading, spacing: 8) { ForEach(items, id: \.self) { item in content(item) } } } else { HStack { ForEach(items, id: \.self) { item in content(item) } } } }
}

@available(iOS 16.0, *)
struct Flow: Layout {
    var alignment: Alignment = .leading; var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, alignment: alignment, spacing: spacing); return result.bounds }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) { let result = FlowResult(in: bounds.width, subviews: subviews, alignment: alignment, spacing: spacing); for row in result.rows { var startX = bounds.minX; for index in row.indices { let subview = subviews[index]; let size = subview.sizeThatFits(.unspecified); subview.place(at: CGPoint(x: startX, y: bounds.minY + row.yOffset), anchor: .topLeading, proposal: .unspecified); startX += size.width + spacing } } }
    struct FlowResult {
        var bounds: CGSize = .zero; var rows: [Row] = []; struct Row { var indices: [Int]; var yOffset: CGFloat }
        init(in maxWidth: CGFloat, subviews: Subviews, alignment: Alignment, spacing: CGFloat) { var currentX: CGFloat = 0; var currentY: CGFloat = 0; var currentRow: [Int] = []; for (index, subview) in subviews.enumerated() { let size = subview.sizeThatFits(.unspecified); if currentX + size.width > maxWidth && !currentRow.isEmpty { rows.append(Row(indices: currentRow, yOffset: currentY)); currentX = 0; currentY += size.height + spacing; currentRow = [] }; currentRow.append(index); currentX += size.width + spacing; bounds.width = max(bounds.width, currentX) }; if !currentRow.isEmpty { rows.append(Row(indices: currentRow, yOffset: currentY)); currentY += subviews.last?.sizeThatFits(.unspecified).height ?? 0 }; bounds.height = currentY }
    }
}
