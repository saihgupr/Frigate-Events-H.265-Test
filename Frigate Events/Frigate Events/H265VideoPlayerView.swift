import SwiftUI
import AVKit
import AVFoundation

struct H265VideoPlayerView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var retryCount = 0
    @State private var showWebViewPlayer = false
    
    private let maxRetries = 3
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading video...")
                    .foregroundColor(.white)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("Video Playback Error")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    if retryCount < maxRetries {
                        Button("Retry with Different Settings") {
                            retryCount += 1
                            loadVideo()
                        }
                        .foregroundColor(.blue)
                        .padding()
                    } else {
                        Button("Try Web Player") {
                            showWebViewPlayer = true
                        }
                        .foregroundColor(.blue)
                        .padding()
                    }
                }
            } else if showWebViewPlayer {
                WebViewVideoPlayer(videoURL: videoURL)
            } else if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        setupAudioSession()
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                        deactivateAudioSession()
                    }
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .onAppear {
            loadVideo()
        }
    }
    
    private func loadVideo() {
        isLoading = true
        errorMessage = nil
        
        // Try different configurations based on retry count
        switch retryCount {
        case 0:
            loadWithStandardAVPlayer()
        case 1:
            loadWithCustomAssetConfiguration()
        case 2:
            loadWithHTTPHeaders()
        default:
            loadWithMinimalConfiguration()
        }
    }
    
    private func loadWithStandardAVPlayer() {
        let avPlayer = AVPlayer(url: videoURL)
        checkPlayerStatus(avPlayer, timeout: 5.0)
    }
    
    private func loadWithCustomAssetConfiguration() {
        let asset = AVURLAsset(url: videoURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "Accept": "video/mp4,video/*;q=0.9,*/*;q=0.8",
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15"
            ]
        ])
        
        let playerItem = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: playerItem)
        checkPlayerStatus(avPlayer, timeout: 8.0)
    }
    
    private func loadWithHTTPHeaders() {
        let asset = AVURLAsset(url: videoURL, options: [
            "AVURLAssetHTTPHeaderFieldsKey": [
                "Accept": "*/*",
                "Accept-Encoding": "gzip, deflate",
                "Connection": "keep-alive",
                "User-Agent": "FrigateEvents/1.0"
            ]
        ])
        
        let playerItem = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: playerItem)
        checkPlayerStatus(avPlayer, timeout: 10.0)
    }
    
    private func loadWithMinimalConfiguration() {
        // Try with minimal configuration as last resort
        let avPlayer = AVPlayer(url: videoURL)
        checkPlayerStatus(avPlayer, timeout: 3.0)
    }
    
    private func checkPlayerStatus(_ avPlayer: AVPlayer, timeout: TimeInterval) {
        let item = avPlayer.currentItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if item?.status == .failed {
                let error = item?.error?.localizedDescription ?? "Unknown error"
                self.errorMessage = "Video playback failed (Attempt \(self.retryCount + 1)/\(self.maxRetries + 1)): \(error)"
                self.isLoading = false
            } else if item?.status == .readyToPlay {
                self.player = avPlayer
                self.isLoading = false
            } else {
                // Still loading, give it more time
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if item?.status == .failed {
                        let error = item?.error?.localizedDescription ?? "Unknown error"
                        self.errorMessage = "Video playback failed (Attempt \(self.retryCount + 1)/\(self.maxRetries + 1)): \(error)"
                        self.isLoading = false
                    } else if item?.status == .readyToPlay {
                        self.player = avPlayer
                        self.isLoading = false
                    } else {
                        self.errorMessage = "Video took too long to load. This may be due to H.265 encoding issues."
                        self.isLoading = false
                    }
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category. Error: \(error)")
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session. Error: \(error)")
        }
    }
}

// MARK: - WebView Video Player as Fallback
struct WebViewVideoPlayer: View {
    let videoURL: URL
    
    var body: some View {
        VStack {
            Text("Web Player")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("This would embed the video in a WebView for better H.265 support.")
                .font(.body)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding()
            
            Text("Video URL: \(videoURL.absoluteString)")
                .font(.caption)
                .foregroundColor(.gray)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct H265VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        if let url = URL(string: "http://devimages.apple.com/samplecode/adp/adp-60fps.mov") {
            H265VideoPlayerView(videoURL: url)
        } else {
            Text("Invalid URL for preview")
        }
    }
}
