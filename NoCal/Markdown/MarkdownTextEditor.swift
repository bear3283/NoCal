/// MarkdownTextEditor.swift
/// Phase 2: Cross-platform UIViewRepresentable / NSViewRepresentable
/// wrapping UITextView / NSTextView with real-time markdown styling.
/// Supports: live syntax highlighting, checkbox tap-to-toggle, auto-continuation.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - iOS
// ─────────────────────────────────────────────────────────────────────────────
#if os(iOS)
import UIKit

struct MarkdownTextEditor: UIViewRepresentable {

    @Binding var text: String
    var baseFont: UIFont = .preferredFont(forTextStyle: .body)
    var onHeightChange: ((CGFloat) -> Void)? = nil

    // MARK: Make
    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate             = context.coordinator
        tv.isEditable           = true
        tv.isScrollEnabled      = true
        tv.backgroundColor      = .clear
        tv.font                 = baseFont
        tv.textContainerInset   = UIEdgeInsets(top: 8, left: 4, bottom: 40, right: 4)
        tv.keyboardDismissMode  = .interactive

        // Auto-correct: keep spell check, disable smart quotes/dashes for markdown
        tv.autocorrectionType               = .yes
        tv.smartQuotesType                  = .no
        tv.smartDashesType                  = .no

        // Tap gesture to handle checkbox toggle
        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        tv.addGestureRecognizer(tap)

        return tv
    }

    // MARK: Update
    func updateUIView(_ tv: UITextView, context: Context) {
        guard tv.text != text, !context.coordinator.isEditing else { return }
        let sel = tv.selectedRange
        tv.text = text
        context.coordinator.applyMarkdown(to: tv)
        let safe = NSRange(
            location: min(sel.location, tv.text.utf16.count),
            length:   0
        )
        tv.selectedRange = safe
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordinator
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {

        var parent: MarkdownTextEditor
        var isEditing   = false
        var isStyling   = false

        init(_ parent: MarkdownTextEditor) { self.parent = parent }

        // ── Lifecycle ─────────────────────────────────────────────────────
        func textViewDidBeginEditing(_ tv: UITextView) { isEditing = true }
        func textViewDidEndEditing(_ tv: UITextView)   { isEditing = false }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            applyMarkdown(to: tv)
        }

        // ── Smart continuation (Return key behaviour) ──────────────────────
        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }

            let nsText    = tv.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let line      = nsText.substring(with: lineRange)

            // Unchecked checkbox → new unchecked item
            if line.hasPrefix("- [ ] ") || line == "- [ ]\n" {
                let content = String(line.dropFirst(6)).trimmingCharacters(in: .newlines)
                let insert  = content.isEmpty ? "" : "\n- [ ] "
                tv.replace(tv.textRange(
                    from: tv.position(from: tv.beginningOfDocument, offset: range.location)!,
                    to:   tv.position(from: tv.beginningOfDocument, offset: range.location)!
                )!, withText: insert.isEmpty ? "\n" : insert)
                if !insert.isEmpty {
                    parent.text = tv.text
                    applyMarkdown(to: tv)
                    return false
                }
                return true
            }

            // Bullet → new bullet
            if line.hasPrefix("- ") && !line.hasPrefix("- [") {
                let content = String(line.dropFirst(2)).trimmingCharacters(in: .newlines)
                if !content.isEmpty {
                    let ins = "\n- "
                    tv.replace(tv.textRange(
                        from: tv.position(from: tv.beginningOfDocument, offset: range.location)!,
                        to:   tv.position(from: tv.beginningOfDocument, offset: range.location)!
                    )!, withText: ins)
                    parent.text = tv.text
                    applyMarkdown(to: tv)
                    return false
                }
            }

            return true
        }

        // ── Styling ────────────────────────────────────────────────────────
        func applyMarkdown(to tv: UITextView) {
            guard !isStyling else { return }
            isStyling = true
            defer { isStyling = false }

            let sel = tv.selectedRange
            tv.textStorage.beginEditing()
            MarkdownRenderer.shared.style(tv.textStorage, baseFont: parent.baseFont)
            tv.textStorage.endEditing()
            // Clamp selection
            let length = tv.textStorage.length
            tv.selectedRange = NSRange(
                location: min(sel.location, length),
                length:   min(sel.length, max(0, length - sel.location))
            )
        }

        // ── Checkbox tap ───────────────────────────────────────────────────
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let tv = gesture.view as? UITextView else { return }
            let pt = gesture.location(in: tv)

            // Convert to text container space
            let offset = tv.textContainerInset
            let adjPt  = CGPoint(x: pt.x - offset.left, y: pt.y - offset.top)

            var frac: CGFloat = 0
            let idx = tv.layoutManager.characterIndex(
                for: adjPt,
                in:  tv.textContainer,
                fractionOfDistanceBetweenInsertionPoints: &frac
            )
            guard idx < tv.text.count else { return }

            let nsText    = tv.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: idx, length: 0))
            let line      = nsText.substring(with: lineRange)

            toggleCheckbox(line: line, lineRange: lineRange, in: tv)
        }

        private func toggleCheckbox(line: String, lineRange: NSRange, in tv: UITextView) {
            let lower = line.lowercased()
            var replacement: String?

            if line.hasPrefix("- [ ]") {
                replacement = "- [x]" + line.dropFirst(5)
            } else if lower.hasPrefix("- [x]") {
                replacement = "- [ ]" + line.dropFirst(5)
            }

            guard let rep = replacement else { return }
            let nsText = tv.text as NSString
            let newText = nsText.replacingCharacters(in: lineRange, with: rep)
            tv.text   = newText
            parent.text = newText
            applyMarkdown(to: tv)
        }

        // Allow simultaneous gesture recognition (don't block text taps)
        func gestureRecognizer(
            _ gr: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - macOS
// ─────────────────────────────────────────────────────────────────────────────
#else
import AppKit

struct MarkdownTextEditor: NSViewRepresentable {

    @Binding var text: String
    var baseFont: NSFont = .preferredFont(forTextStyle: .body)
    var onHeightChange: ((CGFloat) -> Void)? = nil

    // MARK: Make
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let tv = scrollView.documentView as? NSTextView else { return scrollView }

        tv.delegate             = context.coordinator
        tv.isEditable           = true
        tv.isRichText           = false   // we manage attributes ourselves
        tv.font                 = baseFont
        tv.backgroundColor      = .clear
        tv.drawsBackground      = false
        tv.textContainerInset   = NSSize(width: 4, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled  = false
        tv.isAutomaticDashSubstitutionEnabled   = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.allowsUndo           = true

        // Click for checkbox toggle
        let click = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleClick(_:))
        )
        tv.addGestureRecognizer(click)

        return scrollView
    }

    // MARK: Update
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? NSTextView else { return }
        guard tv.string != text, !context.coordinator.isEditing else { return }
        let sel = tv.selectedRanges
        tv.string = text
        context.coordinator.applyMarkdown(to: tv)
        tv.selectedRanges = sel
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: Coordinator
    final class Coordinator: NSObject, NSTextViewDelegate {

        var parent: MarkdownTextEditor
        var isEditing = false
        var isStyling = false

        init(_ parent: MarkdownTextEditor) { self.parent = parent }

        // ── Lifecycle ─────────────────────────────────────────────────────
        func textDidBeginEditing(_ n: Notification) { isEditing = true }
        func textDidEndEditing(_ n: Notification)   { isEditing = false }

        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            parent.text = tv.string
            applyMarkdown(to: tv)
        }

        // ── Smart continuation ─────────────────────────────────────────────
        func textView(_ tv: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }

            let nsText    = tv.string as NSString
            guard let selRange = tv.selectedRanges.first as? NSRange else { return false }
            let lineRange = nsText.lineRange(for: NSRange(location: selRange.location, length: 0))
            let line      = nsText.substring(with: lineRange)

            if line.hasPrefix("- [ ] ") || line == "- [ ]\n" {
                let content = String(line.dropFirst(6)).trimmingCharacters(in: .newlines)
                if !content.isEmpty {
                    tv.insertText("\n- [ ] ", replacementRange: selRange)
                    parent.text = tv.string
                    applyMarkdown(to: tv)
                    return true
                }
            }
            if line.hasPrefix("- ") && !line.hasPrefix("- [") {
                let content = String(line.dropFirst(2)).trimmingCharacters(in: .newlines)
                if !content.isEmpty {
                    tv.insertText("\n- ", replacementRange: selRange)
                    parent.text = tv.string
                    applyMarkdown(to: tv)
                    return true
                }
            }
            return false
        }

        // ── Styling ────────────────────────────────────────────────────────
        func applyMarkdown(to tv: NSTextView) {
            guard !isStyling, let storage = tv.textStorage else { return }
            isStyling = true
            defer { isStyling = false }

            let sel = tv.selectedRanges
            storage.beginEditing()
            MarkdownRenderer.shared.style(storage, baseFont: parent.baseFont)
            storage.endEditing()
            tv.selectedRanges = sel
        }

        // ── Checkbox click ─────────────────────────────────────────────────
        @objc func handleClick(_ gesture: NSClickGestureRecognizer) {
            guard let tv = gesture.view as? NSTextView,
                  let lm = tv.layoutManager,
                  let tc = tv.textContainer else { return }

            let pt      = gesture.location(in: tv)
            let inset   = tv.textContainerInset
            let adjPt   = NSPoint(x: pt.x - inset.width, y: pt.y - inset.height)
            let idx     = lm.characterIndex(for: adjPt, in: tc, fractionOfDistanceBetweenInsertionPoints: nil)

            let nsText    = tv.string as NSString
            guard idx < nsText.length else { return }
            let lineRange = nsText.lineRange(for: NSRange(location: idx, length: 0))
            let line      = nsText.substring(with: lineRange)

            toggleCheckbox(line: line, lineRange: lineRange, in: tv)
        }

        private func toggleCheckbox(line: String, lineRange: NSRange, in tv: NSTextView) {
            let lower = line.lowercased()
            var replacement: String?
            if line.hasPrefix("- [ ]") {
                replacement = "- [x]" + line.dropFirst(5)
            } else if lower.hasPrefix("- [x]") {
                replacement = "- [ ]" + line.dropFirst(5)
            }
            guard let rep = replacement, let storage = tv.textStorage else { return }
            storage.replaceCharacters(in: lineRange, with: rep)
            parent.text = tv.string
            applyMarkdown(to: tv)
        }
    }
}

// macOS: NSFont.preferredFont shim (maps UIKit style to AppKit)
private extension NSFont {
    static func preferredFont(forTextStyle style: NSFont.TextStyleShim) -> NSFont {
        return NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }
    enum TextStyleShim { case body }
}
#endif
