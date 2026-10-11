import Foundation
import PlayerCore

enum SubtitleExportFormat: String, CaseIterable, Sendable {
    case srt, docx, txt

    var displayName: String {
        switch self {
        case .srt: return L10n.text("SRT Subtitles (.srt)", "SRT 字幕 (.srt)")
        case .docx: return L10n.text("Word Document (.docx)", "Word 文档 (.docx)")
        case .txt: return L10n.text("Plain Text (.txt)", "纯文本 (.txt)")
        }
    }
}

enum PlayerSubtitleExportError: BilingualError {
    case preparing, empty, destination, sourceFile

    var message: LocalizedText {
        switch self {
        case .preparing: return LocalizedText("Subtitles are being grouped. Export will be available when ready.", "字幕正在按句整理，完成后即可导出。")
        case .empty: return LocalizedText("No subtitles to export. Load subtitles or wait for a finalized live caption.", "暂无可导出的字幕。请先载入字幕，或等待实时听写完成至少一句。")
        case .destination: return LocalizedText("Choose a local file with the matching extension: .srt, .docx, or .txt.", "请选择本机文件，并使用所选格式的扩展名（.srt、.docx 或 .txt）。")
        case .sourceFile: return LocalizedText("Choose a new filename. Export cannot overwrite source subtitles, caption caches, or media.", "请使用新的文件名。导出不能覆盖当前的原字幕、字幕缓存或视频文件。")
        }
    }
}

struct SubtitleExportSnapshot: Sendable {
    struct FileOutput: Sendable {
        let data: Data
        let cueCount: Int
    }

    let primary: SubtitleTrack
    let secondary: SubtitleTrack
    let primaryOffset: Double
    let secondaryOffset: Double
    let sourceURLs: [URL]
    let suggestedName: String
    let isLive: Bool

    var explanation: String {
        let scope = isLive
            ? L10n.text("Save finalized captions and existing translations. Drafts and pending translations are excluded.", "保存此刻已完成的听写及已有译文；正在修订或尚未生成的内容不包含在内。")
            : L10n.text("Export all loaded subtitles with the current grouping and offsets, regardless of search, selected track, or visibility.", "导出全部已载入字幕，保留当前按句整理与时间偏移；搜索、选中轨道和画面隐藏不影响导出。")
        let languages = primary.cues.isEmpty || secondary.cues.isEmpty
            ? L10n.text("Only one track is loaded; the file will include its available content.", "当前只有一条字幕，文件将仅包含已有内容。")
            : L10n.text("Original above translation; tracks are combined using their timestamps.", "第一字幕在上、第二字幕在下；两轨按实际时间合并。")
        return scope + "\n" + languages
    }

    func explanation(for format: SubtitleExportFormat) -> String {
        guard format != .srt else { return explanation }
        return explanation + L10n.text("\nSave paired paragraphs and timestamps for reading or printing. Unmatched content is retained separately.", "\n按段落保存中英对照与时间标记，便于阅读和打印；未匹配内容单独保留。")
    }

    func suggestedName(for format: SubtitleExportFormat) -> String {
        (suggestedName as NSString).deletingPathExtension + "." + format.rawValue
    }

    func render() throws -> SubtitleExporter.Output {
        try SubtitleExporter.srt(primary: primary, secondary: secondary,
                                 primaryOffset: primaryOffset, secondaryOffset: secondaryOffset)
    }

    func render(format: SubtitleExportFormat) throws -> FileOutput {
        if format == .srt {
            let output = try render()
            return FileOutput(data: Data(output.text.utf8), cueCount: output.cueCount)
        }
        let base = (suggestedName as NSString).deletingPathExtension
        let title = (base.hasSuffix(".bilingual") ? String(base.dropLast(".bilingual".count)) : base) + L10n.text(" — Bilingual Subtitles", " 双语字幕")
        let output = try format == .docx
            ? SubtitleDocumentExporter.docx(primary: primary, secondary: secondary,
                primaryOffset: primaryOffset, secondaryOffset: secondaryOffset, title: title)
            : SubtitleDocumentExporter.txt(primary: primary, secondary: secondary,
                primaryOffset: primaryOffset, secondaryOffset: secondaryOffset, title: title)
        return FileOutput(data: output.data, cueCount: output.cueCount)
    }

    /// Atomic output preserves an existing destination if rendering fails.
    /// Protect source files even when selected through a symbolic link or alias path.
    @discardableResult
    func write(to url: URL, format: SubtitleExportFormat = .srt) throws -> FileOutput {
        guard url.isFileURL, url.pathExtension.lowercased() == format.rawValue, !url.hasDirectoryPath else {
            throw PlayerSubtitleExportError.destination
        }
        let output = try render(format: format)
        let destination = url.standardizedFileURL.resolvingSymlinksInPath()
        for source in sourceURLs where source.isFileURL {
            let original = source.standardizedFileURL.resolvingSymlinksInPath()
            if original == destination || Self.sameFile(original, destination) {
                throw PlayerSubtitleExportError.sourceFile
            }
        }
        try output.data.write(to: url, options: .atomic)
        return output
    }

    private static func sameFile(_ first: URL, _ second: URL) -> Bool {
        let keys: Set<URLResourceKey> = [.fileResourceIdentifierKey]
        guard let a = try? first.resourceValues(forKeys: keys).fileResourceIdentifier as? NSObject,
              let b = try? second.resourceValues(forKeys: keys).fileResourceIdentifier as? NSObject else { return false }
        return a.isEqual(b)
    }
}
