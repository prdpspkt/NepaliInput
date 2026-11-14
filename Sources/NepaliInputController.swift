import Cocoa
import InputMethodKit

// MARK: - Nepali Input Controller

/// The core input controller for Nepali Input IME.
///
/// Behavior matches the native macOS transliteration input method:
/// - Transliterated text appears **inline** as marked text
/// - System `IMKCandidates` window shows alternatives below the cursor
/// - Space commits the selected candidate + inserts a space
/// - Enter commits without a space
/// - Number keys (1–9) select a specific candidate when candidates are shown
/// - Arrow keys navigate the candidate list
/// - Escape cancels the composition
/// - Backspace removes from the buffer and re-queries
/// - Digits (0–9) output Devanagari numerals (०–९) when idle (configurable via menu)
/// - Punctuation auto-commits and passes through
/// - On-Device ML Adaptive Re-ranking learns vocabulary and contextual bigrams
/// - Offline Phonetic Engine guarantees transliteration without internet
///
/// The class name must match `InputMethodServerControllerClass` in Info.plist.
@objc(NepaliInputController)
class NepaliInputController: IMKInputController {

    // MARK: - State

    /// English characters the user has typed (e.g., "namaste")
    private var originalBuffer: String = ""

    /// Transliteration candidates from the API / ML engine
    private var currentCandidates: [String] = []

    /// Index of the currently highlighted candidate
    private var selectedIndex: Int = 0

    /// Whether we've received results for the current buffer contents
    private var hasReceivedResults: Bool = false

    /// Tracks the buffer state when the last query was made,
    /// so we can discard stale responses
    private var pendingQueryBuffer: String = ""

    /// Contextual preceding word for ML bigram re-ranking
    private var previousCommittedWord: String? = nil

    // MARK: - Lifecycle

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        super.init(server: server, delegate: delegate, client: inputClient)
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        resetState()
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposingText()
        MLAdaptiveEngine.shared.saveToDisk()
        super.deactivateServer(sender)
    }

    /// System calls this when the text field loses focus or app switches
    override func commitComposition(_ sender: Any!) {
        commitComposingText()
        super.commitComposition(sender)
    }

    // MARK: - IMKCandidates Data Source

    /// Called by IMKCandidates to get the list of candidates to display
    override func candidates(_ sender: Any!) -> [Any]! {
        return currentCandidates as [Any]
    }

    /// Called when the user clicks a candidate or confirms selection
    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let text = candidateString?.string else { return }
        if let idx = currentCandidates.firstIndex(of: text) {
            selectedIndex = idx
        }
        commitText(text)
    }

    /// Called when the user navigates candidates (arrow keys in the candidate window)
    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        guard let text = candidateString?.string else { return }
        if let idx = currentCandidates.firstIndex(of: text) {
            selectedIndex = idx
        }
        // Update the inline marked text to reflect the newly selected candidate
        if let client = self.client() {
            setMarkedText(text, client: client)
        }
    }

    // MARK: - Event Handling

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event = event, event.type == .keyDown else {
            return false
        }
        guard let client = sender as? IMKTextInput else {
            return false
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Pass through Command / Control / Option combos (Cmd+C, Cmd+V, etc.)
        if modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) {
            if !originalBuffer.isEmpty {
                commitComposingText()
            }
            previousCommittedWord = nil
            return false
        }

        let keyCode = event.keyCode
        let chars = event.characters ?? ""

        // ─── Composing state (buffer is non-empty) ───
        if !originalBuffer.isEmpty {
            return handleComposingKey(keyCode: keyCode, chars: chars, client: client)
        }

        // ─── Idle state (buffer is empty) ───
        return handleIdleKey(keyCode: keyCode, chars: chars, client: client)
    }

    // MARK: - Key Handling — Composing

    private func handleComposingKey(keyCode: UInt16, chars: String, client: IMKTextInput) -> Bool {
        switch keyCode {

        // Escape → cancel composition entirely
        case 53:
            cancelComposition(client: client)
            previousCommittedWord = nil
            return true

        // Backspace → remove last English character, re-query
        case 51:
            return handleBackspace(client: client)

        // Space → commit selected candidate + insert space
        case 49:
            commitComposingText()
            self.client()?.insertText(
                " ",
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            return true

        // Enter / Return → commit selected candidate (no trailing space)
        case 36, 76:
            commitComposingText()
            previousCommittedWord = nil
            return true

        // Tab → commit selected candidate (same as Enter)
        case 48:
            commitComposingText()
            return true

        // Down arrow → next candidate
        case 125:
            navigateCandidate(direction: .down, client: client)
            return true

        // Up arrow → previous candidate
        case 126:
            navigateCandidate(direction: .up, client: client)
            return true

        default:
            break
        }

        // Number keys 1–9 → select that candidate directly if candidates are available
        if let char = chars.first, char >= "1" && char <= "9" {
            let idx = Int(String(char))! - 1
            if idx < currentCandidates.count {
                selectedIndex = idx
                commitText(currentCandidates[idx])
                return true
            }
        }

        // Letter keys → append to buffer, re-query
        if let char = chars.first, char.isLetter {
            originalBuffer.append(char)
            queryAndUpdateComposition(client: client)
            return true
        }

        // Punctuation / numbers / symbols while composing →
        // commit current candidate, then pass the character through (converting digits if enabled)
        if !chars.isEmpty {
            commitComposingText()
            let textToInsert = LanguageManager.shared.useNativeNumerals
                ? LanguageManager.shared.currentLanguage.convertDigits(in: chars)
                : chars
            self.client()?.insertText(
                textToInsert,
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            // Sentence enders reset context
            if chars.contains(".") || chars.contains("?") || chars.contains("!") || chars.contains("।") {
                previousCommittedWord = nil
            }
            return true
        }

        return false
    }

    // MARK: - Key Handling — Idle

    private func handleIdleKey(keyCode: UInt16, chars: String, client: IMKTextInput) -> Bool {
        // Reset context on sentence enders
        if chars.contains(".") || chars.contains("?") || chars.contains("!") || chars.contains("।") || keyCode == 36 || keyCode == 76 {
            previousCommittedWord = nil
        }

        // If native numerals is enabled and user typed a digit ('0'-'9'),
        // output the native numeral directly (e.g. '1' -> '१', '2' -> '२')
        if LanguageManager.shared.useNativeNumerals,
           let char = chars.first,
           let converted = LanguageManager.shared.currentLanguage.convertDigit(char) {
            client.insertText(
                String(converted),
                replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
            )
            return true
        }

        // Only intercept letter keys to start a new composition
        guard let char = chars.first, char.isLetter else {
            return false
        }

        originalBuffer = String(char)
        queryAndUpdateComposition(client: client)
        return true
    }

    // MARK: - Composition & Transliteration

    /// Query the transliteration service (with ML re-ranking & offline fallback)
    private func queryAndUpdateComposition(client: IMKTextInput) {
        let buffer = originalBuffer
        let langCode = LanguageManager.shared.currentLanguage.code
        let prevWord = previousCommittedWord

        // 1. Check cache for instant results
        if let cached = TransliterationService.shared.cachedResults(for: buffer, languageCode: langCode, previousWord: prevWord) {
            applyResults(cached, for: buffer, client: client)
            return
        }

        // 2. Show the English buffer as temporary marked text while waiting
        setMarkedText(originalBuffer, client: client)

        // 3. Fire the async API / ML request
        pendingQueryBuffer = buffer
        TransliterationService.shared.transliterate(
            text: buffer,
            languageCode: langCode,
            previousWord: prevWord
        ) { [weak self] candidates in
            guard let self = self else { return }

            // Discard stale responses — the buffer has moved on
            guard self.originalBuffer == buffer else { return }

            guard let client = self.client() else { return }
            self.applyResults(candidates, for: buffer, client: client)
        }
    }

    /// Apply transliteration results: update marked text + show candidates
    private func applyResults(_ candidates: [String], for buffer: String, client: IMKTextInput) {
        currentCandidates = candidates
        selectedIndex = 0
        hasReceivedResults = true

        // Update inline text to show the top transliteration
        if let top = candidates.first {
            setMarkedText(top, client: client)
        } else {
            // No candidates — keep showing English
            setMarkedText(buffer, client: client)
        }

        // Show / update the system candidate window
        if !candidates.isEmpty {
            candidatesWindow?.update()
            candidatesWindow?.show()
        } else {
            candidatesWindow?.hide()
        }
    }

    // MARK: - Marked Text (Inline Composition)

    /// Set the inline underlined text that appears in the active text field.
    private func setMarkedText(_ text: String, client: IMKTextInput) {
        let attrs: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSUnderlineStyle.thick.rawValue,
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)

        client.setMarkedText(
            attrString,
            selectionRange: NSRange(location: text.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    // MARK: - Candidate Navigation

    private enum NavigationDirection { case up, down }

    private func navigateCandidate(direction: NavigationDirection, client: IMKTextInput) {
        guard !currentCandidates.isEmpty else { return }

        switch direction {
        case .down:
            selectedIndex = min(selectedIndex + 1, currentCandidates.count - 1)
        case .up:
            selectedIndex = max(selectedIndex - 1, 0)
        }

        // Update inline text to match selected candidate
        let text = currentCandidates[selectedIndex]
        setMarkedText(text, client: client)

        // Tell the system candidate window to highlight this index
        candidatesWindow?.selectCandidate(selectedIndex)
    }

    // MARK: - Commit & Cancel

    /// Commit whichever candidate is currently selected (or the English buffer as fallback)
    private func commitComposingText() {
        guard !originalBuffer.isEmpty else { return }

        let text: String
        if hasReceivedResults && !currentCandidates.isEmpty && selectedIndex < currentCandidates.count {
            text = currentCandidates[selectedIndex]
        } else {
            text = originalBuffer
        }
        commitText(text)
    }

    /// Commit a specific text string to the active application
    private func commitText(_ text: String) {
        guard let client = self.client() else {
            resetState()
            return
        }

        // Learn selection in ML Adaptive Engine
        MLAdaptiveEngine.shared.recordCommit(
            candidate: text,
            input: originalBuffer,
            previousWord: previousCommittedWord
        )
        previousCommittedWord = text

        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        resetState()
    }

    /// Cancel composition — discard everything without committing
    private func cancelComposition(client: IMKTextInput) {
        client.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        resetState()
    }

    /// Handle backspace — remove one English character, re-query
    private func handleBackspace(client: IMKTextInput) -> Bool {
        guard !originalBuffer.isEmpty else { return false }

        originalBuffer.removeLast()

        if originalBuffer.isEmpty {
            cancelComposition(client: client)
        } else {
            // Re-query with shorter buffer
            queryAndUpdateComposition(client: client)
        }
        return true
    }

    /// Reset all state to idle
    private func resetState() {
        originalBuffer = ""
        currentCandidates = []
        selectedIndex = 0
        hasReceivedResults = false
        pendingQueryBuffer = ""
        candidatesWindow?.hide()
    }

    // MARK: - Menu (right-click input source icon)

    override func menu() -> NSMenu! {
        let menu = NSMenu(title: "Nepali Input")

        // Header
        let currentLang = LanguageManager.shared.currentLanguage
        let header = NSMenuItem(
            title: "Nepali Input — \(currentLang.nativeName)",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        // Numerals toggle
        let numeralsTitle: String
        if let digits = currentLang.digits {
            let start = digits[0]
            let end = digits[9]
            if currentLang.code.hasPrefix("ne") || currentLang.code.hasPrefix("hi") || currentLang.code.hasPrefix("mr") {
                numeralsTitle = "Devanagari Numerals (\(start)–\(end))"
            } else {
                numeralsTitle = "Native Numerals (\(start)–\(end))"
            }
        } else {
            numeralsTitle = "Devanagari Numerals (०–९)"
        }

        let numeralsItem = NSMenuItem(
            title: numeralsTitle,
            action: #selector(toggleNumerals(_:)),
            keyEquivalent: ""
        )
        numeralsItem.target = self
        numeralsItem.state = LanguageManager.shared.useNativeNumerals ? .on : .off
        menu.addItem(numeralsItem)
        menu.addItem(NSMenuItem.separator())

        // Machine Learning Adaptive Engine Section
        let mlItem = NSMenuItem(
            title: "Adaptive Learning (ML)",
            action: #selector(toggleAdaptiveLearning(_:)),
            keyEquivalent: ""
        )
        mlItem.target = self
        mlItem.state = MLAdaptiveEngine.shared.isEnabled ? .on : .off
        menu.addItem(mlItem)

        let learnedCount = MLAdaptiveEngine.shared.learnedWordsCount
        let countItem = NSMenuItem(
            title: "Learned Words: \(learnedCount)",
            action: nil,
            keyEquivalent: ""
        )
        countItem.isEnabled = false
        menu.addItem(countItem)

        let resetMLItem = NSMenuItem(
            title: "Reset Learned Vocabulary...",
            action: #selector(resetLearnedVocabulary(_:)),
            keyEquivalent: ""
        )
        resetMLItem.target = self
        menu.addItem(resetMLItem)
        menu.addItem(NSMenuItem.separator())

        // Language submenu
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let langMenu = NSMenu(title: "Language")

        for language in LanguageManager.shared.supportedLanguages {
            let item = NSMenuItem(
                title: "\(language.nativeName)  \(language.name)",
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.code
            if language == currentLang {
                item.state = .on
            }
            langMenu.addItem(item)
        }

        langItem.submenu = langMenu
        menu.addItem(langItem)

        return menu
    }

    @objc private func toggleNumerals(_ sender: NSMenuItem) {
        LanguageManager.shared.toggleNativeNumerals()
    }

    @objc private func toggleAdaptiveLearning(_ sender: NSMenuItem) {
        MLAdaptiveEngine.shared.isEnabled.toggle()
    }

    @objc private func resetLearnedVocabulary(_ sender: NSMenuItem) {
        MLAdaptiveEngine.shared.resetLearnedData()
        TransliterationService.shared.clearCache()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String,
              let language = LanguageManager.shared.language(forCode: code) else { return }
        LanguageManager.shared.selectLanguage(language)
        previousCommittedWord = nil
        TransliterationService.shared.clearCache()
    }
}
