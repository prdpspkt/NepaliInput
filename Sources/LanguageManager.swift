import Foundation

// MARK: - Language Definition

struct Language: Equatable {
    let name: String
    let code: String        // e.g., "ne-t-i0-und"
    let nativeName: String  // e.g., "नेपाली"
    let shortLabel: String  // e.g., "ने" (shown in menu bar)
    let digits: [Character]? // Native digits 0-9 if applicable

    static func == (lhs: Language, rhs: Language) -> Bool {
        return lhs.code == rhs.code
    }

    /// Converts an ASCII digit ('0'-'9') to the language's native numeral (e.g. '1' -> '१')
    func convertDigit(_ char: Character) -> Character? {
        guard let digits = digits,
              let ascii = char.asciiValue,
              ascii >= 48 && ascii <= 57 else {
            return nil
        }
        return digits[Int(ascii - 48)]
    }

    /// Replaces all ASCII digits ('0'-'9') in the given string with native numerals
    func convertDigits(in text: String) -> String {
        guard let digits = digits else { return text }
        return String(text.map { char in
            if let ascii = char.asciiValue, ascii >= 48 && ascii <= 57 {
                return digits[Int(ascii - 48)]
            }
            return char
        })
    }
}

// MARK: - Language Manager

/// Manages supported languages and the user's current selection.
/// Persists the selected language and numeral preferences across sessions using UserDefaults.
class LanguageManager {
    static let shared = LanguageManager()

    private let selectedLanguageKey = "NepaliInput_SelectedLanguageCode"
    private let legacyLanguageKey = "MacInput_SelectedLanguageCode"
    private let useNativeNumeralsKey = "NepaliInput_UseNativeNumerals"

    /// Whether native script numerals (e.g. Devanagari ०–९) are used instead of Hindu-Arabic (0–9)
    var useNativeNumerals: Bool {
        didSet {
            UserDefaults.standard.set(useNativeNumerals, forKey: useNativeNumeralsKey)
        }
    }

    /// All supported languages with their Google Input Tools API codes and native numerals
    let supportedLanguages: [Language]

    /// The currently selected language
    private(set) var currentLanguage: Language

    private init() {
        let langs = Self.defaultLanguages()
        self.supportedLanguages = langs

        if UserDefaults.standard.object(forKey: useNativeNumeralsKey) != nil {
            self.useNativeNumerals = UserDefaults.standard.bool(forKey: useNativeNumeralsKey)
        } else {
            // Default to true (Devanagari numerals for Nepali/Hindi)
            self.useNativeNumerals = true
        }

        let savedCode = UserDefaults.standard.string(forKey: selectedLanguageKey)
            ?? UserDefaults.standard.string(forKey: legacyLanguageKey)

        if let savedCode = savedCode,
           let language = langs.first(where: { $0.code == savedCode }) {
            self.currentLanguage = language
        } else {
            // Default to Nepali
            self.currentLanguage = langs[0]
        }
    }

    private static func defaultLanguages() -> [Language] {
        let devanagariDigits: [Character] = ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९"]
        let bengaliDigits: [Character]    = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"]
        let tamilDigits: [Character]      = ["௦", "௧", "௨", "௩", "௪", "௫", "௬", "௭", "௮", "௯"]
        let teluguDigits: [Character]     = ["౦", "౧", "౨", "౩", "౪", "౫", "౬", "౭", "౮", "౯"]
        let gujaratiDigits: [Character]   = ["૦", "૧", "૨", "૩", "૪", "૫", "૬", "૭", "૮", "૯"]
        let kannadaDigits: [Character]    = ["೦", "೧", "೨", "೩", "೪", "೫", "೬", "೭", "೮", "೯"]
        let malayalamDigits: [Character]  = ["൦", "൧", "൨", "൩", "൪", "൫", "൬", "൭", "൮", "൯"]
        let punjabiDigits: [Character]    = ["੦", "੧", "੨", "੩", "੪", "੫", "੬", "੭", "੮", "੯"]
        let urduDigits: [Character]       = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
        let arabicDigits: [Character]     = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        let persianDigits: [Character]    = ["\u{06F0}", "\u{06F1}", "\u{06F2}", "\u{06F3}", "\u{06F4}", "\u{06F5}", "\u{06F6}", "\u{06F7}", "\u{06F8}", "\u{06F9}"]
        let thaiDigits: [Character]       = ["๐", "๑", "๒", "๓", "๔", "๕", "๖", "๗", "๘", "๙"]

        return [
            Language(name: "Nepali",     code: "ne-t-i0-und", nativeName: "नेपाली",    shortLabel: "ने", digits: devanagariDigits),
            Language(name: "Hindi",      code: "hi-t-i0-und", nativeName: "हिन्दी",    shortLabel: "हि", digits: devanagariDigits),
            Language(name: "Bengali",    code: "bn-t-i0-und", nativeName: "বাংলা",     shortLabel: "বা", digits: bengaliDigits),
            Language(name: "Tamil",      code: "ta-t-i0-und", nativeName: "தமிழ்",     shortLabel: "த", digits: tamilDigits),
            Language(name: "Telugu",     code: "te-t-i0-und", nativeName: "తెలుగు",    shortLabel: "తె", digits: teluguDigits),
            Language(name: "Marathi",    code: "mr-t-i0-und", nativeName: "मराठी",     shortLabel: "म", digits: devanagariDigits),
            Language(name: "Gujarati",   code: "gu-t-i0-und", nativeName: "ગુજરાતી",   shortLabel: "ગુ", digits: gujaratiDigits),
            Language(name: "Kannada",    code: "kn-t-i0-und", nativeName: "ಕನ್ನಡ",     shortLabel: "ಕ", digits: kannadaDigits),
            Language(name: "Malayalam",  code: "ml-t-i0-und", nativeName: "മലയാളം",   shortLabel: "മ", digits: malayalamDigits),
            Language(name: "Punjabi",    code: "pa-t-i0-und", nativeName: "ਪੰਜਾਬੀ",    shortLabel: "ਪੰ", digits: punjabiDigits),
            Language(name: "Urdu",       code: "ur-t-i0-und", nativeName: "اردو",      shortLabel: "ار", digits: urduDigits),
            Language(name: "Arabic",     code: "ar-t-i0-und", nativeName: "العربية",    shortLabel: "عر", digits: arabicDigits),
            Language(name: "Persian",    code: "fa-t-i0-und", nativeName: "فارسی",     shortLabel: "فا", digits: persianDigits),
            Language(name: "Russian",    code: "ru-t-i0-und", nativeName: "Русский",   shortLabel: "Ру", digits: nil),
            Language(name: "Greek",      code: "el-t-i0-und", nativeName: "Ελληνικά",  shortLabel: "Ελ", digits: nil),
            Language(name: "Thai",       code: "th-t-i0-und", nativeName: "ไทย",       shortLabel: "ไท", digits: thaiDigits),
            Language(name: "Amharic",    code: "am-t-i0-und", nativeName: "አማርኛ",     shortLabel: "አማ", digits: nil),
            Language(name: "Sinhalese",  code: "si-t-i0-und", nativeName: "සිංහල",     shortLabel: "සි", digits: nil),
        ]
    }

    /// Switch to a different language
    func selectLanguage(_ language: Language) {
        currentLanguage = language
        UserDefaults.standard.set(language.code, forKey: selectedLanguageKey)
        NSLog("NepaliInput: Language changed to \(language.name) (\(language.code))")
    }

    /// Toggle native numerals setting
    func toggleNativeNumerals() {
        useNativeNumerals.toggle()
        NSLog("NepaliInput: Native numerals set to \(useNativeNumerals)")
    }

    /// Get language by code
    func language(forCode code: String) -> Language? {
        return supportedLanguages.first { $0.code == code }
    }
}
