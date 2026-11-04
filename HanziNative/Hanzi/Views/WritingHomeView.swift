import SwiftUI

struct WritingHomeView: View {
    @State private var query: String = ""
    @State private var searchResults: [Word] = []
    @State private var selectedWords: [Word] = []
    @State private var recentStats: [[String: Any]] = []
    @State private var isSearching: Bool = false
    
    private var selectedChars: [String] {
        var seen = Set<String>()
        var res: [String] = []
        for w in selectedWords {
            for c in TextUtils.cjkChars(in: w.simp) {
                if !seen.contains(c) {
                    seen.insert(c)
                    res.append(c)
                }
            }
        }
        return res
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Luyện viết chữ Hán")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Theme.text)
                            Text("Đồ nét theo thứ tự chuẩn · Chấm điểm tự động")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "pencil.and.outline")
                            .foregroundColor(Theme.muted)
                        TextField("Gõ chữ Hán, Pinyin hoặc nghĩa để luyện...", text: $query)
                            .foregroundColor(Theme.text)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: query) { val in
                                searchWords(val)
                            }
                        if !query.isEmpty {
                            Button(action: {
                                query = ""
                                searchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.muted)
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // Direct quick practice input if query contains CJK
                    if TextUtils.hasCjk(query) {
                        let cjks = TextUtils.cjkChars(in: query)
                        NavigationLink(destination: PracticeView(chars: cjks, title: "Luyện: \(query)")) {
                            HStack {
                                Image(systemName: "hand.draw.fill")
                                    .foregroundColor(Theme.gold)
                                Text("Luyện viết ngay: \(query)")
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.muted)
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Search Results dropdown
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Kết quả tìm kiếm (\(searchResults.count))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Theme.muted)
                                .padding(.horizontal, 16)
                            
                            ForEach(searchResults.prefix(5)) { word in
                                let chars = TextUtils.cjkChars(in: word.simp)
                                NavigationLink(destination: PracticeView(chars: chars, title: "Luyện từ: \(word.simp)")) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 8) {
                                                Text(word.simp)
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(Theme.vermilion)
                                                Text(word.pinyin)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Theme.muted)
                                            }
                                            Text(word.shortMean)
                                                .font(.system(size: 13))
                                                .foregroundColor(Theme.textSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "pencil.line")
                                            .foregroundColor(Theme.vermilion)
                                    }
                                    .padding(12)
                                    .background(Theme.surface)
                                    .cornerRadius(10)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    
                    // Quick Preset Decks
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bộ từ gợi ý luyện viết")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 16)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            PresetWritingButton(
                                title: "Chữ số cơ bản",
                                subtitle: "一, 二, 三, 四, 五...",
                                chars: ["一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
                            )
                            PresetWritingButton(
                                title: "Bộ thủ cơ bản",
                                subtitle: "人, 口, 日, 月, 木...",
                                chars: ["人", "口", "日", "月", "木", "水", "火", "土", "金", "女"]
                            )
                            PresetWritingButton(
                                title: "HSK 1 thông dụng",
                                subtitle: "你, 好, 我, 是, 他...",
                                chars: ["你", "好", "我", "是", "他", "她", "不", "很", "大", "小"]
                            )
                            PresetWritingButton(
                                title: "Phương hướng & Vị trí",
                                subtitle: "上, 下, 左, 右, 前...",
                                chars: ["上", "下", "左", "右", "前", "后", "东", "西", "南", "北"]
                            )
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    // Recent Writing Stats
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Chữ đã luyện gần đây")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.text)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        if recentStats.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "pencil.tip.crop.circle")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.muted.opacity(0.6))
                                Text("Bạn chưa luyện viết chữ nào")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 12) {
                                ForEach(recentStats.indices, id: \.self) { idx in
                                    let item = recentStats[idx]
                                    let char = item["char"] as? String ?? ""
                                    let count = item["count"] as? Int ?? 0
                                    
                                    NavigationLink(destination: PracticeView(chars: [char], title: "Luyện viết: \(char)")) {
                                        VStack(spacing: 2) {
                                            Text(char)
                                                .font(.system(size: 26, weight: .bold))
                                                .foregroundColor(Theme.text)
                                            Text("\(count) lần")
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.gold)
                                        }
                                        .frame(width: 64, height: 64)
                                        .background(Theme.surface)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadStats()
        }
    }
    
    private func searchWords(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            searchResults = []
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let res = DictDatabase.shared.search(query: trimmed, limit: 10)
            DispatchQueue.main.async {
                self.searchResults = res
            }
        }
    }
    
    private func loadStats() {
        DispatchQueue.global(qos: .userInitiated).async {
            let stats = UserDatabase.shared.writingStats()
            DispatchQueue.main.async {
                self.recentStats = stats
            }
        }
    }
}

struct PresetWritingButton: View {
    let title: String
    let subtitle: String
    let chars: [String]
    
    var body: some View {
        NavigationLink(destination: PracticeView(chars: chars, title: title)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Theme.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }
}
