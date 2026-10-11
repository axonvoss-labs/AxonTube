import AppKit
import Foundation
import PlayerCore
import SwiftUI
import WebKit

struct YouTubePlaybackState {
    let time: Double
    let duration: Double
    let state: Int
    let rate: Double
    let rates: [Double]
}

/// Only an explicitly opened YouTube video creates this web view. No API keys or AI services.
@MainActor
final class YouTubeController: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    let link: YouTubeLink
    private(set) var webView: WKWebView!
    var onReady: (() -> Void)?
    var onUpdate: ((YouTubePlaybackState) -> Void)?
    var onError: ((LocalizedText) -> Void)?
    private let sessionID = UUID().uuidString
    private let origin = "https://io.github.axonvoss-labs.axontube"
    private var valid = true
    private var ready = false
    private var watchdog: Task<Void, Never>?

    init(link: YouTubeLink) {
        self.link = link
        super.init()
        let content = WKUserContentController()
        content.add(self, name: "playerBridge")
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.websiteDataStore = .nonPersistent()
        config.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
    }

    func load() {
        webView.loadHTMLString(html, baseURL: URL(string: origin + "/"))
        watchdog = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(25))
            guard !Task.isCancelled, let self, self.valid, !self.ready else { return }
            self.onError?(LocalizedText("YouTube is loading slowly or the network is blocking it. Reload, or open the video in your browser.", "YouTube 加载较慢或被网络阻止。可点“重新载入”，或在浏览器中打开。"))
        }
    }

    func invalidate() {
        valid = false
        watchdog?.cancel()
        webView.stopLoading()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "playerBridge")
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
    }

    func play() { command("playVideo") }
    func pause() { command("pauseVideo") }
    func seek(_ seconds: Double) { command("seekTo", arguments: [seconds, true]) }
    func rate(_ value: Double) { command("setPlaybackRate", arguments: [value]) }
    func volume(_ value: Double) { command("setVolume", arguments: [max(0, min(100, value * 100))]) }

    private func command(_ name: String, arguments: [Any] = []) {
        guard valid, ready,
              let data = try? JSONSerialization.data(withJSONObject: arguments),
              let encoded = String(data: data, encoding: .utf8) else { return }
        // Method names are constants supplied by this class, never user input.
        webView.evaluateJavaScript("window.axonTubeCommand('\(name)', \(encoded))", completionHandler: nil)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard valid, message.frameInfo.isMainFrame, message.name == "playerBridge",
              let body = message.body as? [String: Any], body["session"] as? String == sessionID,
              let kind = body["kind"] as? String else { return }
        switch kind {
        case "ready":
            ready = true
            watchdog?.cancel()
            onReady?()
        case "status":
            guard let time = body["time"] as? Double, time.isFinite, time >= 0,
                  let duration = body["duration"] as? Double, duration.isFinite, duration >= 0,
                  let state = body["state"] as? Int,
                  let rate = body["rate"] as? Double, rate.isFinite, rate > 0 else { return }
            let rates = (body["rates"] as? [Double] ?? [1]).filter { $0.isFinite && $0 > 0 && $0 <= 8 }
            onUpdate?(YouTubePlaybackState(time: time, duration: duration, state: state, rate: rate, rates: rates))
        case "error":
            watchdog?.cancel()
            let code = body["code"] as? Int ?? 0
            let reason: LocalizedText
            switch code {
            case 100: reason = LocalizedText("The video is unavailable, was removed, or requires an account.", "视频不存在、已删除，或需要账号访问。")
            case 101, 150: reason = LocalizedText("Embedded playback is unavailable (error \(code)). Check the message shown in the YouTube player.", "当前无法在内嵌播放器中播放（错误 \(code)）。请查看 YouTube 画面中的具体提示。")
            case 153: reason = LocalizedText("YouTube did not accept this player's app identity.", "YouTube 未接受此播放器的应用身份。")
            case 5: reason = LocalizedText("YouTube's web player cannot play this video.", "YouTube 的网页播放器无法播放此视频。")
            case 2: reason = LocalizedText("The YouTube video parameters are invalid.", "YouTube 视频参数无效。")
            default: reason = LocalizedText("YouTube playback failed (\(code)).", "YouTube 播放失败（\(code)）。")
            }
            onError?(reason + LocalizedText(" Use Open in Browser / Sign In to watch on YouTube.", " “在浏览器观看 / 登录”可打开原视频。"))
        case "autoplayBlocked":
            onError?(LocalizedText("Click the play button in the YouTube player to start.", "请直接点击 YouTube 画面上的播放按钮开始。"))
        default: break
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard valid else { decisionHandler(.cancel); return }
        // The wrapper stays at our own app origin. Google sign-in is never hosted here.
        if navigationAction.targetFrame?.isMainFrame == true {
            let url = navigationAction.request.url
            if url?.scheme == "about" || (url?.scheme == "https" && url?.host == "io.github.axonvoss-labs.axontube") {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                if navigationAction.navigationType == .linkActivated, let url { openBrowserLink(url) }
            }
        } else if let url = navigationAction.request.url, url.host == "accounts.google.com" {
            decisionHandler(.cancel)
            onError?(LocalizedText("Use Open in Browser to sign in. Browser sign-in does not sync to the embedded player.", "登录请使用“在浏览器观看”。浏览器的登录状态不会自动同步到内嵌播放器。"))
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url { openBrowserLink(url) }
        else { onError?(LocalizedText("Use Open in Browser to follow this link.", "此链接请通过“在浏览器观看”打开。")) }
        return nil
    }

    private func openBrowserLink(_ url: URL) {
        guard ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.user == nil, url.password == nil else { return }
        NSWorkspace.shared.open(url)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard valid, (error as NSError).code != NSURLErrorCancelled else { return }
        onError?(LocalizedText("YouTube network connection failed: ", "YouTube 网络连接失败：") + LocalizedText(error: error))
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        guard valid else { return }
        ready = false
        onError?(LocalizedText("The web playback process stopped. Select Reload.", "网页播放进程已退出，请点“重新载入”。"))
    }

    private var html: String {
        // videoID is restricted to 11 ASCII identifier characters by PlayerCore.
        """
        <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>html,body{margin:0;width:100%;height:100%;background:#000;overflow:hidden}#player{width:100%;height:100%;border:0}</style>
        </head><body><div id="player"></div><script>
        const session = '\(sessionID)'; let player; let ready = false;
        function send(kind, fields = {}) {
          window.webkit.messageHandlers.playerBridge.postMessage(Object.assign({session,kind},fields));
        }
        function status() {
          if (!ready || !player) return;
          send('status',{time:player.getCurrentTime() || 0,duration:player.getDuration() || 0,
            state:player.getPlayerState(),rate:player.getPlaybackRate() || 1,rates:player.getAvailablePlaybackRates() || [1]});
        }
        window.axonTubeCommand = function(name,args) {
          if (!ready || !player) return;
          const allowed = ['playVideo','pauseVideo','seekTo','setPlaybackRate','setVolume'];
          if (allowed.includes(name)) { player[name].apply(player,args); status(); }
        };
        function onYouTubeIframeAPIReady() {
          player = new YT.Player('player',{videoId:'\(link.videoID)',width:'100%',height:'100%',
            playerVars:{hl:'\(L10n.language.rawValue)',controls:1,playsinline:1,autoplay:0,start:\(Int(link.startTime)),origin:'\(origin)',rel:0},
            events:{onReady:()=>{ready=true;send('ready');status();},
              onStateChange:status,onPlaybackRateChange:status,
              onError:(e)=>send('error',{code:e.data}),onAutoplayBlocked:()=>send('autoplayBlocked')}});
        }
        setInterval(status,150);
        </script><script src="https://www.youtube.com/iframe_api"></script></body></html>
        """
    }
}

struct YouTubeSurface: NSViewRepresentable {
    let controller: YouTubeController
    func makeNSView(context: Context) -> WKWebView { controller.webView }
    func updateNSView(_ view: WKWebView, context: Context) {}
}
