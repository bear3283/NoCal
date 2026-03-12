/// MarkdownRenderer.swift
/// Phase 2: Real-time NSTextStorage styling for WYSIWYG markdown editing.
/// Renders headings, bold/italic, inline code, code blocks, checkboxes, tags, mentions.

import Foundation

// MARK: - Custom Attribute Key
extension NSAttributedString.Key {
    /// Value: "calendar" | "reminder" — marks a tappable date-link in the editor.
    static let noCalDateLink = NSAttributedString.Key("noCalDateLink")
}

#if os(iOS)
import UIKit
typealias MdFont  = UIFont
typealias MdColor = UIColor
private extension UIColor {
    static let mdForeground  = UIColor.label
    static let mdSecondary   = UIColor.secondaryLabel
    static let mdTertiary    = UIColor.tertiaryLabel
    static let mdTag         = UIColor.systemIndigo
    static let mdMention     = UIColor.systemBlue
    static let mdCodeFg      = UIColor.systemGreen
    static let mdCodeBg      = UIColor.systemGray6
    static let mdHeading     = UIColor.label
    static let mdHighlight   = UIColor.systemYellow.withAlphaComponent(0.35)
    static let mdQuoteBg     = UIColor.systemGray6.withAlphaComponent(0.5)
    static let mdCalLink     = UIColor.systemTeal           // @날짜 → 캘린더 이벤트
    static let mdRemLink     = UIColor.systemOrange         // !날짜 → 미리알림
}
#else
import AppKit
typealias MdFont  = NSFont
typealias MdColor = NSColor
private extension NSColor {
    static let mdForeground  = NSColor.labelColor
    static let mdSecondary   = NSColor.secondaryLabelColor
    static let mdTertiary    = NSColor.tertiaryLabelColor
    static let mdTag         = NSColor.systemIndigo
    static let mdMention     = NSColor.systemBlue
    static let mdCodeFg      = NSColor.systemGreen
    static let mdCodeBg      = NSColor.unemphasizedSelectedContentBackgroundColor
    static let mdHeading     = NSColor.labelColor
    static let mdHighlight   = NSColor.systemYellow.withAlphaComponent(0.35)
    static let mdQuoteBg     = NSColor.unemphasizedSelectedContentBackgroundColor.withAlphaComponent(0.6)
    static let mdCalLink     = NSColor.systemTeal           // @날짜 → 캘린더 이벤트
    static let mdRemLink     = NSColor.systemOrange         // !날짜 → 미리알림
}
#endif

// MARK: - MarkdownRenderer
final class MarkdownRenderer {

    static let shared = MarkdownRenderer()
    private init() {}

    /// Apply markdown styling to an NSTextStorage in place.
    /// Safe to call from textStorage(_:didProcessEditing:) or textViewDidChange.
    /// - Parameter registeredLinks: 이미 등록된 날짜링크 원문 집합 — 해당 링크는 dim+체크 스타일 적용
    func style(_ storage: NSTextStorage, baseFont: MdFont, registeredLinks: Set<String> = []) {
        let text     = storage.string
        let nsText   = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        guard fullRange.length > 0 else { return }

        // ── 1. Reset to base ──────────────────────────────────────────────
        storage.setAttributes([
            .font:                 baseFont,
            .foregroundColor:      MdColor.mdForeground,
            .backgroundColor:      MdColor.clear,
            .strikethroughStyle:   0,
            .underlineStyle:       0,
            .paragraphStyle:       defaultParagraph()
        ], range: fullRange)

        // ── 2. Line-level rules ───────────────────────────────────────────
        applyLineRules(storage, nsText: nsText, baseFont: baseFont)

        // ── 3. Inline rules ───────────────────────────────────────────────
        applyInlineRules(storage, text: text, baseFont: baseFont)

        // ── 4. 등록 완료 날짜링크 dim 처리 ───────────────────────────────
        if !registeredLinks.isEmpty {
            applyRegisteredLinkStyles(storage, text: text, registeredLinks: registeredLinks)
        }
    }

    // MARK: - Line Rules
    private func applyLineRules(_ storage: NSTextStorage, nsText: NSString, baseFont: MdFont) {
        var location = 0
        let lines = (nsText as String).components(separatedBy: "\n")

        for line in lines {
            let lineLen   = (line as NSString).length
            let lineRange = NSRange(location: location, length: lineLen)

            if line.hasPrefix("# ") {
                let f = MdFont.systemFont(ofSize: baseFont.pointSize + 10, weight: .bold)
                storage.addAttributes([.font: f, .foregroundColor: MdColor.mdHeading], range: lineRange)

            } else if line.hasPrefix("## ") {
                let f = MdFont.systemFont(ofSize: baseFont.pointSize + 6, weight: .bold)
                storage.addAttributes([.font: f, .foregroundColor: MdColor.mdHeading], range: lineRange)

            } else if line.hasPrefix("### ") {
                let f = MdFont.systemFont(ofSize: baseFont.pointSize + 3, weight: .semibold)
                storage.addAttributes([.font: f], range: lineRange)

            } else if line.hasPrefix("#### ") {
                let f = MdFont.systemFont(ofSize: baseFont.pointSize + 1, weight: .semibold)
                storage.addAttributes([.font: f], range: lineRange)

            } else if line.lowercased().hasPrefix("- [x]") {
                // Completed checkbox ─ dim + strikethrough
                storage.addAttributes([
                    .foregroundColor:    MdColor.mdSecondary,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: MdColor.mdSecondary
                ], range: lineRange)
                // Re-color the "[x]" marker in accent
                let markerRange = NSRange(location: location, length: min(5, lineLen))
                storage.addAttributes([.foregroundColor: MdColor.mdTag], range: markerRange)

            } else if line.hasPrefix("- [ ]") {
                // Unchecked checkbox ─ accent marker
                let markerRange = NSRange(location: location, length: min(5, lineLen))
                storage.addAttributes([
                    .foregroundColor: MdColor.mdTag,
                    .font: MdFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
                ], range: markerRange)

            } else if line.hasPrefix("- ") && !line.hasPrefix("- [ ]") && !line.lowercased().hasPrefix("- [x]") {
                // 일반 불릿 목록
                storage.addAttributes([.paragraphStyle: bulletParagraph()], range: lineRange)
                let markerRange = NSRange(location: location, length: min(2, lineLen))
                storage.addAttributes([.foregroundColor: MdColor.mdTag], range: markerRange)

            } else if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil {
                // 번호 목록
                storage.addAttributes([.paragraphStyle: bulletParagraph()], range: lineRange)
                if let r = line.range(of: #"^\d+\."#, options: .regularExpression) {
                    let markerLen = line.distance(from: line.startIndex, to: r.upperBound)
                    let markerRange = NSRange(location: location, length: markerLen)
                    storage.addAttributes([
                        .foregroundColor: MdColor.mdTag,
                        .font: MdFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
                    ], range: markerRange)
                }

            } else if line.hasPrefix("> ") {
                // Block quote ─ italic + secondary + tinted background
                storage.addAttributes([
                    .foregroundColor: MdColor.mdSecondary,
                    .font: italicFont(size: baseFont.pointSize),
                    .paragraphStyle: quoteParagraph(),
                    .backgroundColor: MdColor.mdQuoteBg
                ], range: lineRange)

            } else if line == "---" || line == "___" || line == "***" {
                // Horizontal rule ─ tinted secondary
                storage.addAttributes([
                    .foregroundColor: MdColor.mdTertiary,
                    .font: MdFont.systemFont(ofSize: baseFont.pointSize - 2, weight: .light)
                ], range: lineRange)
            }

            location += lineLen + 1 // account for "\n"
        }
    }

    // MARK: - Inline Rules
    private func applyInlineRules(_ storage: NSTextStorage, text: String, baseFont: MdFont) {

        // Code blocks ── triple backtick (apply before inline code to avoid overlap)
        match(#"```[\s\S]*?```"#, in: text, options: .dotMatchesLineSeparators) { r in
            let mono = MdFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
            storage.addAttributes([.font: mono, .foregroundColor: MdColor.mdCodeFg], range: r)
        }

        // Inline code ─ single backtick
        match(#"`[^`\n]+`"#, in: text) { r in
            let mono = MdFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
            storage.addAttributes([
                .font:            mono,
                .foregroundColor: MdColor.mdCodeFg,
                .backgroundColor: MdColor.mdCodeBg
            ], range: r)
        }

        // Bold-italic ─ ***text***
        match(#"\*{3}(.+?)\*{3}"#, in: text) { r in
            storage.addAttributes([.font: boldItalicFont(size: baseFont.pointSize)], range: r)
        }

        // Bold ─ **text**
        match(#"\*{2}(.+?)\*{2}"#, in: text) { r in
            storage.addAttributes([.font: MdFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)], range: r)
        }

        // Italic ─ _text_
        match(#"(?<![*_])_(?!_)(.+?)(?<!_)_(?![*_])"#, in: text) { r in
            storage.addAttributes([.font: italicFont(size: baseFont.pointSize)], range: r)
        }

        // Strikethrough ─ ~~text~~
        match(#"~~(.+?)~~"#, in: text) { r in
            storage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor:    MdColor.mdSecondary
            ], range: r)
        }

        // Highlight ─ ==text==
        match(#"==(.+?)=="#, in: text) { r in
            storage.addAttributes([
                .backgroundColor: MdColor.mdHighlight
            ], range: r)
        }

        // Tags ─ #word (not inside URLs or other words)
        match(#"(?<![/\w])#([가-힣\w]+)"#, in: text) { r in
            storage.addAttributes([
                .foregroundColor: MdColor.mdTag,
                .font:            MdFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
            ], range: r)
        }

        // Mentions ─ @word (not date links)
        match(#"(?<!\w)@(?!\d{4}-\d{2}-\d{2})(\w+)"#, in: text) { r in
            storage.addAttributes([
                .foregroundColor: MdColor.mdMention,
                .font:            MdFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
            ], range: r)
        }

        // Calendar date links ─ @YYYY-MM-DD or @YYYY-MM-DD HH:MM
        match(#"@\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?"#, in: text) { r in
            storage.addAttributes([
                .foregroundColor: MdColor.mdCalLink,
                .underlineStyle:  NSUnderlineStyle.single.rawValue,
                .noCalDateLink:   "calendar"
            ], range: r)
        }

        // Reminder date links ─ !YYYY-MM-DD or !YYYY-MM-DD HH:MM
        match(#"!\d{4}-\d{2}-\d{2}(?:\s+\d{1,2}:\d{2})?"#, in: text) { r in
            storage.addAttributes([
                .foregroundColor: MdColor.mdRemLink,
                .underlineStyle:  NSUnderlineStyle.single.rawValue,
                .noCalDateLink:   "reminder"
            ], range: r)
        }
    }

    // MARK: - Registered Link Styles
    /// 이미 캘린더/미리알림에 등록된 날짜링크를 dim + ✓ 접두로 표시
    private func applyRegisteredLinkStyles(
        _ storage: NSTextStorage, text: String, registeredLinks: Set<String>
    ) {
        for link in registeredLinks {
            // link 원문 그대로 텍스트에서 찾아 스타일 적용
            let escaped = NSRegularExpression.escapedPattern(for: link)
            guard let regex = try? NSRegularExpression(pattern: escaped) else { continue }
            let nsText = text as NSString
            let range  = NSRange(location: 0, length: nsText.length)
            for m in regex.matches(in: text, range: range) {
                storage.addAttributes([
                    .foregroundColor: MdColor.mdTertiary,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: MdColor.mdTertiary,
                    .noCalDateLink:      "registered"     // 탭 시 중복 시트 방지용 마커
                ], range: m.range)
            }
        }
    }

    // MARK: - Regex Helper
    private func match(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [],
        apply: (NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let nsText = text as NSString
        let range  = NSRange(location: 0, length: nsText.length)
        for m in regex.matches(in: text, options: [], range: range) {
            apply(m.range)
        }
    }

    // MARK: - Paragraph Helpers
    private func defaultParagraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 4
        return p
    }

    private func quoteParagraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.headIndent    = 16
        p.firstLineHeadIndent = 16
        p.lineSpacing   = 4
        return p
    }

    private func bulletParagraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.headIndent          = 16
        p.firstLineHeadIndent = 4
        p.lineSpacing         = 3
        return p
    }

    // MARK: - Font Helpers
    private func italicFont(size: CGFloat) -> MdFont {
        #if os(iOS)
        return UIFont.italicSystemFont(ofSize: size)
        #else
        let desc = NSFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: desc, size: size) ?? NSFont.systemFont(ofSize: size)
        #endif
    }

    private func boldItalicFont(size: CGFloat) -> MdFont {
        #if os(iOS)
        let traits: UIFontDescriptor.SymbolicTraits = [.traitBold, .traitItalic]
        if let desc = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: desc, size: size)
        }
        return UIFont.boldSystemFont(ofSize: size)
        #else
        let desc = NSFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits([.bold, .italic])
        return NSFont(descriptor: desc, size: size) ?? NSFont.boldSystemFont(ofSize: size)
        #endif
    }
}
