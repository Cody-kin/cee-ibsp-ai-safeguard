import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var events: [SGEventObject] = []
    @Published var totalEventsCount: Int = 0
    @Published var aiState: String = "safe"
    
    @Published var rawMq2Value: Int = 0
    @Published var mq3Value: String = "--"
    @AppStorage("mq2_baseline") var mq2Baseline: Int = 0
    var displayMq2Value: Int { max(0, rawMq2Value - mq2Baseline) }
    
    @Published var isNanoOnline: Bool = false
    @Published var isLoraOnline: Bool = false
    @Published var isSosActive: Bool = false
    @Published var loraLatest: SGLoraLatestResponse?
    @Published var hasSensorTelemetry: Bool = false
    @Published var lastSensorTelemetryAt: Date?
    
    @Published var currentUser: SGCurrentUser?
    @Published var availableCameras: [SGDeviceNode] = []
    
    @Published var aiReport: String = "Initializing Neural Network..."
    @Published var isAnalyzing: Bool = false
    @Published var isManuallyAcknowledged: Bool = false
    
    @Published var unreadBadgeCount: Int = 0
    private var lastViewedEventId: Int {
        get { UserDefaults.standard.object(forKey: "last_viewed_event_id") == nil ? -1 : UserDefaults.standard.integer(forKey: "last_viewed_event_id") }
        set { UserDefaults.standard.set(newValue, forKey: "last_viewed_event_id") }
    }
    
    private var lastSeenEventId: Int = -1
    private var pollingTask: Task<Void, Never>?
    private var recentRiskEventsCache: [SGEventObject] = []
    private var lastEventsFetchDate: Date = .distantPast
    
    var overallSystemState: String {
        if isSosActive { return "CRITICAL" }
        if aiState == "critical" { return "CRITICAL" }
        if displayMq2Value > 400 { return "WARNING" }
        if aiState == "warning" { return "WARNING" }
        return "SAFE"
    }
    
    func startPolling() {
        stopPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                await fetchAllData(showActivity: false)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }
    
    func stopPolling() { pollingTask?.cancel(); pollingTask = nil }
    func manualRefresh() async { stopPolling(); await fetchAllData(showActivity: true); startPolling() }
    
    func acknowledgeWarning() {
        Task {
            isAnalyzing = true
            do { try await AISafeGuardAPIClient.shared.resetSafety(); self.isManuallyAcknowledged = true; await fetchAllData(showActivity: true) }
            catch { print("🚨 重置失敗") }
        }
    }
    
    func clearUnreadBadge() {
        if let newestEvent = events.max(by: { $0.id < $1.id }) { lastViewedEventId = newestEvent.id; unreadBadgeCount = 0 }
    }
    
    // 🌟 專門為 OTA 書籤法打造：取得當前最新的一筆 system_log 作為錨點
    func getLatestSystemLogId() -> String {
        // 從目前的 events 陣列中，找到 ID 最大（最新）的 system_log
        if let latestLog = events.filter({ $0.event_type == "system_log" || $0.event_type == "sys_log" }).max(by: { $0.id < $1.id }) {
            return "\(latestLog.timestamp)_\(latestLog.description)"
        }
        return ""
    }
    
    private func fetchAllData(showActivity: Bool) async {
        if showActivity { isAnalyzing = true }
        defer { if showActivity { isAnalyzing = false } }

        do {
            let shouldFetchEvents = showActivity || events.isEmpty || Date().timeIntervalSince(lastEventsFetchDate) > 15
            async let fetchStateTask = AISafeGuardAPIClient.shared.fetchAIState()
            async let fetchUserTask = AISafeGuardAPIClient.shared.fetchCurrentUser()
            async let fetchDevicesTask = AISafeGuardAPIClient.shared.fetchDevices()
            async let fetchLoraTask = AISafeGuardAPIClient.shared.fetchLoraLatest()
            
            let fetchedEvents: [SGEventObject]
            if shouldFetchEvents {
                fetchedEvents = try await AISafeGuardAPIClient.shared.fetchEvents()
                lastEventsFetchDate = Date()
            } else {
                fetchedEvents = events
            }

            let fetchedState = try await fetchStateTask
            let fetchedUser = try? await fetchUserTask
            let fetchedDevices = try? await fetchDevicesTask
            let fetchedLora = try? await fetchLoraTask
            let eventsChanged = shouldReplaceEvents(with: fetchedEvents)
            
            if eventsChanged {
                self.events = fetchedEvents
                self.totalEventsCount = fetchedEvents.count
                self.refreshRecentRiskEvents(from: fetchedEvents)

                if self.lastViewedEventId == -1 && !fetchedEvents.isEmpty {
                    self.lastViewedEventId = fetchedEvents.max(by: { $0.id < $1.id })?.id ?? 0
                    self.unreadBadgeCount = 0
                } else {
                    self.unreadBadgeCount = fetchedEvents.filter { $0.id > self.lastViewedEventId }.count
                }
            }

            self.aiState = fetchedState.state
            self.loraLatest = fetchedLora
            
            let activeUser = fetchedUser ?? self.currentUser
            if let user = activeUser { self.currentUser = user }
            if let devices = fetchedDevices {
                self.availableCameras = devices.filter { node in
                    guard node.type == "camera" else { return false }
                    if activeUser?.role.lowercased() == "admin" || activeUser?.role.lowercased() == "super_admin" { return true }
                    return node.config?.assignees.contains(activeUser?.username ?? "") ?? false
                }
                self.isNanoOnline = devices.first(where: { $0.id == "NANO-001" })?.status == "online"
            }
            
            parseSensorData(from: fetchedEvents, latestLora: fetchedLora)
            checkAllHeartbeats(from: fetchedEvents, latestLora: fetchedLora, devices: fetchedDevices)
            
            if let newestEvent = fetchedEvents.max(by: { $0.id < $1.id }) {
                if lastSeenEventId != -1 && newestEvent.id > lastSeenEventId {
                    let isDanger = newestEvent.severity == "critical" || newestEvent.severity == "warning" || newestEvent.severity == "high"
                    if isDanger {
                        withAnimation(.spring()) { self.isManuallyAcknowledged = false }
                        let title = newestEvent.severity == "critical" ? "🚨 工地極度危險警報" : "⚠️ 工地環境異常警告"
                        NotificationManager.shared.sendDangerAlert(title: title, body: newestEvent.event_name, eventId: newestEvent.id)
                    }
                }
                self.lastSeenEventId = newestEvent.id
            }
            updateAIReportText()
        } catch { print("🚨 數據抓取失敗：\(error.localizedDescription)") }
    }
    
    private func updateAIReportText() {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "en"
        aiReport = localAIReport(language: lang)
    }

    func localAIReport(language: String) -> String {
        let lang = supportedLanguage(language)
        let recentRiskEvents = recentRiskEventsCache
        let latestRisk = recentRiskEvents.first
        let mq3Int = Int(mq3Value) ?? 0
        let mq2Danger = displayMq2Value > 400
        let mq3Danger = mq3Int > 200
        let cameraCount = availableCameras.count
        let activeFeeds = cameraCount == 0 ? localized("no authorized camera feeds", "無授權影像源", "无授权影像源", lang) : localized("\(cameraCount) authorized camera feed\(cameraCount == 1 ? "" : "s")", "\(cameraCount) 路授權影像", "\(cameraCount) 路授权影像", lang)
        let newestRiskName = latestRisk.map { readableEventName($0, language: lang) } ?? localized("none", "無", "无", lang)

        if !isNanoOnline && !isLoraOnline {
            return localized(
                "Local AI verdict: SYSTEM OFFLINE. Both Nano vision and LoRa telemetry are unavailable, so risk confidence is low. Last known risk: \(newestRiskName). Restore at least one edge node before trusting the site state.",
                "本地 AI 判讀：系統離線。Nano 視覺與 LoRa 遙測皆不可用，目前風險可信度偏低。最後風險：\(newestRiskName)。請先恢復至少一個邊緣節點，再信任場域狀態。",
                "本地 AI 判断：系统离线。Nano 视觉与 LoRa 遥测都不可用，目前风险可信度偏低。最后风险：\(newestRiskName)。请先恢复至少一个边缘节点，再信任现场状态。",
                lang
            )
        }

        if isManuallyAcknowledged {
            return localized(
                "Local AI verdict: MANUALLY SECURED. The active alert set was acknowledged, but the model continues watching \(activeFeeds). MQ2=\(displayMq2Value) ppm, MQ3=\(mq3Value). New critical events will reopen the alert state.",
                "本地 AI 判讀：已人工確認安全。目前警報集已解除，但模型仍持續監看 \(activeFeeds)。MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Value)。若出現新的危急事件，會重新進入警報狀態。",
                "本地 AI 判断：已人工确认安全。目前警报集已解除，但模型仍持续监看 \(activeFeeds)。MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Value)。如果出现新的危急事件，会重新进入警报状态。",
                lang
            )
        }

        if isSosActive {
            return localized(
                "Local AI verdict: CRITICAL. A recent SOS voice event is still active. Treat it as human distress first, then verify camera feeds and dispatch response immediately.",
                "本地 AI 判讀：危急。近期 SOS 語音事件仍在有效時間內。請優先視為人員求救，立即檢視影像並派員處置。",
                "本地 AI 判断：危急。近期 SOS 语音事件仍在有效时间内。请优先视为人员求救，立即查看影像并派人处理。",
                lang
            )
        }

        if let risk = latestRisk, risk.event_type == "ai_vision" || aiState == "critical" {
            return localized(
                "Local AI verdict: CRITICAL VISION RISK. Latest trigger: \(readableEventName(risk, language: lang)) from \(risk.device_id ?? "unknown node"). \(recentRiskEvents.count) high-risk event\(recentRiskEvents.count == 1 ? "" : "s") in the last 15 minutes. Inspect the live feed before clearing.",
                "本地 AI 判讀：視覺危急風險。最新觸發：\(readableEventName(risk, language: lang))，來源 \(risk.device_id ?? "未知節點")。近 15 分鐘共有 \(recentRiskEvents.count) 筆高風險事件。解除前請先檢查即時影像。",
                "本地 AI 判断：视觉危急风险。最新触发：\(readableEventName(risk, language: lang))，来源 \(risk.device_id ?? "未知节点")。近 15 分钟共有 \(recentRiskEvents.count) 条高风险事件。解除前请先检查实时影像。",
                lang
            )
        }

        if mq2Danger || mq3Danger {
            let mq3Text = mq3Value == "--" ? "--" : "\(mq3Value)"
            return localized(
                "Local AI verdict: SENSOR WARNING. Gas telemetry is abnormal: MQ2=\(displayMq2Value) ppm, MQ3=\(mq3Text). Vision state is \(aiState.uppercased()), so compare the feed with on-site smell/smoke conditions.",
                "本地 AI 判讀：感測警告。氣體遙測異常：MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Text)。目前視覺狀態為 \(aiState.uppercased())，請同步比對影像與現場氣味/煙霧。",
                "本地 AI 判断：传感器警告。气体遥测异常：MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Text)。目前视觉状态为 \(aiState.uppercased())，请同步比对影像与现场气味/烟雾。",
                lang
            )
        }

        if !isNanoOnline || !isLoraOnline {
            let missing = !isNanoOnline ? localized("Nano vision", "Nano 視覺", "Nano 视觉", lang) : localized("LoRa telemetry", "LoRa 遙測", "LoRa 遥测", lang)
            return localized(
                "Local AI verdict: DEGRADED MONITORING. \(missing) is offline, but remaining signals are stable. Current view: \(activeFeeds), MQ2=\(displayMq2Value) ppm, MQ3=\(mq3Value).",
                "本地 AI 判讀：降級監控。\(missing) 離線，但其餘訊號目前穩定。目前影像：\(activeFeeds)，MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Value)。",
                "本地 AI 判断：降级监控。\(missing) 离线，但其余信号目前稳定。目前影像：\(activeFeeds)，MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Value)。",
                lang
            )
        }

        return localized(
            "Local AI verdict: SAFE. Vision, event stream, and LoRa telemetry agree: no active threat pattern detected. Monitoring \(activeFeeds); MQ2=\(displayMq2Value) ppm, MQ3=\(mq3Value).",
            "本地 AI 判讀：安全。視覺、事件流與 LoRa 遙測一致，未形成有效威脅模式。正在監看 \(activeFeeds)；MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Value)。",
            "本地 AI 判断：安全。视觉、事件流与 LoRa 遥测一致，未形成有效威胁模式。正在监看 \(activeFeeds)；MQ2=\(displayMq2Value) ppm，MQ3=\(mq3Value)。",
            lang
        )
    }

    private func recentEvents(minutes: Double) -> [SGEventObject] {
        let cutoff = Date().addingTimeInterval(-minutes * 60)
        return events.filter { $0.parsedDate >= cutoff }.sorted { $0.parsedDate > $1.parsedDate }
    }

    private func refreshRecentRiskEvents(from sourceEvents: [SGEventObject]) {
        let cutoff = Date().addingTimeInterval(-15 * 60)
        recentRiskEventsCache = sourceEvents
            .filter { event in
                let severity = event.severity.lowercased()
                let name = event.event_name.lowercased()
                return event.parsedDate >= cutoff && ["critical", "high", "warning"].contains(severity) && name != "heartbeat"
            }
            .sorted { $0.parsedDate > $1.parsedDate }
    }

    private func shouldReplaceEvents(with fetchedEvents: [SGEventObject]) -> Bool {
        guard events.count == fetchedEvents.count else { return true }
        guard events.first?.id == fetchedEvents.first?.id, events.first?.severity == fetchedEvents.first?.severity else { return true }
        guard events.prefix(20).map(\.id) == fetchedEvents.prefix(20).map(\.id) else { return true }
        guard events.prefix(20).map(\.severity) == fetchedEvents.prefix(20).map(\.severity) else { return true }
        return false
    }

    private func readableEventName(_ event: SGEventObject, language: String) -> String {
        let raw = event.event_name.replacingOccurrences(of: "_", with: " ")
        let lowered = raw.lowercased()
        if lowered.contains("fire") { return localized("Fire detected", "偵測到火災", "检测到火灾", language) }
        if lowered.contains("smoke") { return localized("Smoke detected", "偵測到煙霧", "检测到烟雾", language) }
        if lowered.contains("fall") { return localized("Fall detected", "偵測到跌倒", "检测到跌倒", language) }
        if lowered.contains("phone") { return localized("Phone-use violation", "偵測到玩手機", "检测到玩手机", language) }
        if lowered.contains("smoking") { return localized("Smoking violation", "偵測到抽菸", "检测到抽烟", language) }
        if lowered.contains("hardhat") { return localized("Hardhat violation", "安全帽異常", "安全帽异常", language) }
        if lowered.contains("vest") { return localized("Vest violation", "反光衣異常", "反光衣异常", language) }
        if lowered.contains("sos") { return localized("SOS voice alert", "SOS 語音警報", "SOS 语音警报", language) }
        return raw
    }

    private func supportedLanguage(_ language: String) -> String {
        if language == "zh-Hant" || language == "zh-Hans" { return language }
        return "en"
    }

    private func localized(_ en: String, _ zhHant: String, _ zhHans: String, _ language: String) -> String {
        switch supportedLanguage(language) {
        case "zh-Hant": return zhHant
        case "zh-Hans": return zhHans
        default: return en
        }
    }
    
    private func parseDate(from timeString: String) -> Date? {
        var string = timeString
        if !string.hasSuffix("Z") && !string.contains("+") { string += "Z" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]; return formatter.date(from: string)
    }
    
    private func checkAllHeartbeats(from events: [SGEventObject], latestLora: SGLoraLatestResponse?, devices: [SGDeviceNode]?) {
        let now = Date()
        if devices?.first(where: { $0.id == "LORA-001" || $0.id == "DEV-LORA-001" })?.status == "online" {
            isLoraOnline = true
        } else if let receivedDate = latestLora?.receivedDate {
            isLoraOnline = now.timeIntervalSince(receivedDate) < 300
        } else if let loraEvent = events.first(where: { $0.event_type == "sensor" || $0.device_id == "DEV-LORA-001" || $0.device_id == "LORA-001" }), let date = parseDate(from: loraEvent.timestamp) {
            isLoraOnline = now.timeIntervalSince(date) < 300
        } else { isLoraOnline = false }
        if let sosEvent = events.first(where: { $0.event_type == "voice_sos" }), let date = parseDate(from: sosEvent.timestamp) {
            isSosActive = now.timeIntervalSince(date) < 120
        } else { isSosActive = false }
    }
    
    private func parseSensorData(from events: [SGEventObject], latestLora: SGLoraLatestResponse?) {
        if let parsed = latestLora?.parsed,
           let mq2Raw = parsed.mq3,
           let mq3Raw = parsed.mq2,
           let mq2 = Int(mq2Raw) {
            self.rawMq2Value = mq2
            self.mq3Value = mq3Raw
            self.hasSensorTelemetry = true
            self.lastSensorTelemetryAt = latestLora?.receivedDate ?? Date()
            return
        }

        if let payload = latestLora?.payload_text,
           applyGasValues(from: payload) {
            self.lastSensorTelemetryAt = latestLora?.receivedDate ?? Date()
            return
        }

        guard let sensorEvent = events.first(where: { $0.event_type == "sensor" || $0.description.contains("[Gas:") }) else { return }
        if applyGasValues(from: sensorEvent.description) {
            self.lastSensorTelemetryAt = sensorEvent.parsedDate
        }
    }

    private func applyGasValues(from text: String) -> Bool {
        let desc = text
        let pattern = "\\[Gas:\\s*(\\d+)\\s*/\\s*(\\d+)\\]"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: desc, options: [], range: NSRange(location: 0, length: desc.utf16.count)) {
            if let mq2Range = Range(match.range(at: 1), in: desc), let mq3Range = Range(match.range(at: 2), in: desc) {
                // Current LoRa event text is [Gas:mq3/mq2], so swap for display.
                self.rawMq2Value = Int(String(desc[mq3Range])) ?? 0
                self.mq3Value = String(desc[mq2Range])
                self.hasSensorTelemetry = true
                return true
            }
        }

        let lower = desc.lowercased()
        if lower.contains("mq2") || lower.contains("mq3") {
            let mq2 = firstNumber(after: "mq2", in: lower)
            let mq3 = firstNumber(after: "mq3", in: lower)
            if let mq2 {
                self.rawMq2Value = mq2
                self.mq3Value = mq3.map(String.init) ?? self.mq3Value
                self.hasSensorTelemetry = true
                return true
            }
        }

        return false
    }

    private func firstNumber(after key: String, in text: String) -> Int? {
        guard let keyRange = text.range(of: key) else { return nil }
        let suffix = text[keyRange.upperBound...]
        let pattern = #"[-_\s:=|,]*([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: String(suffix), range: NSRange(location: 0, length: suffix.utf16.count)),
              let range = Range(match.range(at: 1), in: suffix) else { return nil }
        return Int(suffix[range])
    }
}
