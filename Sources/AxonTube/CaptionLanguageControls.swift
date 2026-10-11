import SwiftUI
import PlayerCore

/// The two subtitle-language buttons stay visible in the study sidebar.
struct CaptionLanguageControls: View {
    @ObservedObject var model: PlayerModel
    let link: YouTubeLink?
    @AppStorage(L10n.preferenceKey) private var interfaceLanguage = AppLanguage.english.rawValue

    private var tracks: [YouTubeCaptionTrack] {
        guard let link, model.youtubeCaptions.catalogVideoID == link.videoID else { return [] }
        return model.youtubeCaptions.catalog
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            languageMenu(slot: 0)
            languageMenu(slot: 1)
        }
        .environment(\.locale, Locale(identifier: interfaceLanguage))
        .task(id: "\(link?.videoID ?? ""):\(model.isPreparingYouTubeCaptions)") {
            // A successful cache hit can lack the video's full language catalog.
            // Leave pending requests and failures alone; never hide their status.
            guard let link, !model.isPreparingYouTubeCaptions,
                  model.youtubeCaptions.error == nil,
                  model.slots.contains(where: { !$0.track.cues.isEmpty }),
                  model.youtubeCaptions.catalogVideoID != link.videoID,
                  model.youtubeCaptions.languageRequestVideoID != link.videoID else { return }
            model.youtubeCaptions.discoverLanguages(link: link)
        }
    }

    private func selection(slot: Int) -> String {
        slot == 0 ? model.primaryCaptionLanguage : model.secondaryCaptionLanguage
    }

    private func setLanguage(_ value: String, slot: Int) {
        if slot == 0 { model.primaryCaptionLanguage = value }
        else { model.secondaryCaptionLanguage = value }
    }

    private func selectedName(slot: Int) -> String {
        let value = selection(slot: slot)
        switch value {
        case "en": return "English"
        case "zh-Hant": return "繁體中文"
        case "zh-Hans": return "简体中文"
        default:
            let code = tracks.first(where: { $0.id == value })?.languageCode ?? value
            return Locale(identifier: interfaceLanguage).localizedString(forIdentifier: code) ?? code
        }
    }

    private func choice(_ title: String, value: String, slot: Int) -> some View {
        Button { setLanguage(value, slot: slot) } label: {
            if selection(slot: slot) == value { Label(title, systemImage: "checkmark") }
            else { Text(title) }
        }
    }

    private func languageMenu(slot: Int) -> some View {
        let title = slot == 0 ? L10n.text("First subtitle", "第一字幕") : L10n.text("Second subtitle", "第二字幕")
        return VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            Menu {
                choice("English", value: "en", slot: slot)
                choice("繁體中文", value: "zh-Hant", slot: slot)
                choice("简体中文", value: "zh-Hans", slot: slot)
                if !tracks.isEmpty {
                    Divider()
                    ForEach(tracks, id: \.id) { track in
                        choice(track.displayName, value: track.id, slot: slot)
                    }
                }
            } label: {
                Text(selectedName(slot: slot)).lineLimit(1)
                    .font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderedButton).controlSize(.large)
            .tint(slot == 0 ? Color(red: 0.39, green: 0.88, blue: 0.72) : Color(red: 0.98, green: 0.78, blue: 0.45))
            .frame(maxWidth: .infinity)
            .accessibilityLabel(title)
            .accessibilityIdentifier(slot == 0 ? "primary-caption-language" : "secondary-caption-language")
            .help(selectedName(slot: slot))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
