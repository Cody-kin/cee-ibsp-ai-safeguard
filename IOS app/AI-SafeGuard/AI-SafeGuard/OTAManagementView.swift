import SwiftUI
import UniformTypeIdentifiers

struct OTAManagementView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var files: [AISafeGuardAPIClient.SGOTAFile] = []
    @State private var historyLogs: [AISafeGuardAPIClient.SGOTALog] = [] // 🌟 新增歷史日誌狀態
    @State private var isLoading = true
    
    // 檔案上傳狀態
    @State private var isImporterPresented = false
    @State private var isUploading = false
    
    // 預覽與部署狀態
    @State private var previewFile: AISafeGuardAPIClient.SGOTAFile?
    @State private var previewContent: String = ""
    @State private var isFetchingContent = false
    
    // 輪詢魔法與鎖定狀態
    @AppStorage("ota_is_deploying") private var isDeploying: Bool = false
    @AppStorage("ota_baseline_log") private var baselineLogStr: String = ""
    @State private var deployLogs: [String] = []
    @State private var pollingTask: Task<Void, Never>?
    @State private var deploymentStatus: DeployStatus = .idle
    
    enum DeployStatus: Equatable {
        case idle, updating, success
        case error(String)
    }

    var body: some View {
        ZStack {
            // 🌟 炫酷背景
            Color.themeBg.ignoresSafeArea()
            Circle().fill(Color.themeIndigo.opacity(0.15)).blur(radius: 120).frame(width: 400, height: 400).offset(x: 150, y: -200)
            Circle().fill(Color.themeEmerald.opacity(0.1)).blur(radius: 120).frame(width: 300, height: 300).offset(x: -150, y: 300)
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(.themeEmerald).scaleEffect(1.5)
                    Text("FETCHING DATA...").font(.caption).fontWeight(.black).foregroundColor(.themeEmerald).tracking(2)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        
                        // ==================== 區塊一：部署載荷庫 ====================
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DEPLOYMENT PAYLOADS").font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(2)
                                    Text("\(files.count) PACKAGES AVAILABLE").font(.caption2).foregroundColor(.themeIndigo).fontWeight(.bold)
                                }
                                Spacer()
                                if !files.isEmpty {
                                    Button(action: deleteAll) {
                                        HStack { Image(systemName: "trash.fill"); Text("PURGE ALL") }
                                        .font(.caption).fontWeight(.bold).foregroundColor(.themeRose).padding(.horizontal, 12).padding(.vertical, 6).background(Color.themeRose.opacity(0.2)).cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 16)
                            
                            if files.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "shippingbox").font(.system(size: 40)).foregroundColor(.gray.opacity(0.3))
                                    Text("NO FIRMWARE AVAILABLE").font(.subheadline).fontWeight(.black).foregroundColor(.gray).tracking(1)
                                }.frame(height: 150).frame(maxWidth: .infinity)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(files) { file in
                                        HStack(spacing: 16) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12).fill(Color.themeIndigo.opacity(0.2)).frame(width: 48, height: 48)
                                                Image(systemName: "doc.zipper").font(.title2).foregroundColor(.themeIndigo)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(file.displayName).font(.headline).fontWeight(.bold).foregroundColor(.white)
                                                HStack { Text(file.displaySize).font(.caption2.monospacedDigit()).foregroundColor(.themeEmerald).fontWeight(.bold); Text("•").foregroundColor(.gray); Text(file.displayTime).font(.caption2.monospacedDigit()).foregroundColor(.gray) }
                                            }
                                            Spacer()
                                            Button(action: { loadPreview(for: file) }) { Image(systemName: "play.circle.fill").font(.system(size: 32)).foregroundColor(.themeEmerald).shadow(color: .themeEmerald.opacity(0.5), radius: 5) }
                                            Button(action: { UIImpactFeedbackGenerator(style: .medium).impactOccurred(); delete(file.displayName) }) { Image(systemName: "xmark").font(.caption).fontWeight(.black).foregroundColor(.themeRose).padding(10).background(Color.themeRose.opacity(0.15)).clipShape(Circle()) }
                                        }
                                        .padding(12).background(Color.black.opacity(0.4)).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
                                    }
                                }.padding(.horizontal, 20).padding(.bottom, 20)
                            }
                        }
                        .background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial)).cornerRadius(24).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        
                        // ==================== 區塊二：歷史更新日誌 ====================
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("DEPLOYMENT HISTORY").font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(2)
                                    Text("CLOUD AUDIT TRAIL").font(.caption2).foregroundColor(.themeIndigo).fontWeight(.bold)
                                }
                                Spacer()
                                Button(action: { Task { await fetchHistoryLogs() } }) { Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.gray).padding(.trailing, 8) }
                                Button(action: clearHistoryLogs) {
                                    HStack { Image(systemName: "trash.fill"); Text("CLEAR LOG") }
                                    .font(.caption).fontWeight(.bold).foregroundColor(.themeRose).padding(.horizontal, 12).padding(.vertical, 6).background(Color.themeRose.opacity(0.2)).cornerRadius(8)
                                }.disabled(historyLogs.isEmpty)
                            }
                            .padding(.horizontal, 20).padding(.vertical, 16)
                            
                            if historyLogs.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 40)).foregroundColor(.gray.opacity(0.3))
                                    Text("NO UPDATE HISTORY YET").font(.subheadline).fontWeight(.black).foregroundColor(.gray).tracking(1)
                                }.frame(height: 150).frame(maxWidth: .infinity)
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(historyLogs) { log in
                                            HStack(spacing: 16) {
                                                Text(log.timestamp).font(.caption2.monospacedDigit()).foregroundColor(.gray).frame(width: 130, alignment: .leading)
                                                statusBadge(for: log.status).frame(width: 90, alignment: .leading)
                                                Text(log.message).font(.caption).foregroundColor(.white.opacity(0.8)).frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            .padding(.vertical, 12).padding(.horizontal, 20)
                                            Divider().background(Color.white.opacity(0.05))
                                        }
                                    }
                                }.frame(height: 250)
                            }
                        }
                        .background(Color.themeCard.opacity(0.6).background(.ultraThinMaterial)).cornerRadius(24).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                    }.padding(20).padding(.bottom, 80)
                }.refreshable { await fetchFiles(); await fetchHistoryLogs() }
            }
            
            if isUploading {
                Color.black.opacity(0.7).ignoresSafeArea()
                VStack(spacing: 16) { ProgressView().tint(.themeEmerald).scaleEffect(1.5); Text("UPLOADING PAYLOAD...").font(.headline).fontWeight(.black).foregroundColor(.themeEmerald).tracking(2) }.padding(40).background(Color.themeCard.opacity(0.9).background(.ultraThinMaterial)).cornerRadius(24).overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.themeEmerald.opacity(0.5), lineWidth: 1))
            }
            if let file = previewFile { previewModal(for: file) }
            if isDeploying { deploymentOverlay }
        }
        .navigationTitle("OTA Payload Center")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { isImporterPresented = true }) { Image(systemName: "plus.square.fill").font(.title2).foregroundColor(.themeEmerald) }.disabled(isUploading || isDeploying)
            }
        }
        .onAppear {
            Task { await fetchFiles(); await fetchHistoryLogs() }
            if isDeploying {
                deploymentStatus = .updating
                deployLogs = ["Resuming OTA monitoring...", "Waiting for system_log events..."]
                startBookmarkPolling()
            }
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.data, .archive, .shellScript, .plainText], allowsMultipleSelection: false) { result in
            handleFileSelection(result)
        }
        .preferredColorScheme(.dark)
    }
    
    // 🌟 狀態徽章 UI
    @ViewBuilder
    private func statusBadge(for status: String) -> some View {
        HStack(spacing: 4) {
            if status == "Deploying" {
                ProgressView().tint(.blue).scaleEffect(0.6); Text("Deploying").foregroundColor(.blue)
            } else if status == "Success" {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.themeEmerald); Text("Success").foregroundColor(.themeEmerald)
            } else if status == "Failed" {
                Image(systemName: "xmark.circle.fill").foregroundColor(.themeRose); Text("Failed").foregroundColor(.themeRose)
            } else {
                Image(systemName: "terminal.fill").foregroundColor(.gray); Text("Info").foregroundColor(.gray)
            }
        }.font(.caption2).fontWeight(.black)
    }
    
    // MARK: - 預覽視窗
    private func previewModal(for file: AISafeGuardAPIClient.SGOTAFile) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack { Image(systemName: "terminal").foregroundColor(.themeEmerald); Text("INSPECTING: \(file.displayName)").font(.caption).fontWeight(.black).foregroundColor(.gray).tracking(1); Spacer(); Button(action: { previewFile = nil }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray).font(.title3) } }.padding(20).background(Color(white: 0.1))
                ScrollView {
                    if isFetchingContent { ProgressView().padding(40) } else { Text(previewContent).font(.system(size: 12, design: .monospaced)).foregroundColor(.themeEmerald).frame(maxWidth: .infinity, alignment: .leading).padding(16) }
                }.background(Color.black)
                Button(action: { startDeployment() }) { HStack { Image(systemName: "flame.fill"); Text("DISPATCH & DEPLOY (OTA_SCRIPT)") }.font(.headline).fontWeight(.black).foregroundColor(.white).tracking(1).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.themeRose).cornerRadius(12) }.padding(20).background(Color(white: 0.1))
            }.frame(maxHeight: 600).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeBorder, lineWidth: 1)).padding(20)
        }.zIndex(10)
    }
    
    // MARK: - 部署鎖定覆蓋層
    private var deploymentOverlay: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            VStack(spacing: 32) {
                ZStack {
                    Circle().stroke(Color.themeIndigo.opacity(0.3), lineWidth: 2).frame(width: 140, height: 140)
                    if deploymentStatus == .updating {
                        Circle().trim(from: 0, to: 0.8).stroke(Color.themeEmerald, style: StrokeStyle(lineWidth: 4, lineCap: .round)).frame(width: 140, height: 140).rotationEffect(.degrees(isDeploying ? 360 : 0)).animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isDeploying)
                        Image(systemName: "network").font(.system(size: 50)).foregroundColor(.themeIndigo).symbolEffect(.pulse)
                    } else if deploymentStatus == .success { Image(systemName: "checkmark.shield.fill").font(.system(size: 80)).foregroundColor(.themeEmerald).shadow(color: .themeEmerald.opacity(0.5), radius: 20).transition(.scale)
                    } else { Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 80)).foregroundColor(.themeRose).shadow(color: .themeRose.opacity(0.5), radius: 20).transition(.scale) }
                }
                
                VStack(spacing: 12) {
                    if deploymentStatus == .updating { Text("UPDATING FIRMWARE...").font(.title2).fontWeight(.black).foregroundColor(.white).tracking(3); Text("Awaiting telemetry from DEV-NANO-001").font(.subheadline).foregroundColor(.gray)
                    } else if deploymentStatus == .success { Text("OTA SUCCESSFUL").font(.title2).fontWeight(.black).foregroundColor(.themeEmerald).tracking(3); Text("Edge node is back online and fully secured.").font(.subheadline).foregroundColor(.gray)
                    } else if case let .error(msg) = deploymentStatus { Text("OTA FAILED").font(.title2).fontWeight(.black).foregroundColor(.themeRose).tracking(3); Text(msg).font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.horizontal, 40) }
                }
                
                if deploymentStatus == .updating {
                    ScrollViewReader { proxy in
                        ScrollView { VStack(alignment: .leading, spacing: 8) { ForEach(deployLogs, id: \.self) { log in Text("> \(log)").font(.system(size: 12, design: .monospaced)).foregroundColor(.themeEmerald.opacity(0.8)) } }.frame(maxWidth: .infinity, alignment: .leading).padding(16) }
                        .frame(height: 160).background(Color(white: 0.05)).cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1)).padding(.horizontal, 40)
                        .onChange(of: deployLogs.count) { oldValue, newValue in proxy.scrollTo(deployLogs.last, anchor: .bottom) }
                    }
                }
                
                Button(action: {
                    pollingTask?.cancel(); isDeploying = false
                    if deploymentStatus == .updating { addHistoryLog(status: "Failed", message: "Manually unlocked by Admin") } // 🌟 記錄強制解鎖
                    deploymentStatus = .idle; deployLogs.removeAll()
                }) {
                    Text(deploymentStatus == .updating ? "FORCE UNLOCK" : "ACKNOWLEDGE & RESUME")
                        .font(.headline).fontWeight(.black).foregroundColor(deploymentStatus == .updating ? .gray : .white).padding(.horizontal, 32).padding(.vertical, 16)
                        .background(deploymentStatus == .updating ? Color.white.opacity(0.1) : Color.themeEmerald).cornerRadius(12)
                }.padding(.top, 16)
            }
        }.zIndex(20)
    }
    
    // MARK: - API 邏輯方法
    private func fetchHistoryLogs() async {
        do { let logs = try await AISafeGuardAPIClient.shared.fetchOTALogs(); withAnimation { self.historyLogs = logs } } catch { print("🚨 歷史讀取失敗") }
    }
    
    private func addHistoryLog(status: String, message: String) {
        Task { do { try await AISafeGuardAPIClient.shared.addOTALog(status: status, message: message); await fetchHistoryLogs() } catch {} }
    }
    
    private func clearHistoryLogs() {
        Task { do { try await AISafeGuardAPIClient.shared.clearOTALogs(); await fetchHistoryLogs() } catch {} }
    }
    
    private func fetchFiles() async {
        do { let fetched = try await AISafeGuardAPIClient.shared.fetchOTAFiles(); withAnimation { self.files = fetched; self.isLoading = false } } catch { withAnimation { isLoading = false } }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result, let fileURL = urls.first else { return }
        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer { fileURL.stopAccessingSecurityScopedResource() }
        
        Task {
            isUploading = true
            do {
                try await AISafeGuardAPIClient.shared.uploadOTAFile(fileURL: fileURL)
                let name = fileURL.lastPathComponent
                if name == "update.sh" || name.hasSuffix(".pt") { addHistoryLog(status: "Info", message: "Uploaded new payload: \(name)") } // 🌟 記錄上傳
                await fetchFiles()
            } catch { print("🚨 上傳失敗") }
            isUploading = false
        }
    }
    
    private func delete(_ filename: String) {
        Task { do { try await AISafeGuardAPIClient.shared.deleteOTAFile(filename: filename); await fetchFiles() } catch { print("🚨 刪除失敗") } }
    }
    
    private func deleteAll() {
        Task { do { try await AISafeGuardAPIClient.shared.deleteAllOTAFiles(); await fetchFiles() } catch { print("🚨 清空失敗") } }
    }
    
    private func loadPreview(for file: AISafeGuardAPIClient.SGOTAFile) {
        previewFile = file; isFetchingContent = true
        Task { do { previewContent = try await AISafeGuardAPIClient.shared.fetchOTAFileContent(filename: file.displayName) } catch { previewContent = "Error fetching script." }; withAnimation { isFetchingContent = false } }
    }
    
    // 🌟 啟動部署：取得書籤並發射指令
    private func startDeployment() {
        previewFile = nil
        baselineLogStr = viewModel.getLatestSystemLogId() // 取得日誌書籤
        
        isDeploying = true; deploymentStatus = .updating
        deployLogs = ["Initiating OTA sequence...", "Bookmark secured...", "Sending OTA_SCRIPT command..."]
        
        Task {
            do {
                try await AISafeGuardAPIClient.shared.sendNanoSystemCommand(command: "OTA_SCRIPT")
                deployLogs.append("Command acknowledged. Awaiting reboot...")
                addHistoryLog(status: "Deploying", message: "OTA command dispatched via LoRa") // 🌟 記錄開始部署
                startBookmarkPolling()
            } catch {
                deploymentStatus = .error("Failed to dispatch OTA command.")
            }
        }
    }
    
    // 📡 階段三：日誌書籤魔法輪詢
    private func startBookmarkPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    let events = try await AISafeGuardAPIClient.shared.fetchEvents()
                    let sysLogs = events.filter { $0.event_type == "system_log" || $0.event_type == "sys_log" }.sorted { $0.id > $1.id }
                    
                    var triggeredEvent: SGEventObject? = nil
                    var newLogsFound: [String] = []
                    
                    for log in sysLogs {
                        let currentLogId = "\(log.timestamp)_\(log.description)"
                        if currentLogId == baselineLogStr { break } // 遇到書籤就停
                        
                        newLogsFound.insert("[\(log.severity.uppercased())] \(log.description)", at: 0)
                        
                        let isSuccess = log.event_name == "OTA Success" || log.event_name == "System Ready" || log.description.contains("Started Successfully")
                        let isError = log.event_name == "OTA Error"
                        
                        if isSuccess || isError {
                            triggeredEvent = log
                            break
                        }
                    }
                    
                    for logMsg in newLogsFound {
                        if !deployLogs.contains(logMsg) { await MainActor.run { deployLogs.append(logMsg) } }
                    }
                    
                    if let targetLog = triggeredEvent {
                        let isErrorLog = targetLog.event_name == "OTA Error"
                        
                        if !isErrorLog {
                            await MainActor.run {
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                deploymentStatus = .success
                                deployLogs.append("🎉 OTA SECURED: \(targetLog.description)")
                                addHistoryLog(status: "Success", message: "Edge device updated successfully") // 🌟 記錄成功
                                pollingTask?.cancel()
                            }
                        } else {
                            await MainActor.run {
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                deploymentStatus = .error(targetLog.description)
                                addHistoryLog(status: "Failed", message: targetLog.description) // 🌟 記錄失敗
                                pollingTask?.cancel()
                            }
                        }
                        return
                    }
                } catch {
                    await MainActor.run { deployLogs.append("Network timeout, retrying...") }
                }
            }
        }
    }
}
