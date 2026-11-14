import Foundation

// MARK: - Transliteration Service

/// Produces transliteration candidates entirely on-device: the offline lexicon and phonetic engine,
/// re-ranked by the on-device ML adaptive engine. No network requests are made.
class TransliterationService {
    static let shared = TransliterationService()

    private var cache: [String: [String]] = [:]
    private let cacheLimit = 500

    private init() {}

    // MARK: - Public API

    /// Transliterate the given text, applying on-device ML adaptive re-ranking.
    /// The completion handler is called synchronously on the caller's thread.
    ///
    /// - Parameters:
    ///   - text: The Latin/English text to transliterate
    ///   - languageCode: Language code, passed through to the offline engine
    ///   - previousWord: Contextual preceding word used by the ML engine for bigram re-ranking
    ///   - completion: Called with an array of transliterated candidates
    func transliterate(
        text: String,
        languageCode: String,
        previousWord: String? = nil,
        completion: @escaping ([String]) -> Void
    ) {
        guard !text.isEmpty else {
            completion([])
            return
        }
        completion(candidates(for: text, languageCode: languageCode, previousWord: previousWord))
    }

    /// Synchronous cache lookup — returns cached results re-ranked with the latest ML model if available.
    func cachedResults(for text: String, languageCode: String, previousWord: String? = nil) -> [String]? {
        let cacheKey = "\(languageCode):\(text)"
        guard let cached = cache[cacheKey] else { return nil }
        return MLAdaptiveEngine.shared.rerank(
            candidates: cached,
            input: text,
            previousWord: previousWord
        )
    }

    /// Clear the candidate cache
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func candidates(for text: String, languageCode: String, previousWord: String?) -> [String] {
        let cacheKey = "\(languageCode):\(text)"

        let base: [String]
        if let cached = cache[cacheKey] {
            base = cached
        } else {
            base = OfflineTransliterationEngine.shared.transliterate(text: text, languageCode: languageCode)
            if !base.isEmpty {
                addToCache(key: cacheKey, value: base)
            }
        }

        return MLAdaptiveEngine.shared.rerank(
            candidates: base,
            input: text,
            previousWord: previousWord
        )
    }

    private func addToCache(key: String, value: [String]) {
        if cache.count >= cacheLimit {
            let keysToRemove = Array(cache.keys.prefix(cacheLimit / 4))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        cache[key] = value
    }
}
