import SwiftUI
import PlayerCore

struct YouTubeLinkSheet: View {
    @ObservedObject var model: PlayerModel
    @AppStorage(L10n.preferenceKey) private var interfaceLanguage = AppLanguage.english.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var validationMessage: LocalizedText?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(L10n.text("Open YouTube", "打开 YouTube"), systemImage: "play.rectangle.fill").font(.title2.bold())
            TextField("https://www.youtube.com/watch?v=…", text: $input)
                .textFieldStyle(.roundedBorder).focused($inputFocused)
                .accessibilityLabel(L10n.text("YouTube video URL", "YouTube 视频链接"))
                .onSubmit(openVideo)
            Text(L10n.text("English + Traditional Chinese subtitles download automatically in about 1–2 minutes.", "英语和繁体中文字幕会自动下载，约需 1–2 分钟。"))
                .font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
            if let validationMessage { Text(validationMessage.text).font(.system(size: 12)).foregroundStyle(.orange) }
            HStack {
                Spacer()
                Button(L10n.text("Cancel", "取消"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L10n.text("Play in AxonTube", "在应用内播放"), action: openVideo)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(26).frame(width: 620)
            .environment(\.locale, Locale(identifier: interfaceLanguage))
            .environment(\.layoutDirection, L10n.language.isRightToLeft ? .rightToLeft : .leftToRight)
            .onAppear { inputFocused = true }
    }

    private func openVideo() {
        do {
            model.openYouTube(try YouTubeLink.parse(input))
            dismiss()
        } catch { validationMessage = LocalizedText(error: error) }
    }
}
