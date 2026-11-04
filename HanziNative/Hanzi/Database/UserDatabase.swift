import Foundation
import SQLite3

final class UserDatabase: ObservableObject {
    static let shared = UserDatabase()
    private var db: OpaquePointer?
    
    @Published var streakCount: Int = 0
    @Published var favoritesCount: Int = 0
    
    func streakDays() -> Int {
        return streakCount
    }
    
    func removeFavorite(wordId: Int) {
        setFavorite(wordId: wordId, simp: "", pinyin: "", mean: "", fav: false)
    }
    
    private init() {
        openDb()
        createTables()
        updateStreak()
    }
    
    deinit {
        if let db = db { sqlite3_close(db) }
    }
    
    private func openDb() {
        let fileManager = FileManager.default
        let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = docURL.appendingPathComponent("user.sqlite3").path
        
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Failed to open user.sqlite3")
        }
    }
    
    private func createTables() {
        guard let db = db else { return }
        let sql = """
        CREATE TABLE IF NOT EXISTS favorites (word_id INTEGER PRIMARY KEY, simp TEXT, pinyin TEXT, mean TEXT, added INTEGER);
        CREATE TABLE IF NOT EXISTS history (word_id INTEGER PRIMARY KEY, simp TEXT, pinyin TEXT, mean TEXT, ts INTEGER);
        CREATE TABLE IF NOT EXISTS writing (char TEXT PRIMARY KEY, attempts INTEGER, mistakes INTEGER, best INTEGER, ts INTEGER);
        CREATE TABLE IF NOT EXISTS srs (word_id INTEGER PRIMARY KEY, simp TEXT, pinyin TEXT, mean TEXT, reps INTEGER DEFAULT 0, interval_days INTEGER DEFAULT 0, ease REAL DEFAULT 2.5, due INTEGER DEFAULT 0, last_review INTEGER DEFAULT 0);
        CREATE TABLE IF NOT EXISTS quiz_runs (id INTEGER PRIMARY KEY AUTOINCREMENT, mode TEXT, score INTEGER, total INTEGER, ts INTEGER);
        CREATE TABLE IF NOT EXISTS activity_days (day TEXT PRIMARY KEY, actions INTEGER DEFAULT 1);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }
    
    private var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
    
    private var todayKey: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }
    
    func touchActivity() {
        guard let db = db else { return }
        let sql = "INSERT INTO activity_days (day, actions) VALUES (?, 1) ON CONFLICT(day) DO UPDATE SET actions = actions + 1"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (todayKey as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        updateStreak()
    }
    
    func updateStreak() {
        guard let db = db else { return }
        let sql = "SELECT day FROM activity_days ORDER BY day DESC LIMIT 400"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var days = Set<String>()
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let str = sqlite3_column_text(stmt, 0) {
                    days.insert(String(cString: str))
                }
            }
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var cursor = Date()
        var curStr = df.string(from: cursor)
        
        if !days.contains(curStr) {
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            curStr = df.string(from: cursor)
            if !days.contains(curStr) {
                DispatchQueue.main.async { self.streakCount = 0 }
                return
            }
        }
        
        var count = 0
        while days.contains(curStr) {
            count += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            curStr = df.string(from: cursor)
        }
        
        DispatchQueue.main.async {
            self.streakCount = count
        }
    }
    
    // MARK: - Favorites
    
    func isFavorite(wordId: Int) -> Bool {
        guard let db = db else { return false }
        let sql = "SELECT 1 FROM favorites WHERE word_id = ? LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(wordId))
            return sqlite3_step(stmt) == SQLITE_ROW
        }
        return false
    }
    
    func setFavorite(wordId: Int, simp: String, pinyin: String, mean: String, fav: Bool) {
        guard let db = db else { return }
        if fav {
            let sql = "INSERT OR REPLACE INTO favorites (word_id, simp, pinyin, mean, added) VALUES (?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(wordId))
                sqlite3_bind_text(stmt, 2, (simp as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (pinyin as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (mean as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 5, nowMs)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
            addSrsIfAbsent(wordId: wordId, simp: simp, pinyin: pinyin, mean: mean)
            touchActivity()
        } else {
            let sql = "DELETE FROM favorites WHERE word_id = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(wordId))
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
    func favorites() -> [Word] {
        guard let db = db else { return [] }
        let sql = "SELECT word_id, simp, pinyin, mean FROM favorites ORDER BY added DESC"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Word] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let simp = String(cString: sqlite3_column_text(stmt, 1))
                let pinyin = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let mean = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                result.append(Word(id: id, simp: simp, trad: "", pinyin: pinyin, hanviet: "", hsk: nil, rank: nil, shortMean: mean))
            }
        }
        return result
    }
    
    // MARK: - History
    
    func addHistory(wordId: Int, simp: String, pinyin: String, mean: String) {
        guard let db = db else { return }
        let sql = "INSERT OR REPLACE INTO history (word_id, simp, pinyin, mean, ts) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(wordId))
            sqlite3_bind_text(stmt, 2, (simp as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (pinyin as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (mean as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, nowMs)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        
        let trimSql = "DELETE FROM history WHERE word_id NOT IN (SELECT word_id FROM history ORDER BY ts DESC LIMIT 200)"
        sqlite3_exec(db, trimSql, nil, nil, nil)
    }
    
    func history() -> [Word] {
        guard let db = db else { return [] }
        let sql = "SELECT word_id, simp, pinyin, mean FROM history ORDER BY ts DESC LIMIT 80"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Word] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let simp = String(cString: sqlite3_column_text(stmt, 1))
                let pinyin = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
                let mean = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                result.append(Word(id: id, simp: simp, trad: "", pinyin: pinyin, hanviet: "", hsk: nil, rank: nil, shortMean: mean))
            }
        }
        return result
    }
    
    func clearHistory() {
        guard let db = db else { return }
        sqlite3_exec(db, "DELETE FROM history", nil, nil, nil)
    }
    
    // MARK: - SRS Flashcards
    
    func addSrsIfAbsent(wordId: Int, simp: String, pinyin: String, mean: String) {
        guard let db = db else { return }
        let sql = "INSERT OR IGNORE INTO srs (word_id, simp, pinyin, mean, reps, interval_days, ease, due, last_review) VALUES (?, ?, ?, ?, 0, 0, 2.5, ?, 0)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(wordId))
            sqlite3_bind_text(stmt, 2, (simp as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (pinyin as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (mean as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(stmt, 5, nowMs)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }
    
    func importWordsToSrs(_ words: [(id: Int, simp: String, pinyin: String, mean: String)]) {
        for w in words {
            addSrsIfAbsent(wordId: w.id, simp: w.simp, pinyin: w.pinyin, mean: w.mean)
        }
    }
    
    func dueSrsCards(limit: Int = 50) -> [SrsCard] {
        guard let db = db else { return [] }
        let sql = "SELECT word_id, simp, pinyin, mean, reps, interval_days, ease, due, last_review FROM srs WHERE due <= ? ORDER BY due ASC LIMIT ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [SrsCard] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, nowMs)
            sqlite3_bind_int(stmt, 2, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(parseSrs(stmt))
            }
        }
        return result
    }
    
    func allSrsCards(limit: Int = 200) -> [SrsCard] {
        guard let db = db else { return [] }
        let sql = "SELECT word_id, simp, pinyin, mean, reps, interval_days, ease, due, last_review FROM srs ORDER BY due ASC LIMIT ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [SrsCard] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(parseSrs(stmt))
            }
        }
        return result
    }
    
    func saveSrsCard(card: SrsCard) {
        saveSrsCard(card)
    }

    func saveSrsCard(_ card: SrsCard) {
        guard let db = db else { return }
        let sql = "INSERT OR REPLACE INTO srs (word_id, simp, pinyin, mean, reps, interval_days, ease, due, last_review) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(card.wordId))
            sqlite3_bind_text(stmt, 2, (card.simp as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (card.pinyin as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 4, (card.mean as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 5, Int32(card.reps))
            sqlite3_bind_int(stmt, 6, Int32(card.intervalDays))
            sqlite3_bind_double(stmt, 7, card.ease)
            sqlite3_bind_int64(stmt, 8, card.dueMs)
            sqlite3_bind_int64(stmt, 9, card.lastReviewMs)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        touchActivity()
    }
    
    func srsSummary() -> (total: Int, due: Int, mastered: Int) {
        guard let db = db else { return (0, 0, 0) }
        var total = 0
        var due = 0
        var mastered = 0
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM srs", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { total = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM srs WHERE due <= ?", -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(stmt, 1, nowMs)
            if sqlite3_step(stmt) == SQLITE_ROW { due = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM srs WHERE interval_days >= 21", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW { mastered = Int(sqlite3_column_int(stmt, 0)) }
        }
        sqlite3_finalize(stmt)
        
        return (total, due, mastered)
    }
    
    // MARK: - Writing Stats
    
    func recordWriting(char: String, mistakes: Int, score: Int) {
        guard let db = db else { return }
        let sql = """
        INSERT INTO writing (char, attempts, mistakes, best, ts) VALUES (?, 1, ?, ?, ?) 
        ON CONFLICT(char) DO UPDATE SET attempts = attempts + 1, mistakes = mistakes + excluded.mistakes, best = MAX(best, excluded.best), ts = excluded.ts
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (char as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(mistakes))
            sqlite3_bind_int(stmt, 3, Int32(score))
            sqlite3_bind_int64(stmt, 4, nowMs)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
        touchActivity()
    }
    
    func charWritingStat(char: String) -> (attempts: Int, best: Int) {
        guard let db = db else { return (0, 0) }
        let sql = "SELECT attempts, best FROM writing WHERE char = ? LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (char as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                return (Int(sqlite3_column_int(stmt, 0)), Int(sqlite3_column_int(stmt, 1)))
            }
        }
        return (0, 0)
    }
    
    func writingStats() -> [[String: Any]] {
        guard let db = db else { return [] }
        let sql = "SELECT char, attempts, mistakes, best FROM writing ORDER BY ts DESC"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [[String: Any]] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let char = String(cString: sqlite3_column_text(stmt, 0))
                let attempts = Int(sqlite3_column_int(stmt, 1))
                let mistakes = Int(sqlite3_column_int(stmt, 2))
                let best = Int(sqlite3_column_int(stmt, 3))
                result.append([
                    "char": char,
                    "count": attempts,
                    "attempts": attempts,
                    "mistakes": mistakes,
                    "best": best
                ])
            }
        }
        return result
    }
    
    // MARK: - Helpers
    
    private func parseSrs(_ stmt: OpaquePointer?) -> SrsCard {
        let wordId = Int(sqlite3_column_int(stmt, 0))
        let simp = String(cString: sqlite3_column_text(stmt, 1))
        let pinyin = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
        let mean = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let reps = Int(sqlite3_column_int(stmt, 4))
        let intervalDays = Int(sqlite3_column_int(stmt, 5))
        let ease = sqlite3_column_double(stmt, 6)
        let due = sqlite3_column_int64(stmt, 7)
        let lastReview = sqlite3_column_int64(stmt, 8)
        
        return SrsCard(wordId: wordId, simp: simp, pinyin: pinyin, mean: mean, reps: reps, intervalDays: intervalDays, ease: ease, dueMs: due, lastReviewMs: lastReview)
    }
}
