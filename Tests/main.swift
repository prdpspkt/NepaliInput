// Tests for OfflineTransliterationEngine.
// Run with scripts/run_offline_tests.sh, which compiles this file with the engine.
// Usage: offline_engine_tests <path-to-ne_seed_lexicon.tsv>

import Foundation

var failures = 0
var passes = 0

func check(_ got: String, _ want: String, _ label: String) {
    if got == want {
        passes += 1
    } else {
        failures += 1
        print("FAIL  \(label): got \"\(got)\", want \"\(want)\"")
    }
}

func checkTrue(_ condition: Bool, _ label: String) {
    if condition {
        passes += 1
    } else {
        failures += 1
        print("FAIL  \(label)")
    }
}

// MARK: - Phonetic rules (no lexicon)

let rules = OfflineTransliterationEngine(lexicon: [])

// Conjuncts: consonant clusters take a halant between them, and a following vowel attaches to the cluster.
check(rules.phonetic("kshetra"), "क्षेत्र", "conjunct ksh + vowel e + tr")
check(rules.phonetic("shram"), "श्रम्", "conjunct shr; final m takes a halant")
check(rules.phonetic("shree"), "श्री", "shr + long ee")
check(rules.phonetic("ghar"), "घर", "inherent a at word end")
check(rules.phonetic("ce"), "से", "c before e sounds like s")
check(rules.phonetic("chhaina"), "छैन", "chh + ai diphthong matra")
check(rules.phonetic("ko"), "को", "consonant + o matra")
check(rules.phonetic("ma"), "म", "consonant with inherent a")
check(rules.phonetic("aa"), "आ", "standalone long vowel")
check(rules.phonetic("garaun"), "गरौँ", "word-final n after vowel sign is chandrabindu")
check(rules.phonetic("garauna"), "गरौन", "n before a vowel stays न")
check(rules.phonetic("ran"), "रन", "word-final n after inherent a stays न")
check(rules.phonetic("naa"), "ना", "n + long aa at word end gives ना")
check(rules.phonetic("kanaa"), "कना", "consonant + n + long aa at word end")
check(rules.phonetic("garaunaa"), "गरौना", "n + long aa after vowel sign")
check(rules.phonetic("m"), "म", "bare m keeps inherent a")
check(rules.phonetic("ma"), "म", "m + short a is म")
check(rules.phonetic("maa"), "मा", "m + long aa gives मा")
check(rules.phonetic("kmaa"), "क्मा", "conjunct-like m + long aa")
check(rules.phonetic("maale"), "माले", "m + long aa before a suffix")
check(rules.phonetic("kansha"), "कंश", "n before a consonant is anusvara")
check(rules.phonetic("kanchan"), "कञ्चन", "n before ch is ञ्")
check(rules.phonetic("panch"), "पञ्च", "panch is पञ्च")
checkTrue(rules.variants("kanchan").contains("कन्चन"), "kanchan also offers न्च")
check(rules.phonetic("nepal"), "नेपल", "n before a vowel is still न")
check(rules.phonetic("sambandha"), "सम्बन्ध", "m and n before stops take a halant")
check(rules.phonetic("bandhan"), "बन्धन", "n before dh (stop) takes a halant")
check(rules.phonetic("samyam"), "संयम्", "m before y is anusvara, final m takes a halant")
check(rules.phonetic("kanya"), "कञ", "ny is the letter ञ, not anusvara")
check(rules.phonetic("123"), "१२३", "ASCII digits become Devanagari")
check(rules.phonetic("ma 1"), "म १", "space and digit pass through")

// MARK: - Lexicon ranking

let seedPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/lexicon/ne_seed_lexicon.tsv"

guard let seedText = try? String(contentsOfFile: seedPath, encoding: .utf8) else {
    print("FAIL  cannot read seed lexicon at \(seedPath)")
    exit(1)
}

let seed = OfflineTransliterationEngine.parseLexicon(seedText)
let engine = OfflineTransliterationEngine(lexicon: seed)

check(engine.transliterate(text: "namaste", languageCode: "ne").first ?? "", "नमस्ते", "lexicon hit ranks first")
check(engine.transliterate(text: "dhanyabad", languageCode: "ne").first ?? "", "धन्यवाद", "lexicon hit for dhanyabad")
check(engine.transliterate(text: "NAMASTE", languageCode: "ne").first ?? "", "नमस्ते", "lookup is case-insensitive")

// "pani" has two entries; the higher score (पनि, 90) must come first.
check(engine.transliterate(text: "pani", languageCode: "ne").first ?? "", "पनि", "higher score ranks first")
checkTrue(engine.transliterate(text: "pani", languageCode: "ne").contains("पानी"), "both pani entries offered")

// "au" after a consonant is ambiguous (garaun = गरौँ, gaun = गाउँ), so these come from the lexicon.
check(engine.transliterate(text: "gaunle", languageCode: "ne").first ?? "", "गाउँले", "gaunle from lexicon")
check(engine.transliterate(text: "gaun", languageCode: "ne").first ?? "", "गाउँ", "gaun from lexicon")
check(engine.transliterate(text: "garaun", languageCode: "ne").first ?? "", "गरौँ", "garaun from lexicon")

// Nasal variants: every valid spelling is offered, rule-based first.
let sambandhaVariants = rules.variants("sambandha")
checkTrue(sambandhaVariants.first == "सम्बन्ध", "sambandha: rule-based spelling is first")
for spelling in ["सम्बन्ध", "संबंध", "सम्बंध", "संबन्ध"] {
    checkTrue(sambandhaVariants.contains(spelling), "sambandha offers \(spelling)")
}
checkTrue(rules.variants("samyam").contains("संयं"), "samyam offers anusvara for final m")
checkTrue(rules.variants("garaun").contains("गरौन"), "garaun offers न as an alternative")
checkTrue(rules.variants("ma").count == 1, "no nasal variants for ma")
checkTrue(rules.variants("karna").first == "कर्ण", "n after r is ण first")
checkTrue(rules.variants("karna").contains("कर्न"), "n after r also offers न")
checkTrue(rules.variants("kanaa").first == "कना", "n after k stays न first")
checkTrue(engine.transliterate(text: "karnali", languageCode: "ne").first == "कर्णाली", "karnali from lexicon")
let unknownVariants = engine.transliterate(text: "sambandha", languageCode: "ne")
checkTrue(unknownVariants.contains("संबंध"), "transliterate shows variants for a word not in the lexicon")

// A word missing from the lexicon still gets phonetic output.
let unknown = engine.transliterate(text: "kshetra", languageCode: "ne")
checkTrue(unknown.first == "क्षेत्र", "unknown word falls back to phonetic output")
checkTrue(unknown.last == "kshetra", "raw Latin text is always the last candidate")

// Candidates contain no duplicates.
let dupes = engine.transliterate(text: "ma", languageCode: "ne")
checkTrue(Set(dupes).count == dupes.count, "no duplicate candidates")

// MARK: - Seed lexicon integrity

checkTrue(seed.count >= 100, "seed lexicon has at least 100 entries (found \(seed.count))")

let devanagariRange: ClosedRange<UInt32> = 0x0900...0x097F
var badEntries: [String] = []
for entry in seed {
    let hasDevanagari = entry.word.unicodeScalars.contains { devanagariRange.contains($0.value) }
    let romanIsLatin = entry.roman.allSatisfy { $0.isASCII && ($0.isLetter || $0 == "'") }
    if !hasDevanagari || !romanIsLatin || entry.score <= 0 {
        badEntries.append("\(entry.roman)\t\(entry.word)\t\(entry.score)")
    }
}
checkTrue(badEntries.isEmpty, "every seed entry has Devanagari text, a Latin key and a positive score: \(badEntries)")

let pairs = seed.map { "\($0.roman)\t\($0.word)" }
checkTrue(Set(pairs).count == pairs.count, "no duplicate roman/word pairs in seed lexicon")

// MARK: - Summary

print("\(passes) passed, \(failures) failed")
exit(failures == 0 ? 0 : 1)
