import Foundation

// MARK: - Transliteration Service

/// Handles communication with the Google Input Tools transliteration API,
/// integrated with an on-device ML Adaptive Re-ranking Engine and an
/// Offline Transliteration Fallback Engine.
class TransliterationService {
    static let shared = TransliterationService()

    private let session: URLSession
    private var currentTask: URLSessionDataTask?
    private var debounceWorkItem: DispatchWorkItem?
    private var cache: [String: [String]] = [:]
    private let cacheLimit = 500

    /// Debounce interval in seconds — how long to wait after last keystroke
    /// before making an API call. Kept very low for responsive inline transliteration.
    var debounceInterval: TimeInterval = 0.03

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.0
        config.timeoutIntervalForResource = 3.0
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Transliterate the given text into the target language, applying on-device ML adaptive re-ranking.
    /// Results are delivered on the main thread via the completion handler.
    ///
    /// - Parameters:
    ///   - text: The Latin/English text to transliterate
    ///   - languageCode: The Google ITC language code (e.g., "ne-t-i0-und")
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

        // Check cache first; re-rank with current context if found
        let cacheKey = "\(languageCode):\(text)"
        if let cached = cache[cacheKey] {
            let reranked = MLAdaptiveEngine.shared.rerank(
                candidates: cached,
                input: text,
                previousWord: previousWord
            )
            completion(reranked)
            return
        }

        // Cancel previous pending request
        debounceWorkItem?.cancel()
        currentTask?.cancel()

        // Debounce: wait a short interval before making the API call
        let workItem = DispatchWorkItem { [weak self] in
            self?.performRequest(text: text, languageCode: languageCode, previousWord: previousWord) { results in
                DispatchQueue.main.async {
                    completion(results)
                }
            }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
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

    /// Clear the translation cache
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func performRequest(
        text: String,
        languageCode: String,
        previousWord: String?,
        completion: @escaping ([String]) -> Void
    ) {
        var components = URLComponents(string: "https://inputtools.google.com/request")!
        components.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "itc", value: languageCode),
            URLQueryItem(name: "num", value: "9"),
            URLQueryItem(name: "cp", value: "0"),
            URLQueryItem(name: "cs", value: "1"),
            URLQueryItem(name: "ie", value: "utf-8"),
            URLQueryItem(name: "oe", value: "utf-8"),
            URLQueryItem(name: "app", value: "NepaliInput"),
        ]

        guard let url = components.url else {
            NSLog("NepaliInput: Failed to construct URL for text: \(text)")
            fallbackOffline(text: text, languageCode: languageCode, previousWord: previousWord, completion: completion)
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            // Handle cancellation silently
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }

            guard let self = self else { return }

            if let error = error {
                NSLog("NepaliInput: Network error, falling back to offline ML engine: \(error.localizedDescription)")
                self.fallbackOffline(text: text, languageCode: languageCode, previousWord: previousWord, completion: completion)
                return
            }

            guard let data = data else {
                self.fallbackOffline(text: text, languageCode: languageCode, previousWord: previousWord, completion: completion)
                return
            }

            let apiCandidates = self.parseResponse(data: data)
            let baseCandidates: [String]
            if !apiCandidates.isEmpty {
                baseCandidates = apiCandidates
            } else {
                baseCandidates = OfflineTransliterationEngine.shared.transliterate(text: text, languageCode: languageCode)
            }

            // Cache raw candidates
            if !baseCandidates.isEmpty {
                let cacheKey = "\(languageCode):\(text)"
                self.addToCache(key: cacheKey, value: baseCandidates)
            }

            // Apply On-Device ML Adaptive Re-ranking
            let finalCandidates = MLAdaptiveEngine.shared.rerank(
                candidates: baseCandidates,
                input: text,
                previousWord: previousWord
            )

            completion(finalCandidates)
        }

        currentTask = task
        task.resume()
    }

    private func fallbackOffline(
        text: String,
        languageCode: String,
        previousWord: String?,
        completion: @escaping ([String]) -> Void
    ) {
        let offlineCandidates = OfflineTransliterationEngine.shared.transliterate(text: text, languageCode: languageCode)
        let reranked = MLAdaptiveEngine.shared.rerank(
            candidates: offlineCandidates,
            input: text,
            previousWord: previousWord
        )
        completion(reranked)
    }

    /// Parse the Google Input Tools API response.
    private func parseResponse(data: Data) -> [String] {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                return []
            }

            guard json.count >= 2,
                  let status = json[0] as? String,
                  status == "SUCCESS" else {
                return []
            }

            guard let results = json[1] as? [[Any]],
                  let firstResult = results.first,
                  firstResult.count >= 2,
                  let candidates = firstResult[1] as? [String] else {
                return []
            }

            return candidates
        } catch {
            return []
        }
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
