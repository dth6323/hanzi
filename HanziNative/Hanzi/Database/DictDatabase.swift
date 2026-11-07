import Foundation
import SQLite3

private func sqliteString(_ stmt: OpaquePointer?, _ index: Int32) -> String {
    guard let stmt = stmt, let ptr = sqlite3_column_text(stmt, index) else { return "" }
    return String(cString: ptr)
}
private func sqliteStringOpt(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    guard let stmt = stmt, let ptr = sqlite3_column_text(stmt, index) else { return nil }
    return String(cString: ptr)
}


final class DictDatabase {
    static let shared = DictDatabase()
    private var db: OpaquePointer?
    
    private init() {
        openDb()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    private func openDb() {
        // Look for bundled vi_full.db or in Documents
        if let bundlePath = Bundle.main.path(forResource: "vi_full", ofType: "db") {
            if sqlite3_open_v2(bundlePath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK {
                return
            }
        }
        
        let fileManager = FileManager.default
        let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dbPath = docURL.appendingPathComponent("vi_full.db").path
        
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("Failed to open vi_full.db")
        }
    }
    
    private let wordCols = "id, simp, trad, pinyin, hanviet, hsk, rank, short_mean"
    
    // MARK: - Search
    
    func search(_ raw: String, limit: Int = 60) -> [Word] {
        guard let db = db else { return [] }
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return [] }
        
        if hasCjk(q) {
            let sql = """
            SELECT \(wordCols) FROM words 
            WHERE simp LIKE ? OR trad LIKE ? 
            ORDER BY (simp = ? OR trad = ?) DESC, length(simp), rank 
            LIMIT ?
            """
            var stmt: OpaquePointer?
            var words: [Word] = []
            
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                let likeQ = "\(q)%"
                sqlite3_bind_text(stmt, 1, (likeQ as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (likeQ as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (q as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (q as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 5, Int32(limit))
                
                while sqlite3_step(stmt) == SQLITE_ROW {
                    words.append(parseWord(stmt))
                }
            }
            sqlite3_finalize(stmt)
            
            if words.count < 10 && q.count > 1 {
                let fallbackSql = "SELECT \(wordCols) FROM words WHERE simp LIKE ? ORDER BY rank LIMIT ?"
                if sqlite3_prepare_v2(db, fallbackSql, -1, &stmt, nil) == SQLITE_OK {
                    let containsQ = "%\(q)%"
                    sqlite3_bind_text(stmt, 1, (containsQ as NSString).utf8String, -1, nil)
                    sqlite3_bind_int(stmt, 2, Int32(limit))
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        let w = parseWord(stmt)
                        if !words.contains(where: { $0.id == w.id }) {
                            words.append(w)
                        }
                    }
                }
                sqlite3_finalize(stmt)
            }
            return words
        }
        
        let plain = removeDiacritics(q.lowercased())
        let key = plain.components(separatedBy: CharacterSet.letters.inverted).joined()
        let spaced = plain.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
        var result: [Word] = []
        var seenIds = Set<Int>()
        
        if !key.isEmpty {
            let pySql = "SELECT \(wordCols) FROM words WHERE pinyin_key LIKE ? ORDER BY (pinyin_key = ?) DESC, rank LIMIT 30"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, pySql, -1, &stmt, nil) == SQLITE_OK {
                let keyLike = "\(key)%"
                sqlite3_bind_text(stmt, 1, (keyLike as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (key as NSString).utf8String, -1, nil)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let w = parseWord(stmt)
                    if seenIds.insert(w.id).inserted {
                        result.append(w)
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        if !spaced.isEmpty {
            let hvSql = "SELECT \(wordCols) FROM words WHERE hanviet_key LIKE ? ORDER BY (hanviet_key = ?) DESC, rank LIMIT 20"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, hvSql, -1, &stmt, nil) == SQLITE_OK {
                let spacedLike = "\(spaced)%"
                sqlite3_bind_text(stmt, 1, (spacedLike as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (spaced as NSString).utf8String, -1, nil)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let w = parseWord(stmt)
                    if seenIds.insert(w.id).inserted {
                        result.append(w)
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        if !spaced.isEmpty {
            let ftsSql = """
            SELECT \(wordCols) FROM words WHERE id IN 
            (SELECT rowid FROM mean_fts WHERE mean_fts MATCH ? LIMIT 300) 
            ORDER BY rank IS NULL, rank LIMIT 30
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, ftsSql, -1, &stmt, nil) == SQLITE_OK {
                let match = "\"\(spaced)\""
                sqlite3_bind_text(stmt, 1, (match as NSString).utf8String, -1, nil)
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let w = parseWord(stmt)
                    if seenIds.insert(w.id).inserted {
                        result.append(w)
                    }
                }
            } else {
                // Fallback for like
                let likeSql = """
                SELECT \(wordCols) FROM words WHERE id IN 
                (SELECT id FROM mean_fts_content WHERE c0 LIKE ? LIMIT 200) 
                ORDER BY rank IS NULL, rank LIMIT 30
                """
                if sqlite3_prepare_v2(db, likeSql, -1, &stmt, nil) == SQLITE_OK {
                    let pLike = "%\(spaced)%"
                    sqlite3_bind_text(stmt, 1, (pLike as NSString).utf8String, -1, nil)
                    while sqlite3_step(stmt) == SQLITE_ROW {
                        let w = parseWord(stmt)
                        if seenIds.insert(w.id).inserted {
                            result.append(w)
                        }
                    }
                }
            }
            sqlite3_finalize(stmt)
        }
        
        return Array(result.prefix(limit))
    }
    
    // MARK: - Word Detail
    
    func word(id: Int) -> Word? {
        guard let db = db else { return nil }
        let sql = "SELECT \(wordCols) FROM words WHERE id = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(id))
            if sqlite3_step(stmt) == SQLITE_ROW {
                return parseWord(stmt)
            }
        }
        return nil
    }
    
    func wordBySimp(_ simp: String) -> Word? {
        guard let db = db else { return nil }
        let sql = "SELECT \(wordCols) FROM words WHERE simp = ? ORDER BY rank LIMIT 1"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (simp as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                return parseWord(stmt)
            }
        }
        return nil
    }
    
    func senses(wordId: Int) -> [Sense] {
        guard let db = db else { return [] }
        let sql = "SELECT id, kind, gloss, explain FROM senses WHERE word_id = ? ORDER BY sort"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Sense] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(wordId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let kind = sqliteStringOpt(stmt, 1)
                let gloss = sqliteString(stmt, 2)
                let explain = sqliteStringOpt(stmt, 3)
                
                let examples = senseExamples(senseId: id)
                result.append(Sense(id: id, kind: kind, gloss: gloss, explain: explain, examples: examples))
            }
        }
        return result
    }
    
    private func senseExamples(senseId: Int) -> [Example] {
        guard let db = db else { return [] }
        let sql = """
        SELECT e.id, e.zh, e.pinyin, e.mean FROM sense_examples se 
        JOIN examples e ON e.id = se.example_id 
        WHERE se.sense_id = ? ORDER BY se.sort LIMIT 6
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Example] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(senseId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(parseExample(stmt))
            }
        }
        return result
    }
    
    func relations(wordId: Int) -> [String: [String]] {
        guard let db = db else { return [:] }
        let sql = "SELECT kind, target, extra FROM word_rel WHERE word_id = ? ORDER BY kind, sort"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var map: [String: [String]] = [:]
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(wordId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let kind = sqliteString(stmt, 0)
                var target = sqliteString(stmt, 1)
                let extra = sqliteString(stmt, 2)
                if kind == "measure" && !extra.isEmpty {
                    target = "\(target) (\(extra))"
                }
                map[kind, default: []].append(target)
            }
        }
        return map
    }
    
    func notes(wordId: Int) -> [Note] {
        guard let db = db else { return [] }
        let sql = "SELECT kind, title, body, examples FROM notes WHERE word_id = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Note] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(wordId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let kind = sqliteString(stmt, 0)
                let title = sqliteString(stmt, 1)
                let body = sqliteStringOpt(stmt, 2) ?? ""
                let examplesStr = sqliteStringOpt(stmt, 3) ?? "[]"
                
                var examples: [Example] = []
                if let data = examplesStr.data(using: .utf8),
                   let ids = try? JSONSerialization.jsonObject(with: data) as? [Int], !ids.isEmpty {
                    examples = fetchExamples(ids: ids)
                }
                result.append(Note(kind: kind, title: title, body: body, examples: examples))
            }
        }
        return result
    }
    
    private func fetchExamples(ids: [Int]) -> [Example] {
        guard let db = db, !ids.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let sql = "SELECT id, zh, pinyin, mean FROM examples WHERE id IN (\(placeholders))"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Example] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            for (idx, id) in ids.enumerated() {
                sqlite3_bind_int(stmt, Int32(idx + 1), Int32(id))
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(parseExample(stmt))
            }
        }
        return result
    }
    
    // MARK: - Character
    
    func char(_ c: String) -> HanChar? {
        guard let db = db else { return nil }
        let sql = "SELECT * FROM chars WHERE char = ?"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (c as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let char = sqliteString(stmt, 0)
                let strokesJson = sqliteString(stmt, 1)
                let mediansJson = sqliteString(stmt, 2)
                let strokeCount = Int(sqlite3_column_int(stmt, 3))
                let radical = sqliteString(stmt, 4)
                let radPinyin = sqliteStringOpt(stmt, 5) ?? ""
                let radMeaning = sqliteStringOpt(stmt, 6) ?? ""
                let pinyinsJson = sqliteString(stmt, 7)
                let hanvietsJson = sqliteString(stmt, 8)
                let shortMean = sqliteStringOpt(stmt, 9) ?? ""
                let componentsJson = sqliteString(stmt, 10)
                let compDetailJson = sqliteString(stmt, 11)
                
                let strokes = (try? JSONDecoder().decode([String].self, from: Data(strokesJson.utf8))) ?? []
                let medians = (try? JSONDecoder().decode([[[Double]]].self, from: Data(mediansJson.utf8))) ?? []
                let pinyins = (try? JSONDecoder().decode([String].self, from: Data(pinyinsJson.utf8))) ?? []
                let hanviets = (try? JSONDecoder().decode([String].self, from: Data(hanvietsJson.utf8))) ?? []
                let components = (try? JSONDecoder().decode([String].self, from: Data(componentsJson.utf8))) ?? []
                let compDetail = (try? JSONDecoder().decode([String].self, from: Data(compDetailJson.utf8))) ?? []
                
                return HanChar(
                    char: char,
                    strokes: strokes,
                    medians: medians,
                    strokeCount: strokeCount,
                    radical: radical,
                    radPinyin: radPinyin,
                    radMeaning: radMeaning,
                    pinyins: pinyins,
                    hanviets: hanviets,
                    shortMean: shortMean,
                    components: components,
                    compDetail: compDetail
                )
            }
        }
        return nil
    }
    
    // MARK: - Learn & HSK
    
    func wordsByHsk(level: Int) -> [Word] {
        guard let db = db else { return [] }
        let sql = "SELECT \(wordCols) FROM words WHERE hsk = ? ORDER BY rank"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Word] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(level))
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(parseWord(stmt))
            }
        }
        return result
    }
    
    func topics() -> [Topic] {
        guard let db = db else { return [] }
        let sql = """
        SELECT t.id, t.name, COUNT(wt.word_id) AS n FROM topics t 
        JOIN word_topics wt ON wt.topic_id = t.id 
        GROUP BY t.id ORDER BY t.name
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Topic] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let name = sqliteString(stmt, 1)
                let n = Int(sqlite3_column_int(stmt, 2))
                result.append(Topic(id: id, name: name, count: n))
            }
        }
        return result
    }
    
    func wordsByTopic(topicId: Int) -> [Word] {
        guard let db = db else { return [] }
        let sql = """
        SELECT w.id, w.simp, w.trad, w.pinyin, w.hanviet, w.hsk, w.rank, w.short_mean 
        FROM word_topics wt JOIN words w ON w.id = wt.word_id 
        WHERE wt.topic_id = ? ORDER BY w.rank IS NULL, w.rank
        """
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Word] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(topicId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(parseWord(stmt))
            }
        }
        return result
    }
    
    func grammarLevels() -> [String] {
        guard let db = db else { return [] }
        let sql = "SELECT level FROM grammar GROUP BY level ORDER BY MIN(id)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [String] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let str = sqliteString(stmt, 0)
                if !str.isEmpty {
                    result.append(str)
                }
            }
        }
        return result
    }
    
    func allGrammar() -> [Grammar] {
        guard let db = db else { return [] }
        let sql = "SELECT id, level, title, keywords, use_for, body FROM grammar ORDER BY id"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Grammar] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let lv = sqliteString(stmt, 1)
                let title = sqliteString(stmt, 2)
                let keywords = sqliteStringOpt(stmt, 3) ?? ""
                let useFor = sqliteStringOpt(stmt, 4) ?? ""
                let bodyJson = sqliteStringOpt(stmt, 5) ?? "[]"
                let body = (try? JSONDecoder().decode([String].self, from: Data(bodyJson.utf8))) ?? []
                result.append(Grammar(id: id, level: lv, title: title, keywords: keywords, useFor: useFor, body: body))
            }
        }
        return result
    }

    func grammarByLevel(_ level: String) -> [Grammar] {
        guard let db = db else { return [] }
        let sql = "SELECT id, level, title, keywords, use_for, body FROM grammar WHERE level = ? ORDER BY id"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Grammar] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (level as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let lv = sqliteString(stmt, 1)
                let title = sqliteString(stmt, 2)
                let keywords = sqliteStringOpt(stmt, 3) ?? ""
                let useFor = sqliteStringOpt(stmt, 4) ?? ""
                let bodyJson = sqliteStringOpt(stmt, 5) ?? "[]"
                let body = (try? JSONDecoder().decode([String].self, from: Data(bodyJson.utf8))) ?? []
                
                result.append(Grammar(id: id, level: lv, title: title, keywords: keywords, useFor: useFor, body: body))
            }
        }
        return result
    }
    
    func allTopics() -> [Topic] {
        return topics()
    }
    
    func wordsForTopic(topicId: Int, limit: Int = 100) -> [Word] {
        return wordsByTopic(topicId: topicId)
    }

    func wordsForHsk(level: Int, limit: Int = 100) -> [Word] {
        return wordsByHsk(level: level)
    }

    func getChar(char: String) -> HanChar? {
        return self.char(char)
    }

    func search(query: String, limit: Int = 60) -> [Word] {
        return search(query, limit: limit)
    }

    func segmentChineseText(text: String) -> [Word] {
        guard let db = db else { return [] }
        let chars = TextUtils.cjkChars(in: text)
        if chars.isEmpty { return [] }
        let joined = chars.joined()
        var candidates = Set<String>()
        let characters = Array(joined)
        for i in 0..<characters.count {
            for len in 1...min(4, characters.count - i) {
                let sub = String(characters[i..<(i + len)])
                candidates.insert(sub)
            }
        }
        if candidates.isEmpty { return [] }
        
        var results: [Word] = []
        let sortedCandidates = Array(candidates).sorted(by: { $0.count > $1.count })
        for wordStr in sortedCandidates {
            let sql = "SELECT \(wordCols) FROM words WHERE simp = ? OR trad = ? ORDER BY rank IS NULL, rank ASC LIMIT 1"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (wordStr as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (wordStr as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    results.append(parseWord(stmt))
                }
            }
            sqlite3_finalize(stmt)
        }
        return results
    }
    
    func randomHskWords(level: Int? = nil, limit: Int = 30) -> [Word] {
        guard let db = db else { return [] }
        let sql: String
        if let lv = level {
            sql = "SELECT \(wordCols) FROM words WHERE hsk = \(lv) AND short_mean != '' ORDER BY RANDOM() LIMIT \(limit)"
        } else {
            sql = "SELECT \(wordCols) FROM words WHERE hsk IS NOT NULL AND short_mean != '' ORDER BY RANDOM() LIMIT \(limit)"
        }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        var result: [Word] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                result.append(parseWord(stmt))
            }
        }
        return result
    }
    
    // MARK: - Helpers
    
    private func parseWord(_ stmt: OpaquePointer?) -> Word {
        let id = Int(sqlite3_column_int(stmt, 0))
        let simp = sqliteString(stmt, 1)
        let trad = sqliteStringOpt(stmt, 2) ?? ""
        let pinyin = sqliteStringOpt(stmt, 3) ?? ""
        let hanviet = sqliteStringOpt(stmt, 4) ?? ""
        let hsk = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 5)) : nil
        let rank = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 6)) : nil
        let shortMean = sqliteStringOpt(stmt, 7) ?? ""
        
        return Word(id: id, simp: simp, trad: trad, pinyin: pinyin, hanviet: hanviet, hsk: hsk, rank: rank, shortMean: shortMean)
    }
    
    private func parseExample(_ stmt: OpaquePointer?) -> Example {
        let id = Int(sqlite3_column_int(stmt, 0))
        let zh = sqliteString(stmt, 1)
        let pinyin = sqliteStringOpt(stmt, 2) ?? ""
        let mean = sqliteStringOpt(stmt, 3) ?? ""
        return Example(id: id, zh: zh, pinyin: pinyin, mean: mean)
    }
    
    // MARK: - Handwriting Recognition
    
    func recognizeHandwriting(strokes: [[CGPoint]], canvasSize: CGSize, limit: Int = 12) -> [(char: String, pinyin: String, hanviet: String, score: Double)] {
        guard let db = db, !strokes.isEmpty, canvasSize.width > 0 else { return [] }
        let k = strokes.count
        let minK = max(1, k - 1)
        let maxK = k + 1
        
        let scale = 1024.0 / Double(canvasSize.width)
        let userStrokes = strokes.map { stroke in
            stroke.map { Pt(x: Double($0.x) * scale, y: 900.0 - Double($0.y) * scale) }
        }
        
        let nPoints = 12
        func resamplePts(_ pts: [Pt]) -> [Pt] {
            guard pts.count >= 2 else { return Array(repeating: pts.first ?? Pt(x: 0, y: 0), count: nPoints) }
            let total = pathLength(pts)
            guard total > 0 else { return Array(repeating: pts.first!, count: nPoints) }
            let step = total / Double(nPoints - 1)
            var out = [pts[0]]
            var acc = 0.0
            var prev = pts[0]
            var i = 1
            while i < pts.count && out.count < nPoints {
                let cur = pts[i]
                let d = prev.dist(cur)
                if acc + d >= step && d > 0 {
                    let t = (step - acc) / d
                    let q = Pt(x: prev.x + (cur.x - prev.x) * t, y: prev.y + (cur.y - prev.y) * t)
                    out.append(q)
                    prev = q
                    acc = 0.0
                } else {
                    acc += d
                    prev = cur
                    i += 1
                }
            }
            while out.count < nPoints {
                out.append(pts.last!)
            }
            return out
        }
        
        func strokeDist(_ u: [Pt], _ m: [Pt]) -> Double {
            var fwd = 0.0
            for i in 0..<nPoints {
                fwd += u[i].dist(m[i])
            }
            fwd /= Double(nPoints)
            
            var rev = 0.0
            for i in 0..<nPoints {
                rev += u[nPoints - 1 - i].dist(m[i])
            }
            rev = (rev / Double(nPoints)) + 20.0
            return min(fwd, rev)
        }
        
        let uResampled = userStrokes.map(resamplePts)
        
        let sql = "SELECT char, pinyin, hanviet, popular, medians, stroke_count FROM chars WHERE stroke_count BETWEEN ? AND ? AND medians IS NOT NULL"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        var candidates: [(char: String, pinyin: String, hanviet: String, score: Double)] = []
        let popBonus: [String: Double] = [
            "rất cao": 15.0,
            "cao": 10.0,
            "trung bình": 5.0,
            "thấp": 0.0,
            "rất thấp": -10.0
        ]
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(minK))
            sqlite3_bind_int(stmt, 2, Int32(maxK))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let ch = sqliteString(stmt, 0)
                let py = sqliteStringOpt(stmt, 1) ?? ""
                let hv = sqliteStringOpt(stmt, 2) ?? ""
                let pop = sqliteStringOpt(stmt, 3) ?? ""
                let mediansJson = sqliteString(stmt, 4)
                let bonus = popBonus[pop] ?? 0.0
                
                guard let rawMed = try? JSONDecoder().decode([[[Double]]].self, from: Data(mediansJson.utf8)), !rawMed.isEmpty else {
                    continue
                }
                
                let medPts = rawMed.map { s in s.map { p in Pt(x: p[0], y: p[1]) } }
                let medResampled = medPts.map(resamplePts)
                
                var score: Double = 0.0
                if medPts.count == k {
                    var inOrder = 0.0
                    for i in 0..<k {
                        inOrder += strokeDist(uResampled[i], medResampled[i])
                    }
                    inOrder /= Double(k)
                    
                    if k <= 4 {
                        var bestPerm = 0.0
                        for u in uResampled {
                            let minD = medResampled.map { strokeDist(u, $0) }.min() ?? 999.0
                            bestPerm += minD
                        }
                        bestPerm /= Double(k)
                        score = min(inOrder, bestPerm + 20.0) - bonus
                    } else {
                        score = inOrder - bonus
                    }
                } else {
                    var totalDist = 0.0
                    for u in uResampled {
                        let minD = medResampled.map { strokeDist(u, $0) }.min() ?? 999.0
                        totalDist += minD
                    }
                    totalDist /= Double(k)
                    let penalty = 45.0 * Double(abs(medPts.count - k))
                    score = totalDist + penalty - bonus
                }
                
                candidates.append((char: ch, pinyin: py, hanviet: hv, score: score))
            }
        }
        
        candidates.sort { $0.score < $1.score }
        return Array(candidates.prefix(limit))
    }
}
