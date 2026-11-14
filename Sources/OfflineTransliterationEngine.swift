import Foundation

// MARK: - Offline Phonetic & Statistical Transliteration Engine

/// Provides on-device offline transliteration for Nepali and Devanagari when network
/// is unavailable or when instant local candidates are required.
class OfflineTransliterationEngine {
    static let shared = OfflineTransliterationEngine()

    // High-frequency curated Nepali vocabulary
    private let dictionary: [String: [String]] = [
        "namaste": ["नमस्ते", "नमस्ते!"],
        "namaskar": ["नमस्कार"],
        "nepal": ["नेपाल"],
        "nepali": ["नेपाली", "नेपाल"],
        "mero": ["मेरो"],
        "tera": ["तेरो"],
        "terai": ["तराई"],
        "timro": ["तिम्रो"],
        "tapai": ["तपाईं", "तपाई"],
        "tapain": ["तपाईं"],
        "timi": ["तिमी"],
        "ma": ["म", "मा"],
        "hami": ["हामी"],
        "hamro": ["हाम्रो"],
        "kasto": ["कस्तो"],
        "kahan": ["कहाँ"],
        "kahile": ["कहिल्यै", "कहिले"],
        "kina": ["किन"],
        "ke": ["के"],
        "ko": ["को"],
        "kasari": ["कसरी"],
        "chha": ["छ", "छन्"],
        "chhan": ["छन्"],
        "chhaina": ["छैन"],
        "chhainam": ["छैनौँ", "छैन"],
        "ho": ["हो", "होस्"],
        "haina": ["होइन", "हैन"],
        "hunchha": ["हुन्छ"],
        "hudaina": ["हुँदैन"],
        "pani": ["पनि", "पानी"],
        "paani": ["पानी"],
        "bata": ["बाट"],
        "dekhi": ["देखि"],
        "lai": ["लाई"],
        "le": ["ले"],
        "sanga": ["सँग"],
        "sath": ["साथ"],
        "dhanyabaad": ["धन्यवाद"],
        "dhanyabad": ["धन्यवाद"],
        "swagatam": ["स्वागतम्", "स्वागतम"],
        "swagat": ["स्वागत"],
        "subhapravat": ["शुभप्रभात"],
        "shubharatri": ["शुभरात्री", "शुभरात्रि"],
        "ramro": ["राम्रो"],
        "naramro": ["नराम्रो"],
        "mitho": ["मीठो", "मिठो"],
        "ghar": ["घर"],
        "kam": ["काम"],
        "keto": ["केटो"],
        "keti": ["केटी"],
        "manchhe": ["मान्छे"],
        "sathi": ["साथी"],
        "aama": ["आमा"],
        "baba": ["बाबा", "बुबा"],
        "buba": ["बुबा"],
        "daju": ["दाजु"],
        "bhai": ["भाइ"],
        "didi": ["दीदी", "दिदी"],
        "bahini": ["बहिनी"],
        "desh": ["देश"],
        "bidesh": ["विदेश"],
        "khana": ["खाना"],
        "dudh": ["दूध"],
        "bhat": ["भात"],
        "chiya": ["चिया"],
        "aaja": ["आज"],
        "bholi": ["भोलि"],
        "hijo": ["हिजो"],
        "batawaran": ["वातावरण"],
        "samachar": ["समाचार"],
        "kathmandu": ["काठमाडौं", "काठमाडौँ"],
        "pokhara": ["पोखरा"],
        "lalitpur": ["ललितपुर"],
        "bhaktapur": ["भक्तपुर"],
        "biratnagar": ["विराटनगर"],
        "dharan": ["धरान"],
        "butwal": ["बुटवल"],
    ]

    private init() {}

    /// Transliterate Latin input into Devanagari candidates offline
    func transliterate(text: String, languageCode: String) -> [String] {
        guard !text.isEmpty else { return [] }
        let lower = text.lowercased()
        var results: [String] = []

        // 1. Direct dictionary lookup
        if let dictMatches = dictionary[lower] {
            results.append(contentsOf: dictMatches)
        }

        // 2. Phonetic rule-based translation
        let phonetic = convertPhonetic(lower)
        if !results.contains(phonetic) {
            results.append(phonetic)
        }

        // 3. Alternative vowel/consonant representations
        let alt = generateAlternative(lower)
        if let altWord = alt, !results.contains(altWord) {
            results.append(altWord)
        }

        // 4. Raw Latin text fallback
        if !results.contains(text) {
            results.append(text)
        }

        return results
    }

    private func convertPhonetic(_ input: String) -> String {
        var result = ""
        var i = input.startIndex

        let consonants: [(pattern: String, base: String)] = [
            ("ksha", "क्ष"), ("ksh", "क्ष्"),
            ("tra", "त्र"),   ("tr", "त्र्"),
            ("gya", "ज्ञ"),   ("gy", "ज्ञ्"),
            ("chha", "छ"),   ("chh", "छ्"),
            ("shree", "श्री"),("shr", "श्र्"),
            ("kh", "ख"),     ("gh", "घ"),    ("ng", "ङ"),
            ("ch", "च"),     ("jh", "झ"),    ("ny", "ञ"),
            ("th", "थ"),     ("dh", "ध"),    ("ph", "फ"),
            ("bh", "भ"),     ("sh", "श"),    ("shh", "ष"),
            ("k", "क"),      ("g", "ग"),     ("j", "ज"),
            ("t", "त"),      ("d", "द"),     ("n", "न"),
            ("p", "प"),      ("b", "ब"),     ("m", "म"),
            ("y", "य"),      ("r", "र"),     ("l", "ल"),
            ("w", "व"),      ("v", "व"),     ("s", "स"),
            ("h", "ह")
        ]

        let vowels: [(pattern: String, indep: String, matra: String)] = [
            ("aa", "आ", "ा"), ("ee", "ई", "ी"), ("oo", "ऊ", "ू"),
            ("ai", "ऐ", "ै"), ("au", "औ", "ौ"), ("ri", "ऋ", "ृ"),
            ("a", "अ", ""),   ("i", "इ", "ि"), ("u", "उ", "ु"),
            ("e", "ए", "े"),   ("o", "ओ", "ो")
        ]

        while i < input.endIndex {
            let remaining = String(input[i...])

            // Standalone vowel
            var matchedVowel = false
            for (pattern, indep, _) in vowels {
                if remaining.hasPrefix(pattern) {
                    result.append(indep)
                    i = input.index(i, offsetBy: pattern.count)
                    matchedVowel = true
                    break
                }
            }
            if matchedVowel { continue }

            // Consonant
            var matchedConsonant = false
            for (pattern, base) in consonants {
                if remaining.hasPrefix(pattern) {
                    result.append(base)
                    i = input.index(i, offsetBy: pattern.count)
                    matchedConsonant = true

                    if base.hasSuffix("्") {
                        break
                    }

                    if i < input.endIndex {
                        let after = String(input[i...])
                        var vowelAttached = false
                        for (vpat, _, matra) in vowels {
                            if after.hasPrefix(vpat) {
                                result.append(matra)
                                i = input.index(i, offsetBy: vpat.count)
                                vowelAttached = true
                                break
                            }
                        }
                        if !vowelAttached {
                            var nextIsConsonant = false
                            for (cpat, _) in consonants {
                                if after.hasPrefix(cpat) {
                                    nextIsConsonant = true
                                    break
                                }
                            }
                            if nextIsConsonant {
                                result.append("्")
                            }
                        }
                    }
                    break
                }
            }
            if matchedConsonant { continue }

            // Digits (Devanagari mapping)
            let char = input[i]
            let digits = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
            if let ascii = char.asciiValue, ascii >= 48 && ascii <= 57 {
                result.append(digits[Int(ascii - 48)])
            } else {
                result.append(char)
            }
            i = input.index(after: i)
        }

        return result
    }

    private func generateAlternative(_ input: String) -> String? {
        // Generates common phonetic variations (e.g., 'v' <-> 'b', 'sh' <-> 's')
        if input.contains("v") {
            return convertPhonetic(input.replacingOccurrences(of: "v", with: "b"))
        } else if input.contains("b") {
            return convertPhonetic(input.replacingOccurrences(of: "b", with: "v"))
        } else if input.contains("sh") {
            return convertPhonetic(input.replacingOccurrences(of: "sh", with: "s"))
        }
        return nil
    }
}
