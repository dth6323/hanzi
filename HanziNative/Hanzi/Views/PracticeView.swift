import SwiftUI

struct PracticeView: View {
    let chars: [String]
    let title: String?
    let example: Example?
    
    @State private var hanChars: [HanChar] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading: Bool = true
    @State private var mode: WriteMode = .trace
    @State private var feedback: String = ""
    @State private var feedbackColor: Color = Theme.muted
    @State private var score: Int? = nil
    @State private var attemptsMap: [String: Int] = [:]
    
    struct SentenceToken: Identifiable {
        let id: Int
        let text: String
        let isCjk: Bool
        let cjkIndex: Int?
    }
    
    init(chars: [String], title: String? = nil, example: Example? = nil) {
        self.chars = chars
        self.title = title
        self.example = example
    }
    
    private var sentenceTokens: [SentenceToken] {
        guard let ex = example else { return [] }
        var tokens: [SentenceToken] = []
        var cjkIdx = 0
        for (i, ch) in Array(ex.zh).enumerated() {
            let s = String(ch)
            if TextUtils.hasCjk(s) {
                tokens.append(SentenceToken(id: i, text: s, isCjk: true, cjkIndex: cjkIdx))
                cjkIdx += 1
            } else {
                tokens.append(SentenceToken(id: i, text: s, isCjk: false, cjkIndex: nil))
            }
        }
        return tokens
    }
    
    private var currentChar: HanChar? {
        guard !hanChars.isEmpty, currentIndex < hanChars.count else { return nil }
        return hanChars[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(Theme.vermilion)
            } else if hanChars.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pencil.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.muted)
                    Text("Không tìm thấy dữ liệu nét viết cho chữ này")
                        .foregroundColor(Theme.muted)
                }
            } else {
                VStack(spacing: 12) {
                    if let ex = example {
                        sentenceBanner(ex)
                    } else if hanChars.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(hanChars.enumerated()), id: \.offset) { idx, hc in
                                    Button(action: { selectChar(idx) }) {
                                        Text(hc.char)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(idx == currentIndex ? .white : Theme.muted)
                                            .frame(width: 44, height: 44)
                                            .background(idx == currentIndex ? Theme.vermilion : Theme.surface)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 50)
                    }
                    
                    // Header info of current char
                    if let cur = currentChar {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(cur.char)
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(Theme.gold)
                                    Text(cur.pinyin)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(Theme.text)
                                    if !cur.hanViet.isEmpty {
                                        Text("(\(cur.hanViet))")
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.muted)
                                    }
                                }
                                Text(cur.meaning)
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.muted)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            SpeakButton(text: cur.char, size: 28)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                    }
                    
                    // Mode selector segmented control
                    Picker("Chế độ", selection: $mode) {
                        Text("Xem mẫu").tag(WriteMode.watch)
                        Text("Đồ nét").tag(WriteMode.trace)
                        Text("Tự viết").tag(WriteMode.recall)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    
                    // Feedback text
                    Text(feedback.isEmpty ? " " : feedback)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(feedbackColor)
                        .frame(height: 20)
                    
                    // Canvas View
                    if let cur = currentChar {
                        HanziCanvasView(
                            charData: cur,
                            mode: mode,
                            onStrokeCompleted: { strokeIdx, result in
                                if result.ok {
                                    feedback = "Đúng nét \(strokeIdx + 1)/\(cur.strokes.count)"
                                    feedbackColor = Theme.hint
                                } else {
                                    feedback = result.reason ?? "Chưa đúng, thử lại"
                                    feedbackColor = Theme.vermilion
                                }
                            },
                            onCharCompleted: { mistakes in
                                handleCharCompleted(cur: cur, mistakes: mistakes)
                            }
                        )
                        .id("\(cur.char)_\(mode)")
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                    
                    // Bottom Navigation Bar
                    HStack {
                        Button(action: { go(-1) }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Chữ trước")
                            }
                            .foregroundColor(currentIndex > 0 ? Theme.text : Theme.muted.opacity(0.4))
                        }
                        .disabled(currentIndex == 0)
                        
                        Spacer()
                        
                        if let s = score {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(Theme.gold)
                                Text("\(s) điểm")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Theme.gold)
                            }
                        } else {
                            Text("\(currentIndex + 1)/\(hanChars.count)")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.muted)
                        }
                        
                        Spacer()
                        
                        Button(action: { go(1) }) {
                            HStack {
                                Text("Chữ sau")
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(currentIndex < hanChars.count - 1 ? Theme.text : Theme.muted.opacity(0.4))
                        }
                        .disabled(currentIndex >= hanChars.count - 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle(title ?? "Luyện viết chữ Hán")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChars()
        }
    }
    
    private func loadChars() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            var loaded: [HanChar] = []
            var stats: [String: Int] = [:]
            
            for c in chars {
                if let hc = DictDatabase.shared.getChar(char: c), hc.canWrite {
                    loaded.append(hc)
                    let st = UserDatabase.shared.charWritingStat(char: c)
                    stats[c] = st.attempts
                }
            }
            
            DispatchQueue.main.async {
                self.hanChars = loaded
                self.attemptsMap = stats
                self.isLoading = false
            }
        }
    }
    
    private func selectChar(_ idx: Int) {
        guard idx >= 0 && idx < hanChars.count else { return }
        currentIndex = idx
        score = nil
        feedback = ""
    }
    
    private func go(_ delta: Int) {
        let n = currentIndex + delta
        if n >= 0 && n < hanChars.count {
            selectChar(n)
        }
    }
    
    private func handleCharCompleted(cur: HanChar, mistakes: Int) {
        let sc = StrokeMatcher.writingScore(mistakes: mistakes, totalStrokes: cur.strokes.count)
        UserDatabase.shared.recordWriting(char: cur.char, mistakes: mistakes, score: sc)
        
        let attempts = (attemptsMap[cur.char] ?? 0) + 1
        attemptsMap[cur.char] = attempts
        self.score = sc
        
        if example != nil {
            if currentIndex < hanChars.count - 1 {
                feedback = mistakes == 0
                    ? "Hoàn hảo chữ \(currentIndex + 1)/\(hanChars.count)! Bấm 'Chữ sau' ➡️"
                    : "Đạt chữ \(cur.char)! Bấm 'Chữ sau' để viết tiếp ➡️"
            } else {
                feedback = "Xuất sắc! Bạn đã viết xong toàn bộ câu ví dụ! 🎉"
            }
            feedbackColor = Theme.gold
        } else if mistakes == 0 {
            feedback = "Hoàn hảo! 100 điểm (Lần viết thứ \(attempts))"
            feedbackColor = Theme.gold
        } else {
            feedback = "Hoàn thành! Sai \(mistakes) nét · \(sc) điểm"
            feedbackColor = Theme.hint
        }
    }
    
    private func sentenceBanner(_ ex: Example) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.gold)
                    Text("CÂU VÍ DỤ")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.gold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.gold.opacity(0.15))
                .cornerRadius(6)
                
                Text("Chữ \(currentIndex + 1)/\(hanChars.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
                
                Spacer()
                
                SpeakButton(text: ex.zh, size: 22)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(sentenceTokens) { token in
                        if token.isCjk, let targetIdx = token.cjkIndex {
                            let isActive = targetIdx == currentIndex
                            let exists = targetIdx < hanChars.count && hanChars[targetIdx].char == token.text
                            Button(action: {
                                if exists { selectChar(targetIdx) }
                            }) {
                                Text(token.text)
                                    .font(.system(size: 20, weight: isActive ? .bold : .medium))
                                    .foregroundColor(isActive ? .white : (targetIdx < currentIndex ? Theme.gold : Theme.text))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(isActive ? Theme.vermilion : (targetIdx < currentIndex ? Theme.gold.opacity(0.15) : Theme.surface))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isActive ? Theme.gold : Color.clear, lineWidth: 1.5)
                                    )
                            }
                        } else {
                            Text(token.text)
                                .font(.system(size: 20))
                                .foregroundColor(Theme.muted)
                        }
                    }
                }
            }
            
            if !ex.pinyin.isEmpty {
                Text(ex.pinyin)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.gold)
            }
            
            if !ex.mean.isEmpty {
                Text(ex.mean)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(14)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.gold.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
