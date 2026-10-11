import Foundation

/// A display/practice view of the original cues. Boundaries use whole source cues;
/// neither word timings nor semantic alignment are inferred.
public enum SubtitleSentenceBuilder {
    public struct Options: Sendable {
        public var maximumDuration: Double
        public var maximumEnglishCharacters: Int
        public var maximumGap: Double

        public init(maximumDuration: Double = 12, maximumEnglishCharacters: Int = 220,
                    maximumGap: Double = 1.2) {
            self.maximumDuration = maximumDuration
            self.maximumEnglishCharacters = maximumEnglishCharacters
            self.maximumGap = maximumGap
        }
    }

    public struct Group: Identifiable, Equatable, Sendable {
        public let id: Int
        public let start: Double
        public let end: Double
        public let englishCueIDs: [Int]
        public let chineseCueIDs: [Int]
    }

    public struct Result: Sendable {
        public let english: SubtitleTrack
        public let chinese: SubtitleTrack
        public let groups: [Group]
        /// These Chinese cues remain visible at their own source intervals.
        public let unmatchedChineseCueIDs: [Int]
    }

    /// Callers apply track offsets before building. Each track keeps its own shifted
    /// source interval; equal IDs identify pairs without moving the translation clock.
    /// English IDs and intervals depend only on English, so translations cannot move a loop.
    /// Cancellation returns an empty result; callers must discard cancelled work.
    public static func build(english: [SubtitleCue], chinese: [SubtitleCue], options: Options = .init()) -> Result {
        guard !Task.isCancelled else { return emptyResult }
        let maxDuration = options.maximumDuration.isFinite && options.maximumDuration > 0 ? options.maximumDuration : 12
        let maxCharacters = options.maximumEnglishCharacters > 0 ? options.maximumEnglishCharacters : 220
        let maxGap = options.maximumGap.isFinite && options.maximumGap >= 0 ? options.maximumGap : 1.2
        let atoms = normalizedAtoms(english)
        guard !Task.isCancelled else { return emptyResult }
        var sentences: [Sentence] = []
        var current: Sentence?

        for atom in atoms {
            guard !Task.isCancelled else { return emptyResult }
            if var sentence = current {
                let combined = join(sentence.text, atom.text)
                let mustBreak = isEvent(atom.text) || sentence.isEvent || hasSpeakerMarker(atom.text)
                    || atom.start - sentence.end > maxGap + 0.000_001
                    || max(sentence.end, atom.end) - sentence.start > maxDuration + 0.000_001
                    || combined.count > maxCharacters
                    || endsSentence(sentence.text, followedBy: atom.text)
                if mustBreak {
                    sentences.append(sentence)
                    current = Sentence(atom)
                } else {
                    sentence.end = max(sentence.end, atom.end)
                    sentence.text = combined
                    sentence.sourceIDs += atom.sourceIDs
                    current = sentence
                }
            } else {
                current = Sentence(atom)
            }
        }
        if let current { sentences.append(current) }
        guard !Task.isCancelled else { return emptyResult }

        let englishTrack = SubtitleTrack(cues: sentences.enumerated().map {
            SubtitleCue(id: $0.offset, start: $0.element.start, end: $0.element.end, text: $0.element.text)
        })
        var translations: [Int: [Atom]] = [:]
        var unmatched: [Atom] = []
        for atom in normalizedAtoms(chinese) {
            guard !Task.isCancelled else { return emptyResult }
            let candidates = englishTrack.overlappingCues(start: atom.start, end: atom.end)
            if let group = bestOverlap(for: atom, candidates: candidates) {
                translations[group.id, default: []].append(atom)
            } else {
                unmatched.append(atom)
            }
        }

        guard !Task.isCancelled else { return emptyResult }
        var translatedCues: [SubtitleCue] = []
        var groups: [Group] = []
        for (index, sentence) in sentences.enumerated() {
            guard !Task.isCancelled else { return emptyResult }
            let assigned = translations[index] ?? []
            if !assigned.isEmpty {
                let text = assigned.map(\.text).reduce("") { join($0, $1, preservingSpeakerBreak: true) }
                let start = assigned.map(\.start).min()!
                let end = assigned.map(\.end).max()!
                translatedCues.append(SubtitleCue(id: index, start: start, end: end, text: text))
            }
            groups.append(Group(id: index, start: sentence.start, end: sentence.end,
                                englishCueIDs: sentence.sourceIDs, chineseCueIDs: assigned.flatMap(\.sourceIDs)))
        }
        // No positive overlap means there is no justified English group to attach to.
        for (index, atom) in unmatched.enumerated() {
            guard !Task.isCancelled else { return emptyResult }
            translatedCues.append(SubtitleCue(id: sentences.count + index, start: atom.start, end: atom.end, text: atom.text))
        }
        return Result(english: englishTrack, chinese: SubtitleTrack(cues: translatedCues), groups: groups,
                      unmatchedChineseCueIDs: unmatched.flatMap(\.sourceIDs))
    }

    private static var emptyResult: Result {
        Result(english: SubtitleTrack(cues: []), chinese: SubtitleTrack(cues: []), groups: [], unmatchedChineseCueIDs: [])
    }

    /// Reflows soft whitespace. Explicit speaker/event lines retain a paragraph break.
    /// This does not change punctuation or join fragments by guessing missing words.
    public static func normalizedText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines).map { line in
            line.split(whereSeparator: \.isWhitespace).map(String.init).reduce("") { join($0, $1) }
        }.filter { !$0.isEmpty }
        var result = ""
        var previousLineWasEvent = false
        for line in lines {
            if !result.isEmpty && (hasSpeakerMarker(line) || isEvent(line) || previousLineWasEvent) {
                result += "\n" + line
            } else {
                result = join(result, line)
            }
            previousLineWasEvent = isEvent(line)
        }
        return result
    }

    private struct Atom {
        let start: Double
        var end: Double
        let text: String
        var sourceIDs: [Int]
    }

    private struct Sentence {
        let start: Double
        var end: Double
        var text: String
        var sourceIDs: [Int]
        let isEvent: Bool

        init(_ atom: Atom) {
            start = atom.start
            end = atom.end
            text = atom.text
            sourceIDs = atom.sourceIDs
            isEvent = SubtitleSentenceBuilder.isEvent(atom.text)
        }
    }

    private static func normalizedAtoms(_ cues: [SubtitleCue]) -> [Atom] {
        let ordered = cues.enumerated().filter {
            $0.element.start.isFinite && $0.element.end.isFinite && $0.element.start >= 0 && $0.element.end > $0.element.start
        }.sorted {
            if $0.element.start != $1.element.start { return $0.element.start < $1.element.start }
            if $0.element.end != $1.element.end { return $0.element.end < $1.element.end }
            return $0.offset < $1.offset
        }
        var atoms: [Atom] = []
        for (_, cue) in ordered {
            if Task.isCancelled { return [] }
            let text = normalizedText(cue.text)
            guard !text.isEmpty else { continue }
            if let last = atoms.last, last.start == cue.start, last.text == text {
                // Same anchor and complete text: duplicate record or duration update.
                // Different starts (even if overlapping) may be a genuinely repeated utterance.
                atoms[atoms.count - 1].end = max(last.end, cue.end)
                atoms[atoms.count - 1].sourceIDs.append(cue.id)
            } else {
                atoms.append(Atom(start: cue.start, end: cue.end, text: text, sourceIDs: [cue.id]))
            }
        }
        return atoms
    }

    private static func bestOverlap(for atom: Atom, candidates: [SubtitleCue]) -> SubtitleCue? {
        let midpoint = atom.start + (atom.end - atom.start) / 2
        var best: SubtitleCue?
        var bestDuration = -Double.infinity
        var bestContainsMidpoint = false
        var bestDistance = Double.infinity
        for candidate in candidates {
            if Task.isCancelled { return nil }
            let overlap = min(atom.end, candidate.end) - max(atom.start, candidate.start)
            let containsMidpoint = candidate.start <= midpoint && midpoint < candidate.end
            let distance = abs(midpoint - (candidate.start + (candidate.end - candidate.start) / 2))
            let tiedDuration = abs(overlap - bestDuration) < 0.000_001
            if overlap > bestDuration + 0.000_001
                || (tiedDuration && containsMidpoint && !bestContainsMidpoint)
                || (tiedDuration && containsMidpoint == bestContainsMidpoint && distance < bestDistance - 0.000_001) {
                best = candidate
                bestDuration = overlap
                bestContainsMidpoint = containsMidpoint
                bestDistance = distance
            }
        }
        return best
    }

    private static func join(_ left: String, _ right: String, preservingSpeakerBreak: Bool = false) -> String {
        guard let last = left.last else { return right }
        guard let first = right.first else { return left }
        if preservingSpeakerBreak && (hasSpeakerMarker(right) || isEvent(right) || isEvent(left)) { return left + "\n" + right }
        let closes = ",.;:!?%)]}，。！？；：、％）］｝】》」』”’…"
        let opens = "([{（［｛【《「『“‘"
        if closes.contains(first) || opens.contains(last) { return left + right }
        if isCJK(last) && isCJK(first) { return left + right }
        if last == ".", left.dropLast().last?.isNumber == true, first.isNumber { return left + right }
        if last == "-", left.dropLast().last?.isLetter == true, first.isLetter { return left + right }
        return left + " " + right
    }

    private static func isCJK(_ character: Character) -> Bool {
        character.unicodeScalars.contains {
            switch $0.value {
            // Hangul is deliberately excluded: Korean word spaces carry meaning.
            case 0x2E80...0x303F, 0x3040...0x30FF,
                 0x31F0...0x31FF, 0x3400...0x4DBF, 0x4E00...0x9FFF,
                 0xF900...0xFAFF, 0xFE30...0xFE4F, 0xFF01...0xFF60, 0x20000...0x323AF: return true
            default: return false
            }
        }
    }

    private static func endsSentence(_ text: String, followedBy next: String) -> Bool {
        var ending = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = ending.last, "\"'”’)]}）］｝】》」』".contains(last) { ending.removeLast() }
        guard let last = ending.last else { return false }
        if "!?。！？".contains(last) { return true }
        guard last == "." else { return false }
        if ending.hasSuffix("...") { return true }
        if ending.dropLast().last?.isNumber == true, next.first?.isNumber == true { return false }
        let token = ending.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
        let word = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“‘([{"))
        if continuingAbbreviations.contains(word.lowercased()) { return false }
        if abbreviations.contains(word.lowercased())
            || word.range(of: #"^(?:[A-Za-z]\.){2,}$"#, options: .regularExpression) != nil
            || (word.count == 2 && word.first?.isUppercase == true) {
            // "U.S." can be either mid-sentence or terminal. Only clear new-sentence
            // starters resolve this ambiguity; other cases remain grouped conservatively.
            let nextWord = next.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            return sentenceStarters.contains(nextWord)
        }
        return true
    }

    private static let continuingAbbreviations: Set<String> = [
        "mr.", "mrs.", "ms.", "dr.", "prof.", "st.", "mt.", "rev.", "gen.", "sgt.", "capt.",
        "vs.", "e.g.", "i.e.", "no.", "fig.", "dept.", "approx.",
        "jan.", "feb.", "mar.", "apr.", "jun.", "jul.", "aug.", "sep.", "sept.", "oct.", "nov.", "dec."
    ]

    private static let sentenceStarters: Set<String> = [
        "I", "We", "You", "He", "She", "It", "They", "This", "That", "These", "Those", "There", "Here",
        "The", "A", "An", "But", "And", "However", "Then", "Now", "After", "Before", "Today", "Tomorrow", "Yesterday"
    ]

    private static let abbreviations: Set<String> = [
        "mr.", "mrs.", "ms.", "dr.", "prof.", "sr.", "jr.", "st.", "mt.", "rev.",
        "gen.", "sgt.", "capt.", "vs.", "etc.", "e.g.", "i.e.", "a.m.", "p.m.",
        "no.", "fig.", "inc.", "ltd.", "co.", "dept.", "approx.", "est.",
        "jan.", "feb.", "mar.", "apr.", "jun.", "jul.", "aug.", "sep.", "sept.", "oct.", "nov.", "dec."
    ]

    private static func hasSpeakerMarker(_ text: String) -> Bool {
        if text.contains("\n") { return text.split(separator: "\n").contains { hasSpeakerMarker(String($0)) } }
        if text.hasPrefix(">>") || text.hasPrefix("- ") || text.hasPrefix("—") || text.hasPrefix("– ") { return true }
        if text.range(of: #"^\[[A-Za-z][A-Za-z .'’\-]{0,30}\]\s+\S"#, options: .regularExpression) != nil { return true }
        return text.range(of: #"^(?:[A-Z][A-Za-z .'’\-]{0,30}|[\p{Han}]{1,8})[:：]"#, options: .regularExpression) != nil
    }

    private static func isEvent(_ text: String) -> Bool {
        if text.contains("\n") { return text.split(separator: "\n").contains { isEvent(String($0)) } }
        if text.contains("♪") || text.contains("♫") { return true }
        if (text.hasPrefix("[") && text.hasSuffix("]")) || (text.hasPrefix("【") && text.hasSuffix("】")) { return true }
        return ["(music)", "(applause)", "(laughter)", "(silence)", "（音乐）", "（掌声）", "（笑声）"].contains(text.lowercased())
    }
}
