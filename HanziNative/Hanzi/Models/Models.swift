import Foundation

struct Word: Identifiable, Hashable {
    let id: Int
    let simp: String
    let trad: String
    let pinyin: String
    let hanviet: String
    let hsk: Int?
    let rank: Int?
    let shortMean: String
    
    var tradIfDifferent: String? {
        (trad.isEmpty || trad == simp) ? nil : trad
    }
    var hanViet: String { hanviet }
}

struct Example: Identifiable, Hashable {
    let id: Int
    let zh: String
    let pinyin: String
    let mean: String
}

struct Sense: Identifiable, Hashable {
    let id: Int
    let kind: String?
    let gloss: String
    let explain: String?
    let examples: [Example]
}

struct Note: Identifiable, Hashable {
    var id: String { "\(kind)_\(title)" }
    let kind: String
    let title: String
    let body: String
    let examples: [Example]
}

struct HanChar: Identifiable, Hashable {
    var id: String { char }
    let char: String
    let strokes: [String]
    let medians: [[[Double]]]
    let strokeCount: Int
    let radical: String
    let radPinyin: String
    let radMeaning: String
    let pinyins: [String]
    let hanviets: [String]
    let shortMean: String
    let components: [String]
    let compDetail: [String]
    
    var canWrite: Bool { !strokes.isEmpty && !medians.isEmpty }
    var pinyin: String { pinyins.first ?? "" }
    var hanviet: String { hanviets.first ?? "" }
    var hanViet: String { hanviets.first ?? "" }
    var meaning: String { "" }
}

struct Topic: Identifiable, Hashable {
    let id: Int
    let name: String
    let count: Int
    var wordCount: Int { count }
    var desc: String { "" }
}

struct Grammar: Identifiable, Hashable {
    let id: Int
    let level: String
    let title: String
    let keywords: String
    let useFor: String
    let body: [String]
    
    var hsk: Int? {
        if level.uppercased().contains("HSK"), let last = level.last, let n = Int(String(last)) {
            return n
        }
        return nil
    }
    var pattern: String { keywords }
    var explanation: String { useFor }
}

struct SrsCard: Identifiable, Hashable {
    var id: Int { wordId }
    let wordId: Int
    let simp: String
    let pinyin: String
    let mean: String
    var reps: Int
    var intervalDays: Int
    var ease: Double
    var dueMs: Int64
    var lastReviewMs: Int64
    
    var front: String { simp }
    var meaning: String { mean }
    var hanViet: String { "" }
    
    init(wordId: Int, simp: String, pinyin: String, mean: String, reps: Int, intervalDays: Int, ease: Double, dueMs: Int64, lastReviewMs: Int64) {
        self.wordId = wordId
        self.simp = simp
        self.pinyin = pinyin
        self.mean = mean
        self.reps = reps
        self.intervalDays = intervalDays
        self.ease = ease
        self.dueMs = dueMs
        self.lastReviewMs = lastReviewMs
    }
    
    init(id: Int = 0, wordId: Int, front: String, pinyin: String, hanViet: String = "", meaning: String, intervalDays: Int = 1, easeFactor: Double = 2.5, reps: Int = 0, lapses: Int = 0, dueDays: Int = 0, lastReviewed: Int64? = nil) {
        self.wordId = wordId
        self.simp = front
        self.pinyin = pinyin
        self.mean = meaning
        self.intervalDays = intervalDays
        self.ease = easeFactor
        self.reps = reps
        self.dueMs = Int64(Date().timeIntervalSince1970 * 1000) + Int64(dueDays * 86400000)
        self.lastReviewMs = lastReviewed ?? Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func review(grade: Int) -> SrsCard {
        var copy = self
        copy.review(grade: grade, nowMs: nil)
        return copy
    }
    
    mutating func review(grade: Int, nowMs: Int64? = nil) {
        let now = nowMs ?? Int64(Date().timeIntervalSince1970 * 1000)
        lastReviewMs = now
        
        if grade == 0 { // Again
            reps = 0
            intervalDays = 0
            ease = max(1.3, min(3.0, ease - 0.2))
            dueMs = now + 10 * 60 * 1000 // 10 mins
            return
        }
        
        if grade == 1 { // Hard
            ease = max(1.3, min(3.0, ease - 0.15))
            intervalDays = reps == 0 ? 1 : max(1, min(3650, Int(Double(intervalDays) * 1.2)))
        } else if grade == 2 { // Good
            if reps == 0 {
                intervalDays = 1
            } else if reps == 1 {
                intervalDays = 3
            } else {
                intervalDays = max(1, min(3650, Int(Double(intervalDays) * ease)))
            }
        } else { // Easy
            ease = max(1.3, min(3.0, ease + 0.15))
            if reps == 0 {
                intervalDays = 4
            } else {
                intervalDays = max(2, min(3650, Int(Double(intervalDays) * ease * 1.3)))
            }
        }
        reps += 1
        dueMs = now + Int64(intervalDays) * 86_400_000
    }
}
