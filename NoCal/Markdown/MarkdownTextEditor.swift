/// MarkdownTextEditor.swift
/// Phase 6: Cursor-aware snippet insertion via NotificationCenter.
/// - NotificationCenter .noCalInsertSnippet → insert at cursor position
/// - Selection-wrap: bold/italic/etc wraps selected text
/// - Smart continuation: checkbox, bullet, numbered list auto-continue
/// - Checkbox tap/click to toggle [ ] ↔ [x]

import SwiftUI

// MARK: - Notification Name
extension Notification.Name {
    static let noCalInsertSnippet = Notification.Name("noCalInsertSnippet")
}

// MARK: - Shared snippet processing
/// Returns (processedSnippet, cursorOffsetFromInsertionPoint)
func processMarkdownSnippet(_ snippet: String, selected: String) -> (String, Int) {
    switch snippet {
    case "****":
        if !selected.isEmpty { return ("**\(selected)**", selected.utf16.count + 4) }
        return ("****", 2)
    case "__":
        if !selected.isEmpty { return ("_\(selected)_", selected.utf16.count + 2) }
        return ("__", 1)
    case "~~~~":
        if !selected.isEmpty { return ("~~\(selected)~~", selected.utf16.count + 4) }
        return ("~~~~", 2)
    case "====":
        if !selected.isEmpty { return ("==\(selected)==", selected.utf16.count + 4) }
        return ("====", 2)
    case "``":
        if !selected.isEmpty { return ("`\(selected)`", selected.utf16.count + 2) }
        return ("``", 1)
    case "\n```\n\n```":
        // Cursor lands inside the code block (after opening ``` newline)
        return ("\n```\n\n```", 5)
    case "[]()":
        if !selected.isEmpty {
            let r = "[\(selected)]()"
            return (r, selected.utf16.count + 3)  // cursor inside ()
        }
        return ("[]()", 1)  // cursor at offset 1 = inside []
    default:
        return (snippet, (snippet as NSString).length)
    }
}

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

        tv.autocorrectionType               = .yes
        tv.smartQuotesType                  = .no
        tv.smartDashesType                  = .no

        // Store reference for NotificationCenter-based insertion
        context.coordinator.textView = tv

        // Tap gesture for checkbox toggle
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
        context.coordinator.textView = tv
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
        weak var textView: UITextView?

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertSnippet(_:)),
                name: .noCalInsertSnippet,
                object: nil
            )
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        // ── Lifecycle ─────────────────────────────────────────────────────
        func textViewDidBeginEditing(_ tv: UITextView) { isEditing = true }
        func textViewDidEndEditing(_ tv: UITextView)   { isEditing = false }

        func textViewDidChange(_ tv: UITextView) {
            parent.text = tv.text
            applyMarkdown(to: tv)
        }

        // ── Snippet insertion (cursor-aware) ───────────────────────────────
        @objc private func handleInsertSnippet(_ notification: Notification) {
            guard let snippet = notification.object as? String,
                  let tv = textView else { return }
            DispatchQueue.main.async { self.insertAtCursor(snippet, in: tv) }
        }

        func insertAtCursor(_ snippet: String, in tv: UITextView) {
            let range = tv.selectedRange
            let nsText = tv.text as NSString
            let selectedText = range.length > 0 ? nsText.substring(with: range) : ""
            let (processed, cursorOffset) = processMarkdownSnippet(snippet, selected: selectedText)
            let newText = nsText.replacingCharacters(in: range, with: processed)
            tv.text = newText
            parent.text = newText
            let newLoc = min(range.location + cursorOffset, newText.utf16.count)
            tv.selectedRange = NSRange(location: newLoc, length: 0)
            applyMarkdown(to: tv)
        }

        // ── Smart continuation (Return key behaviour) ──────────────────────
        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }

            let nsText    = tv.text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: range.location, length: 0))
            let line      = nsText.substring(with: lineRange)

            func insertAtCursor(_ ins: String) -> Bool {
                guard let from = tv.position(from: tv.beginningOfDocument, offset: range.location),
                      let textRange = tv.textRange(from: from, to: from) else { return true }
                tv.replace(textRange, withText: ins)
                parent.text = tv.text
                applyMarkdown(to: tv)
                return false
            }

            // Unchecked checkbox
            if line.hasPrefix("- [ ] ") || line == "- [ ]\n" {
                let content = String(line.dropFirst(6)).trimmingCharacters(in: .newlines)
                return insertAtCursor(content.isEmpty ? "\n" : "\n- [ ] ")
            }

            // Bullet
            if line.hasPrefix("- ") && !line.hasPrefix("- [") {
                let content = String(line.dropFirst(2)).trimmingCharacters(in: .newlines)
                if !content.isEmpty {
                    return insertAtCursor("\n- ")
                }
            }

            // Numbered list
            if let r = line.range(of: #"^(\d+)\. "#, options: .regularExpression) {
                let numStr  = String(line[r]).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                let num     = (Int(numStr) ?? 0) + 1
                let content = String(line.dropFirst(line.distance(from: line.startIndex, to: r.upperBound)))
                    .trimmingCharacters(in: .newlines)
                return insertAtCursor(content.isEmpty ? "\n" : "\n\(num). ")
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
        tv.isRichText           = false
        tv.font                 = baseFont
        tv.backgroundColor      = .clear
        tv.drawsBackground      = false
        tv.textContainerInset   = NSSize(width: 4, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled  = false
        tv.isAutomaticDashSubstitutionEnabled   = false
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.allowsUndo           = true

        context.coordinator.textView = tv

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
        context.coordinator.textView = tv
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
        weak var textView: NSTextView?

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertSnippet(_:)),
                name: .noCalInsertSnippet,
                object: nil
            )
        }

        deinit { NotificationCenter.default.removeObserver(self) }

        // ── Lifecycle ─────────────────────────────────────────────────────
        func textDidBeginEditing(_ n: Notification) { isEditing = true }
        func textDidEndEditing(_ n: Notification)   { isEditing = false }

        func textDidChange(_ n: Notification) {
            guard let tv = n.object as? NSTextView else { return }
            parent.text = tv.string
            applyMarkdown(to: tv)
        }

        // ── Snippet insertion (cursor-aware) ───────────────────────────────
        @objc private func handleInsertSnippet(_ notification: Notification) {
            guard let snippet = notification.object as? String,
                  let tv = textView else { return }
            DispatchQueue.main.async { self.insertAtCursor(snippet, in: tv) }
        }

        func insertAtCursor(_ snippet: String, in tv: NSTextView) {
            let selRange = (tv.selectedRanges.first as? NSRange)
                ?? NSRange(location: tv.string.utf16.count, length: 0)
            let nsText = tv.string as NSString
            let selectedText = selRange.length > 0 ? nsText.substring(with: selRange) : ""
            let (processed, cursorOffset) = processMarkdownSnippet(snippet, selected: selectedText)

            guard let storage = tv.textStorage else { return }
            storage.beginEditing()
            storage.replaceCharacters(in: selRange, with: processed)
            storage.endEditing()

            parent.text = tv.string
            let newLoc = min(selRange.location + cursorOffset, tv.string.utf16.count)
            tv.selectedRanges = [NSRange(location: newLoc, length: 0) as NSValue]
            applyMarkdown(to: tv)
            tv.scrollRangeToVisible(NSRange(location: newLoc, length: 0))
            tv.window?.makeFirstResponder(tv)
        }

        // ── Smart continuation ─────────────────────────────────────────────
        func textView(_ tv: NSTextView, doCommandBy selector: Selector) -> Bool {
            let nsText    = tv.string as NSString
            guard let selRange = tv.selectedRanges.first as? NSRange else { return false }

            // Tab → 2-space indent
            if selector == #selector(NSResponder.insertTab(_:)) {
                tv.insertText("  ", replacementRange: selRange)
                parent.text = tv.string
                return true
            }

            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }

            let lineRange = nsText.lineRange(for: NSRange(location: selRange.location, length: 0))
            let line      = nsText.substring(with: lineRange)

            if line.hasPrefix("- [ ] ") || line == "- [ ]\n" {
                let content = String(line.dropFirst(6)).trimmingCharacters(in: .newlines)
                if content.isEmpty {
                    tv.insertText("\n", replacementRange: selRange)
                } else {
                    tv.insertText("\n- [ ] ", replacementRange: selRange)
                }
                parent.text = tv.string
                applyMarkdown(to: tv)
                return true
            }
            if line.hasPrefix("- ") && !line.hasPrefix("- [") {
                let content = String(line.dropFirst(2)).trimmingCharacters(in: .newlines)
                if content.isEmpty {
                    tv.insertText("\n", replacementRange: selRange)
                } else {
                    tv.insertText("\n- ", replacementRange: selRange)
                }
                parent.text = tv.string
                applyMarkdown(to: tv)
                return true
            }
            if let range = line.range(of: #"^(\d+)\. "#, options: .regularExpression) {
                let numStr  = String(line[range]).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                let num     = (Int(numStr) ?? 0) + 1
                let content = String(line.dropFirst(line.distance(from: line.startIndex, to: range.upperBound)))
                    .trimmingCharacters(in: .newlines)
                if content.isEmpty {
                    tv.insertText("\n", replacementRange: selRange)
                } else {
                    tv.insertText("\n\(num). ", replacementRange: selRange)
                }
                parent.text = tv.string
                applyMarkdown(to: tv)
                return true
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

// macOS: NSFont.preferredFont shim
private extension NSFont {
    static func preferredFont(forTextStyle style: NSFont.TextStyleShim) -> NSFont {
        return NSFont.systemFont(ofSize: NSFont.systemFontSize)
    }
    enum TextStyleShim { case body }
}
#endif
