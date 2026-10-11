import AppKit
import UniformTypeIdentifiers
import PlayerCore

/// Keeps the native save panel's filename, type and explanation in sync.
@MainActor
final class SubtitleExportFormatPicker: NSObject {
    let view: NSView
    private let popup: NSPopUpButton
    private weak var panel: NSSavePanel?
    private let snapshot: SubtitleExportSnapshot
    private(set) var format: SubtitleExportFormat = .srt

    init(panel: NSSavePanel, snapshot: SubtitleExportSnapshot) {
        self.panel = panel
        self.snapshot = snapshot
        view = NSView(frame: NSRect(x: 0, y: 0, width: 430, height: 46))
        popup = NSPopUpButton(frame: .zero, pullsDown: false)
        super.init()
        let label = NSTextField(labelWithString: L10n.text("File format:", "文件格式："))
        popup.addItems(withTitles: SubtitleExportFormat.allCases.map(\.displayName))
        popup.setAccessibilityLabel(L10n.text("Export file format", "导出文件格式"))
        popup.target = self
        popup.action = #selector(formatChanged(_:))
        let stack = NSStackView(views: [label, popup])
        stack.orientation = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            popup.widthAnchor.constraint(equalToConstant: 260)
        ])
        apply(name: snapshot.suggestedName(for: format))
    }

    @objc private func formatChanged(_ sender: NSPopUpButton) {
        guard SubtitleExportFormat.allCases.indices.contains(sender.indexOfSelectedItem), let panel else { return }
        var name = panel.nameFieldStringValue
        let ext = (name as NSString).pathExtension.lowercased()
        if SubtitleExportFormat(rawValue: ext) != nil { name = (name as NSString).deletingPathExtension }
        format = SubtitleExportFormat.allCases[sender.indexOfSelectedItem]
        apply(name: name.isEmpty ? snapshot.suggestedName(for: format) : name + "." + format.rawValue)
    }

    private func apply(name: String) {
        guard let panel else { return }
        panel.allowedContentTypes = [UTType(filenameExtension: format.rawValue) ?? .data]
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = false
        // Set the name after the type to avoid NSSavePanel appending a second extension.
        panel.nameFieldStringValue = name
        panel.message = snapshot.explanation(for: format)
    }
}
