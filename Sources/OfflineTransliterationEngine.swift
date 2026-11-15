import Foundation

// MARK: - Offline Transliteration Engine
//
// Two layers, in order:
//   1. Seed lexicon (Resources/lexicon/ne_seed_lexicon.tsv): common words with a frequency score.
//   2. Rule-based phonetic converter for everything else.
//
// Lexicon entries are original work written for this project (see the file header), so they can be
// bundled and redistributed without a third-party license.

final class OfflineTransliterationEngine {
    typealias LexiconEntry = (roman: String, word: String, score: Int)

    static let shared = OfflineTransliterationEngine(lexicon: loadBundledLexicon())

    /// Romanized word -> candidates, highest score first.
    private let lexicon: [String: [(word: String, score: Int)]]

    init(lexicon entries: [LexiconEntry]) {
        var table: [String: [(word: String, score: Int)]] = [:]
        for entry in entries {
            table[entry.roman.lowercased(), default: []].append((word: entry.word, score: entry.score))
        }
        for key in table.keys {
            table[key]?.sort { $0.score > $1.score }
        }
        self.lexicon = table
    }

    // MARK: Lexicon loading

    /// Parses TSV lines of `roman<TAB>devanagari<TAB>score`. Lines starting with `#` are comments.
    static func parseLexicon(_ text: String) -> [LexiconEntry] {
        var entries: [LexiconEntry] = []
        for line in text.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("#") { continue }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count == 3, let score = Int(columns[2]) else { continue }
            entries.append((roman: String(columns[0]), word: String(columns[1]), score: score))
        }
        return entries
    }

    static func loadBundledLexicon() -> [LexiconEntry] {
        guard let url = Bundle.main.url(forResource: "ne_seed_lexicon", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("NepaliInput: seed lexicon missing; using phonetic rules only")
            return []
        }
        return parseLexicon(text)
    }

    // MARK: Candidates

    /// Transliterate Latin input into Devanagari candidates offline.
    func transliterate(text: String, languageCode: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let lower = text.lowercased()
        var results: [String] = []

        func add(_ candidate: String) {
            if !candidate.isEmpty && !results.contains(candidate) {
                results.append(candidate)
            }
        }

        // 1. Lexicon words, most frequent first.
        for entry in lexicon[lower] ?? [] {
            add(entry.word)
        }
        // 2. Rule-based spelling first, then every other valid spelling of the nasals (n, m).
        for candidate in variants(lower) {
            add(candidate)
        }
        // 3. Common spelling variant (v <-> b, sh -> s).
        if let variant = spellingVariant(lower) {
            add(phonetic(variant))
        }
        // 4. Raw Latin text.
        add(text)

        return results
    }

    private func spellingVariant(_ input: String) -> String? {
        if input.contains("v") { return input.replacingOccurrences(of: "v", with: "b") }
        if input.contains("b") { return input.replacingOccurrences(of: "b", with: "v") }
        if input.contains("sh") { return input.replacingOccurrences(of: "sh", with: "s") }
        return nil
    }

    // MARK: Phonetic rules

    /// One way to spell an ambiguous letter: a nasal (n, m) or a dental/retroflex pair (t, d).
    /// The first option of each choice is the rule-based spelling.
    private enum Choice {
        case anusvara          // ं on the preceding consonant (or alone)
        case chandrabindu      // ँ after a vowel sign
        case conjunct(String)  // the nasal is its own consonant, joined to what follows: सम्बन्ध
        case closed(String)    // the nasal is its own consonant with a final halant: संयम्
        case letter(String)    // a consonant on its own, from a dental/retroflex pair: ट or त
    }

    private enum Token {
        case consonant(String)                        // base letter, without a vowel sign
        case vowel(independent: String, matra: String)
        case other(Character)                         // digits, punctuation, anything else
        case choice([Choice])                         // a letter with more than one valid spelling
    }

    /// Consonants before which a nasal becomes anusvara. Other consonants (stops) take a halant conjunct.
    private static let anusvaraFollowers = ["shh", "shr", "sh", "s", "y", "r", "l", "w", "v", "h"]

    /// Palatal consonants, before which "n" is written as ञ्.
    private static let palatalFollowers = ["chh", "ch", "jh", "j"]

    /// Dental and retroflex consonants. "t" is त or ट, "d" is द or ड, and the aspirated forms
    /// th and dh have their own pairs. Longest first, so "th" and "dh" win over "t" and "d".
    private static let retroflexPairs: [(roman: String, dental: String, retroflex: String)] = [
        ("th", "थ", "ठ"), ("dh", "ध", "ढ"), ("t", "त", "ट"), ("d", "द", "ड"),
    ]

    /// Longest patterns first, so "chh" wins over "ch" and "c".
    private static let consonantPatterns: [(roman: String, letter: String)] = [
        ("chh", "छ"), ("ksh", "क्ष"), ("shr", "श्र"), ("shh", "ष"), ("sh", "श"),
        ("tr", "त्र"), ("gy", "ज्ञ"), ("ch", "च"), ("kh", "ख"), ("gh", "घ"),
        ("ng", "ङ"), ("jh", "झ"), ("ny", "ञ"), ("th", "थ"), ("dh", "ध"), ("ph", "फ"), ("bh", "भ"),
        ("x", "क्स"), ("k", "क"), ("q", "क"), ("c", "क"), ("g", "ग"), ("j", "ज"), ("z", "ज"),
        ("t", "त"), ("d", "द"), ("n", "न"), ("p", "प"), ("f", "फ"), ("b", "ब"), ("m", "म"),
        ("y", "य"), ("r", "र"), ("l", "ल"), ("w", "व"), ("v", "व"), ("s", "स"), ("h", "ह"),
    ].sorted { $0.roman.count > $1.roman.count }

    private static let vowelPatterns: [(roman: String, independent: String, matra: String)] = [
        ("aa", "आ", "ा"), ("ee", "ई", "ी"), ("ii", "ई", "ी"), ("oo", "ऊ", "ू"), ("uu", "ऊ", "ू"),
        ("ai", "ऐ", "ै"), ("au", "औ", "ौ"), ("a", "अ", ""), ("i", "इ", "ि"), ("u", "उ", "ु"),
        ("e", "ए", "े"), ("o", "ओ", "ो"),
    ].sorted { $0.roman.count > $1.roman.count }

    private static let devanagariDigits = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]

    private func tokenize(_ input: String) -> [Token] {
        var tokens: [Token] = []
        var i = input.startIndex

        scan: while i < input.endIndex {
            let rest = input[i...]

            // Word-final "n" after an explicit vowel sign is chandrabindu (ँ): garaun -> गरौँ.
            // "garauna" keeps न because the "n" is followed by a vowel.
            // Word-final "n" after an explicit vowel sign: chandrabindu (garaun -> गरौँ) or न (garaunn).
            if rest.hasPrefix("n"), input.index(after: i) == input.endIndex,
               case .vowel(_, let matra)? = tokens.last, !matra.isEmpty {
                tokens.append(.choice([.chandrabindu, .conjunct("न")]))
                i = input.index(after: i)
                continue scan
            }

            // Word-final "m" after a consonant and short a: halant (samyam -> संयम्) or anusvara (संयं).
            // A word like "kam" still ranks काम first through the lexicon.
            if rest.hasPrefix("m"), input.index(after: i) == input.endIndex, tokens.count >= 2,
               case .vowel(_, let matra) = tokens[tokens.count - 1], matra.isEmpty,
               Self.isConsonant(tokens[tokens.count - 2]) {
                tokens.append(.choice([.closed("म"), .anusvara]))
                i = input.index(after: i)
                continue scan
            }

            // A nasal before a consonant: anusvara (kansha -> कंश, samyam -> संयम) or a conjunct
            // with halant (sambandha -> सम्बन्ध). Before a sibilant or semivowel anusvara is the
            // rule-based choice; before a stop the conjunct is. "ng" and "ny" are their own letters.
            if (rest.hasPrefix("n") || rest.hasPrefix("m")) && !tokens.isEmpty
                && !rest.hasPrefix("ng") && !rest.hasPrefix("ny") {
                let after = input.index(after: i)
                let tail = input[after...]
                if Self.consonantPatterns.contains(where: { tail.hasPrefix($0.roman) }) {
                    let letter = rest.hasPrefix("n") ? "न" : "म"
                    let anusvaraFirst = Self.anusvaraFollowers.contains(where: { tail.hasPrefix($0) })
                    // "n" before a palatal (च, छ, ज, झ) is ञ्: kanchan -> कञ्चन, panch -> पञ्च.
                    let palatal = rest.hasPrefix("n") && Self.palatalFollowers.contains(where: { tail.hasPrefix($0) })
                    let options: [Choice]
                    if palatal {
                        options = [.conjunct("ञ"), .conjunct("न"), .anusvara]
                    } else if anusvaraFirst {
                        options = [.anusvara, .conjunct(letter)]
                    } else {
                        options = [.conjunct(letter), .anusvara]
                    }
                    tokens.append(.choice(options))
                    i = after
                    continue scan
                }
            }

            // "n" before a vowel can be retroflex ण: karnali -> कर्णाली. After "र" ण is the
            // rule-based choice; elsewhere न is.
            if rest.hasPrefix("n") && !tokens.isEmpty && !rest.hasPrefix("ng") && !rest.hasPrefix("ny") {
                let after = input.index(after: i)
                let tail = input[after...]
                if Self.vowelPatterns.contains(where: { tail.hasPrefix($0.roman) }) {
                    var afterR = false
                    if case .consonant("र")? = tokens.last { afterR = true }
                    let options: [Choice] = afterR
                        ? [.conjunct("ण"), .conjunct("न")]
                        : [.conjunct("न"), .conjunct("ण")]
                    tokens.append(.choice(options))
                    i = after
                    continue scan
                }
            }

            // "c" before e, i or y sounds like "s" (ce, ci, cy).
            if rest.hasPrefix("c") && !rest.hasPrefix("ch") {
                let next = input.index(after: i)
                if next < input.endIndex && "eiy".contains(input[next]) {
                    tokens.append(.consonant("स"))
                    i = next
                    continue scan
                }
            }
            // "t" and "d" (and th, dh) are dental or retroflex: ta -> त or ट, da -> द or ड.
            // "tr" stays त्र. The dental spelling is the rule-based choice.
            if !rest.hasPrefix("tr"),
               let pair = Self.retroflexPairs.first(where: { rest.hasPrefix($0.roman) }) {
                tokens.append(.choice([.letter(pair.dental), .letter(pair.retroflex)]))
                i = input.index(i, offsetBy: pair.roman.count)
                continue scan
            }
            if let consonant = Self.consonantPatterns.first(where: { rest.hasPrefix($0.roman) }) {
                tokens.append(.consonant(consonant.letter))
                i = input.index(i, offsetBy: consonant.roman.count)
                continue scan
            }
            if let vowel = Self.vowelPatterns.first(where: { rest.hasPrefix($0.roman) }) {
                tokens.append(.vowel(independent: vowel.independent, matra: vowel.matra))
                i = input.index(i, offsetBy: vowel.roman.count)
                continue scan
            }
            tokens.append(.other(input[i]))
            i = input.index(after: i)
        }
        return tokens
    }

    /// Rule-based conversion of Latin text to Devanagari (the first spelling from `variants`).
    ///
    /// A consonant keeps its inherent "a" unless a vowel sign follows it. Two consonants in a row
    /// form a conjunct (halant between them), so "shram" becomes श्रम्, not श्र्म.
    func phonetic(_ input: String) -> String {
        let tokens = tokenize(input.lowercased())
        return render(tokens, choices: Array(repeating: 0, count: choiceCount(tokens)))
    }

    /// Every valid spelling of the input, rule-based spelling first, then spellings with one
    /// changed choice, then two, and so on. Choices multiply the spellings: sambandha gives
    /// सम्बन्ध, संबन्ध, सम्बंध, संबंध, and ta gives त and ट. Capped at 32 spellings.
    func variants(_ input: String) -> [String] {
        let tokens = tokenize(input.lowercased())
        let radices = tokens.compactMap { token -> Int? in
            if case .choice(let options) = token { return options.count }
            return nil
        }
        var choices = Array(repeating: 0, count: radices.count)
        var results: [String] = []
        var seen = Set<String>()
        let limit = 32

        // Collects spellings that change exactly `changesLeft` choices, starting at `start`.
        func collect(from start: Int, changesLeft: Int) {
            if results.count >= limit { return }
            if changesLeft == 0 {
                let spelling = render(tokens, choices: choices)
                if seen.insert(spelling).inserted {
                    results.append(spelling)
                }
                return
            }
            guard start < choices.count else { return }
            for position in start..<choices.count {
                for option in 1..<radices[position] {
                    choices[position] = option
                    collect(from: position + 1, changesLeft: changesLeft - 1)
                    choices[position] = 0
                    if results.count >= limit { return }
                }
            }
        }

        for changes in 0...choices.count {
            collect(from: 0, changesLeft: changes)
            if results.count >= limit { break }
        }
        return results
    }

    /// Whether a token is a consonant that a following halant or vowel can attach to.
    private static func isConsonant(_ token: Token) -> Bool {
        switch token {
        case .consonant:
            return true
        case .choice(let options):
            return options.allSatisfy { option in
                if case .letter = option { return true }
                return false
            }
        default:
            return false
        }
    }

    private func choiceCount(_ tokens: [Token]) -> Int {
        tokens.reduce(0) { count, token in
            if case .choice = token { return count + 1 }
            return count
        }
    }

    /// Renders tokens to Devanagari. `choices[n]` picks the spelling of the n-th choice.
    private func render(_ tokens: [Token], choices: [Int]) -> String {
        var output = ""
        var pending: String? = nil   // consonant still waiting for its vowel sign
        var choiceIndex = 0

        for token in tokens {
            switch token {
            case .consonant(let letter):
                if let p = pending { output += p + "्" }
                pending = letter
            case .vowel(let independent, let matra):
                if let p = pending {
                    output += p + matra
                    pending = nil
                } else {
                    output += independent
                }
            case .other(let ch):
                if let p = pending {
                    output += p
                    pending = nil
                }
                output += Self.digitOrSelf(ch)
            case .choice(let options):
                let option = options[choices[choiceIndex]]
                choiceIndex += 1
                switch option {
                case .anusvara:
                    if let p = pending {
                        output += p + "ं"
                        pending = nil
                    } else {
                        output += "ं"
                    }
                case .chandrabindu:
                    if let p = pending {
                        output += p
                        pending = nil
                    }
                    output += "ँ"
                case .conjunct(let letter), .letter(let letter):
                    if let p = pending { output += p + "्" }
                    pending = letter
                case .closed(let letter):
                    if let p = pending { output += p + "्" }
                    pending = nil
                    output += letter + "्"
                }
            }
        }
        if let p = pending { output += p }
        return output
    }

    private static func digitOrSelf(_ ch: Character) -> String {
        if let ascii = ch.asciiValue, (48...57).contains(ascii) {
            return devanagariDigits[Int(ascii) - 48]
        }
        return String(ch)
    }
}
