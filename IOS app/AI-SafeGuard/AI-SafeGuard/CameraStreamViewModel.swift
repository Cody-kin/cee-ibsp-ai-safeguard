import SwiftUI
import Combine

@MainActor
final class CameraStreamViewModel: ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var isOffline: Bool = true
    
    private var streamingTask: Task<Void, Never>?
    private var consecutiveFailures = 0
    private let maxFailures = 3
    
    // Fallback single-camera stream. Dashboard camera cards prefer each device.stream_url.
    private let streamURL = "http://127.0.0.1/storage/latest_NANO-001.jpg"
    
    // 獨立的輪詢 Session，避免快取干擾
    private let pollingSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    func startStreaming() {
        stopStreaming()
        
        // 剛啟動時先給一張我們自己畫的「科技網格」底圖墊著
        if currentFrame == nil {
            currentFrame = createMockLastFrame()
            isOffline = true
        }
        
        streamingTask = Task {
            while !Task.isCancelled {
                await fetchNextFrame()
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒 (2 FPS)
            }
        }
    }
    
    func stopStreaming() {
        streamingTask?.cancel()
        streamingTask = nil
    }
    
    private func fetchNextFrame() async {
        // 強制破壞快取參數
        let urlString = "\(streamURL)?t=\(Date().timeIntervalSince1970)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 2.0
        
        do {
            let (data, response) = try await pollingSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                handleFailure()
                return
            }
            
            let newImage = autoreleasepool { UIImage(data: data) }
            if let frame = newImage {
                // 🎉 成功抓到圖片！更新畫面並解除斷線狀態
                self.currentFrame = frame
                self.consecutiveFailures = 0
                if self.isOffline { self.isOffline = false }
            } else {
                handleFailure()
            }
        } catch {
            let nsError = error as NSError
            // 忽略 iOS 底層偶發的 -1005 (The network connection was lost)
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorNetworkConnectionLost {
                return
            }
            handleFailure()
        }
    }
    
    private func handleFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= maxFailures {
            if !isOffline { isOffline = true }
        }
    }
    
    // 自動生成「最後已知畫面」的科技網格底圖
    private func createMockLastFrame() -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 800, height: 600)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        let context = UIGraphicsGetCurrentContext()!
        
        context.setFillColor(UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0).cgColor)
        context.fill(rect)
        
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.05).cgColor)
        context.setLineWidth(2.0)
        
        for i in stride(from: CGFloat(0), to: CGFloat(800), by: CGFloat(40)) {
            context.move(to: CGPoint(x: i, y: 0))
            context.addLine(to: CGPoint(x: i, y: 600))
            context.move(to: CGPoint(x: 0, y: i))
            context.addLine(to: CGPoint(x: 800, y: i))
        }
        
        context.strokePath()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}
