import SwiftUI
import Combine

@MainActor
class SnapshotCameraViewModel: ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var isOffline: Bool = false
    
    private var timerTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    let streamUrlPath: String
    
    init(streamUrlPath: String) {
        self.streamUrlPath = streamUrlPath
    }
    
    func startStreaming() {
        stopStreaming()
        isOffline = false
        timerTask = Task {
            while !Task.isCancelled {
                await fetchNextFrame()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }
    
    func stopStreaming() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func fetchNextFrame() async {
        // 🌟 防呆：如果 streamUrl 是空的 (代表後端沒給)，立刻判定為離線！
        guard !streamUrlPath.isEmpty, let token = UserDefaults.standard.string(forKey: "aisafeguard_access_token") else {
            withAnimation { self.isOffline = true }
            return
        }
        
        let timestamp = Date().timeIntervalSince1970
        let fullUrlString = "http://127.0.0.1\(streamUrlPath)?_t=\(timestamp)"
        guard let url = URL(string: fullUrlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let image = await Task.detached(priority: .utility) { UIImage(data: data) }.value
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let image {
                self.currentFrame = image
                self.consecutiveFailures = 0
                self.isOffline = false
            } else {
                markFrameFailure()
            }
        } catch {
            markFrameFailure()
        }
    }

    private func markFrameFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= 2 {
            self.isOffline = true
        }
    }
}

struct SnapshotCameraView: View {
    let cameraName: String
    let streamUrl: String
    @StateObject private var viewModel: SnapshotCameraViewModel
    
    init(cameraName: String, streamUrl: String) {
        self.cameraName = cameraName
        self.streamUrl = streamUrl
        _viewModel = StateObject(wrappedValue: SnapshotCameraViewModel(streamUrlPath: streamUrl))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(viewModel.isOffline ? Color.themeRose : Color.themeEmerald).frame(width: 8, height: 8)
                Text(cameraName).font(.caption).fontWeight(.bold).foregroundColor(.white)
                Spacer()
                Text(viewModel.isOffline ? "CONNECTION LOST" : "LIVE").font(.caption2).fontWeight(.bold).foregroundColor(viewModel.isOffline ? .themeRose : .themeEmerald)
            }.padding(12).background(Color.black.opacity(0.5))
            
            ZStack {
                if let image = viewModel.currentFrame, !viewModel.isOffline {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fit).frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash").font(.system(size: 40)).foregroundColor(.gray)
                        Text("SIGNAL LOST").font(.headline).foregroundColor(.gray)
                    }.frame(height: 200).frame(maxWidth: .infinity)
                }
            }.background(Color.black)
        }
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .onAppear { viewModel.startStreaming() }
        .onDisappear { viewModel.stopStreaming() }
    }
}
