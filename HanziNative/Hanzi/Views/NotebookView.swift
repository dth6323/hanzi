import SwiftUI

struct NotebookView: View {
    @State private var streakDays: Int = 0
    @State private var srsSummary: (total: Int, due: Int, mastered: Int) = (0, 0, 0)
    @State private var dueCards: [SrsCard] = []
    @State private var favorites: [Word] = []
    @State private var isLoading: Bool = true
    @State private var alertMessage: String? = nil
    @State private var showAlert: Bool = false
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sổ tay & Ôn tập")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Theme.text)
                            Text("Ghi nhớ ngắt quãng SRS theo đường cong quên lãng")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.muted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // SRS Dashboard Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .foregroundColor(Color.orange)
                                    Text("\(streakDays) ngày liên tục")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.orange)
                                }
                                Text("Duy trì chuỗi học mỗi ngày")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted)
                            }
                            Spacer()
                        }
                        
                        Divider().background(Theme.border)
                        
                        // 3 SRS metrics
                        HStack(spacing: 16) {
                            srsMetricBox(
                                title: "Cần ôn hôm nay",
                                count: "\(srsSummary.due)",
                                color: Theme.vermilion
                            )
                            srsMetricBox(
                                title: "Đã nhớ vững",
                                count: "\(srsSummary.mastered)",
                                color: Theme.gold
                            )
                            srsMetricBox(
                                title: "Tổng số thẻ",
                                count: "\(srsSummary.total)",
                                color: Theme.text
                            )
                        }
                        
                        // Action Review Button
                        if srsSummary.total > 0 {
                            NavigationLink(destination: FlashcardView(cards: dueCards.isEmpty ? UserDatabase.shared.allSrsCards(limit: 30) : dueCards, title: dueCards.isEmpty ? "Ôn tập tự do (30 thẻ)" : "Ôn tập hôm nay (\(dueCards.count) thẻ)")) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(dueCards.isEmpty ? "Ôn ngẫu nhiên 30 thẻ" : "Bắt đầu ôn tập (\(dueCards.count) thẻ)")
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(dueCards.isEmpty ? Theme.surfaceLight : Theme.vermilion)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(16)
                    .background(Theme.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 16)
                    
                    // Quick Deck presets
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thêm thẻ từ vựng vào SRS")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.text)
                            .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(1...6, id: \.self) { level in
                                    Button(action: { addHskDeck(level: level) }) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HskBadgeView(level: level)
                                            Text("Thêm HSK \(level)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(Theme.text)
                                            Text("+ 50 từ mới")
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.muted)
                                        }
                                        .frame(width: 120, alignment: .leading)
                                        .padding(12)
                                        .background(Theme.surface)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    
                    // Favorite words list
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Từ đã lưu yêu thích (\(favorites.count))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.text)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        if favorites.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bookmark.slash")
                                    .font(.system(size: 36))
                                    .foregroundColor(Theme.muted.opacity(0.6))
                                Text("Chưa có từ nào trong danh sách yêu thích")
                                    .font(.system(size: 14))
                                    .foregroundColor(Theme.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(favorites) { word in
                                    NavigationLink(destination: WordDetailView(wordId: word.id)) {
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 8) {
                                                    Text(word.simp)
                                                        .font(.system(size: 20, weight: .bold))
                                                        .foregroundColor(Theme.text)
                                                    Text(word.pinyin)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(Theme.vermilion)
                                                    if let h = word.hsk, h > 0 {
                                                        HskBadgeView(level: h)
                                                    }
                                                }
                                                Text(word.shortMean)
                                                    .font(.system(size: 13))
                                                    .foregroundColor(Theme.textSecondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                            
                                            Button(action: { removeFavorite(wordId: word.id) }) {
                                                Image(systemName: "bookmark.fill")
                                                    .foregroundColor(Theme.gold)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        .padding(14)
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
        .alert(alertMessage ?? "", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            refreshData()
        }
    }
    
    private func srsMetricBox(title: String, count: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(count)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.surfaceLight.opacity(0.4))
        .cornerRadius(8)
    }
    
    private func refreshData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let streak = UserDatabase.shared.streakDays()
            let summary = UserDatabase.shared.srsSummary()
            let due = UserDatabase.shared.dueSrsCards()
            let favs = UserDatabase.shared.favorites()
            
            DispatchQueue.main.async {
                self.streakDays = streak
                self.srsSummary = summary
                self.dueCards = due
                self.favorites = favs
                self.isLoading = false
            }
        }
    }
    
    private func addHskDeck(level: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            let words = DictDatabase.shared.wordsForHsk(level: level, limit: 50)
            for w in words {
                let card = SrsCard(
                    id: 0,
                    wordId: w.id,
                    front: w.simp,
                    pinyin: w.pinyin,
                    hanViet: w.hanViet,
                    meaning: w.shortMean,
                    intervalDays: 1,
                    easeFactor: 2.5,
                    reps: 0,
                    lapses: 0,
                    dueDays: 0,
                    lastReviewed: nil
                )
                UserDatabase.shared.saveSrsCard(card: card)
            }
            
            DispatchQueue.main.async {
                self.alertMessage = "Đã thêm 50 từ HSK \(level) vào bộ thẻ SRS thành công!"
                self.showAlert = true
                self.refreshData()
            }
        }
    }
    
    private func removeFavorite(wordId: Int) {
        UserDatabase.shared.removeFavorite(wordId: wordId)
        refreshData()
    }
}
