import SwiftUI

struct PracticeView: View {
    let chars: [String]
    let title: String?
    
    @State private var hanChars: [HanChar] = []
    @State private var currentIndex: Int = 0
    @State private var isLoading: Bool = true
    @State private var mode: WriteMode = .trace
    @State private var feedback: String = ""
    @State private var feedbackColor: Color = Theme.muted
    @State private var score: Int? = nil
    @State private var attemptsMap: [String: Int] = [:]
    
    init(chars: [String], title: String? = nil) {
        self.chars = chars
        self.title = title
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
                    // Multi-character selector if more than 1 char
                    if hanChars.count > 1 {
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
        
        if mistakes == 0 {
            feedback = "Hoàn hảo! 100 điểm (Lần viết thứ \(attempts))"
            feedbackColor = Theme.gold
        } else {
            feedback = "Hoàn thành! Sai \(mistakes) nét · \(sc) điểm"
            feedbackColor = Theme.hint
        }
    }
}
