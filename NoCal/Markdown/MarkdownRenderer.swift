/// MarkdownRenderer.swift
/// Phase 2: Real-time NSTextStorage styling for WYSIWYG markdown editing.
/// Renders headings, bold/italic, inline code, code blocks, checkboxes, tags, mentions.

import Foundation

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
}
#endif

// MARK: - MarkdownRenderer
final class MarkdownRenderer {

    static let shared = MarkdownRenderer()
    private init() {}

    /// Apply markdown styling to an NSTextStorage in place.
    /// Safe to call from textStorage(_:didProcessEditing:) or textViewDidChange.
    func style(_ storage: NSTextStorage, baseFont: MdFont) {
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

            } else if line.hasPrefix("> ") {
                // Block quote ─ italic + secondary
                storage.addAttributes([
                    .foregroundColor: MdColor.mdSecondary,
                    .font: italicFont(size: baseFont.pointSize),
                    .paragraphStyle: quoteParagraph()
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

        // Tags ─ #word (not inside URLs or other words)
        match(#"(?<![/\w])#([가-힣\w]+)"#, in: text) { r in
            storage.addAttributes([
                .foregroundColor: MdColor.mdTag,
                .font:            MdFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
            ], range: r)
        }

        // Mentions ─ @word
        match(#"(?<!\w)@(\w+)"#, in: text) { r in
            storage.addAttributes([
                .foregroundColor: MdColor.mdMention,
                .font:            MdFont.systemFont(ofSize: baseFont.pointSize, weight: .medium)
            ], range: r)
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
