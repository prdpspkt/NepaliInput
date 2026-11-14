import Foundation

// MARK: - Machine Learning Adaptive Re-ranking Engine

/// Manages on-device adaptive learning and re-ranking for Nepali Input candidates.
///
/// Features:
/// 1. Personalized Vocabulary Learning: Remembers words the user frequently selects.
/// 2. N-Gram Context Modeling: Learns word transitions (e.g., following "खाना", "पानी" ranks higher than "पनि").
/// 3. Recency Scoring: Recently typed words receive exponential recency boosts.
/// 4. Dynamic Candidate Injection: Custom names and unique spellings committed by the user
///    are retained and injected into candidates even if Google API misses them or when offline.
/// 5. 100% On-Device & Private: No telemetry or typing data is ever transmitted.
class MLAdaptiveEngine {
    static let shared = MLAdaptiveEngine()

    private let enabledKey = "NepaliInput_AdaptiveLearningEnabled"
    private let queue = DispatchQueue(label: "com.pradeeps.nepaliinput.ml", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?

    /// Whether adaptive ML re-ranking is enabled
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        }
    }

    // MARK: - Model State

    /// Mapping of Latin input -> [Candidate: FrequencyCount]
    private var inputFrequency: [String: [String: Int]] = [:]

    /// Bigram transition table: previousWord -> [currentWord: TransitionCount]
    private var bigramTransitions: [String: [String: Int]] = [:]

    /// Recency tracking: Candidate -> Epoch timestamp of last usage
    private var lastUsedTimestamps: [String: TimeInterval] = [:]

    /// Total count of learned user words
    var learnedWordsCount: Int {
        var count = 0
        queue.sync {
            count = inputFrequency.values.reduce(0) { $0 + $1.count }
        }
        return count
    }

    private let storageURL: URL

    private init() {
        if UserDefaults.standard.object(forKey: enabledKey) != nil {
            self.isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        } else {
            self.isEnabled = true
        }

        // Setup persistent storage in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("NepaliInput", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.storageURL = appDir.appendingPathComponent("adaptive_model.json")

        loadModel()
    }

    // MARK: - Learning API

    /// Records the user's chosen candidate for a given Latin input and preceding context word
    func recordCommit(candidate: String, input: String, previousWord: String?) {
        guard isEnabled, !candidate.isEmpty, !input.isEmpty else { return }

        queue.async { [weak self] in
            guard let self = self else { return }
            let lowerInput = input.lowercased()

            // 1. Update frequency for this input
            var forInput = self.inputFrequency[lowerInput] ?? [:]
            forInput[candidate, default: 0] += 1
            self.inputFrequency[lowerInput] = forInput

            // 2. Update bigram transition if previous word exists
            if let prev = previousWord, !prev.isEmpty {
                var forPrev = self.bigramTransitions[prev] ?? [:]
                forPrev[candidate, default: 0] += 1
                self.bigramTransitions[prev] = forPrev
            }

            // 3. Update recency
            self.lastUsedTimestamps[candidate] = Date().timeIntervalSince1970

            // 4. Debounced save to disk
            self.scheduleSave()
        }
    }

    // MARK: - Re-ranking API

    /// Re-ranks candidates using the adaptive model (Frequency + Bigram Transition + Recency + Prior Rank)
    func rerank(candidates: [String], input: String, previousWord: String?) -> [String] {
        guard isEnabled, !candidates.isEmpty else { return candidates }

        return queue.sync {
            let lowerInput = input.lowercased()
            let now = Date().timeIntervalSince1970
            var allCandidates = candidates

            // Inject any learned candidates for this input not already present
            if let learned = self.inputFrequency[lowerInput] {
                for (cand, _) in learned {
                    if !allCandidates.contains(cand) {
                        allCandidates.append(cand)
                    }
                }
            }

            struct CandidateScore {
                let candidate: String
                let score: Double
            }

            let scored = allCandidates.enumerated().map { (index, candidate) -> CandidateScore in
                // 1. Base prior rank score (1.0 for first, 0.5 for second, etc.)
                let baseScore = 1.0 / Double(index + 1)

                // 2. User frequency score for this specific Latin input
                let count = self.inputFrequency[lowerInput]?[candidate] ?? 0
                let freqScore = log(1.0 + Double(count)) * 2.2

                // 3. Contextual bigram transition score
                var bigramScore = 0.0
                if let prev = previousWord, !prev.isEmpty,
                   let transitions = self.bigramTransitions[prev],
                   let transCount = transitions[candidate] {
                    bigramScore = log(1.0 + Double(transCount)) * 2.8
                }

                // 4. Recency boost (exponential decay over 7 days)
                var recencyScore = 0.0
                if let lastTime = self.lastUsedTimestamps[candidate] {
                    let delta = max(0, now - lastTime)
                    recencyScore = exp(-delta / (7.0 * 86400.0)) * 0.75
                }

                let totalScore = baseScore + freqScore + bigramScore + recencyScore
                return CandidateScore(candidate: candidate, score: totalScore)
            }

            return scored.sorted(by: { $0.score > $1.score }).map { $0.candidate }
        }
    }

    /// Clears all learned frequencies, transitions, and recency data
    func resetLearnedData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.inputFrequency.removeAll()
            self.bigramTransitions.removeAll()
            self.lastUsedTimestamps.removeAll()
            try? FileManager.default.removeItem(at: self.storageURL)
            NSLog("NepaliInput: ML adaptive data has been reset.")
        }
    }

    // MARK: - Persistence

    private struct ModelData: Codable {
        let inputFrequency: [String: [String: Int]]
        let bigramTransitions: [String: [String: Int]]
        let lastUsedTimestamps: [String: TimeInterval]
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        saveWorkItem = work
        // Save to disk after 3 seconds of inactivity
        queue.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    func saveToDisk() {
        let model = ModelData(
            inputFrequency: inputFrequency,
            bigramTransitions: bigramTransitions,
            lastUsedTimestamps: lastUsedTimestamps
        )
        do {
            let data = try JSONEncoder().encode(model)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("NepaliInput: Failed to save adaptive model: \(error)")
        }
    }

    private func loadModel() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let model = try JSONDecoder().decode(ModelData.self, from: data)
            self.inputFrequency = model.inputFrequency
            self.bigramTransitions = model.bigramTransitions
            self.lastUsedTimestamps = model.lastUsedTimestamps
            NSLog("NepaliInput: Loaded ML model with \(model.inputFrequency.count) learned inputs.")
        } catch {
            NSLog("NepaliInput: Failed to load adaptive model: \(error)")
        }
    }
}
