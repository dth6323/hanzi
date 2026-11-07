import SwiftUI

struct WordDetailView: View {
    let wordId: Int
    @State private var word: Word?
    @State private var senses: [Sense] = []
    @State private var relations: [String: [String]] = [:]
    @State private var notes: [Note] = []
    @State private var isFav: Bool = false
    @State private var isLoading = true
    
    private let relLabels = [
        "measure": "Lượng từ dùng với từ này",
        "compound": "Từ ghép thường gặp",
        "syno": "Từ đồng nghĩa",
        "anto": "Từ trái nghĩa"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let w = word {
                    // Header Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .bottom, spacing: 10) {
                            Text(w.simp)
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(AppColors.text)
                            
                            if let trad = w.tradIfDifferent {
                                Text("〔\(trad)〕")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppColors.muted)
                                    .padding(.bottom, 8)
                            }
                            Spacer()
                        }
                        
                        HStack {
                            Text(w.pinyin)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppColors.gold)
                            Spacer()
                            SpeakButtonView(text: w.simp, size: 24)
                            SpeakButtonView(text: w.simp, slow: true, size: 22)
                        }
                        
                        HStack(spacing: 12) {
                            if !w.hanviet.isEmpty {
                                Text("Hán Việt: \(w.hanviet)")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.muted)
                            }
                            if let hsk = w.hsk {
                                HskBadgeView(level: hsk)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x3A1F1A), Color(hex: 0x1D1A18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Characters for Stroke Order Practice
                    let chars = cjkChars(w.simp)
                    if !chars.isEmpty {
                        SectionHeaderView(title: "Chữ Hán · luyện nét viết")
                        HStack(spacing: 12) {
                            ForEach(chars, id: \.self) { c in
                                NavigationLink(destination: CharDetailView(char: c)) {
                                    Text(c)
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(AppColors.ink)
                                        .frame(width: 64, height: 64)
                                        .background(AppColors.paper)
                                        .cornerRadius(14)
                                }
                            }
                        }
                    }
                    
                    // Senses
                    SectionHeaderView(title: "Nghĩa & Ví dụ")
                    ForEach(Array(senses.enumerated()), id: \.element.id) { index, s in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(AppColors.primary))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    if let k = s.kind, !k.isEmpty {
                                        Text(k)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(AppColors.gold)
                                    }
                                    Text(s.gloss)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppColors.text)
                                    if let exp = s.explain, !exp.isEmpty {
                                        Text(exp)
                                            .font(.system(size: 13))
                                            .foregroundColor(AppColors.muted)
                                    }
                                }
                            }
                            
                            // Examples
                            ForEach(s.examples) { ex in
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.zh)
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.text)
                                        if !ex.pinyin.isEmpty {
                                            Text(ex.pinyin)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.gold)
                                        }
                                        if !ex.mean.isEmpty {
                                            Text(ex.mean)
                                                .font(.system(size: 13))
                                                .foregroundColor(AppColors.muted)
                                        }
                                    }
                                    Spacer()
                                    SpeakButtonView(text: ex.zh, size: 18)
                                    NavigationLink(destination: PracticeView(
                                        chars: TextUtils.cjkChars(in: ex.zh),
                                        title: "Luyện viết câu",
                                        example: ex
                                    )) {
                                        Image(systemName: "pencil.and.outline")
                                            .font(.system(size: 18))
                                            .foregroundColor(Theme.gold)
                                    }
                                }
                                .padding(.leading, 32)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(14)
                        .background(AppColors.surface)
                        .cornerRadius(16)
                    }
                    
                    // Relations (Measure words, compounds, etc.)
                    ForEach(["measure", "compound", "syno", "anto"], id: \.self) { kind in
                        if let list = relations[kind], !list.isEmpty {
                            SectionHeaderView(title: relLabels[kind] ?? kind)
                            FlowLayout(spacing: 8) {
                                ForEach(list.prefix(30), id: \.self) { item in
                                    if kind == "measure" {
                                        Text(item)
                                            .font(.system(size: 14))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.surface2)
                                            .cornerRadius(10)
                                    } else {
                                        Text(item)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppColors.text)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(AppColors.surface2)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView()
                        .tint(AppColors.primary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text("Không tìm thấy từ")
                        .foregroundColor(AppColors.muted)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(16)
        }
        .background(AppColors.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let w = word {
                    Button {
                        isFav.toggle()
                        UserDatabase.shared.setFavorite(wordId: w.id, simp: w.simp, pinyin: w.pinyin, mean: w.shortMean, fav: isFav)
                    } label: {
                        Image(systemName: isFav ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isFav ? AppColors.gold : AppColors.muted)
                    }
                }
            }
        }
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let db = DictDatabase.shared
            let udb = UserDatabase.shared
            let w = db.word(id: wordId)
            
            if let w = w {
                let s = db.senses(wordId: w.id)
                let r = db.relations(wordId: w.id)
                let n = db.notes(wordId: w.id)
                let fav = udb.isFavorite(wordId: w.id)
                udb.addHistory(wordId: w.id, simp: w.simp, pinyin: w.pinyin, mean: w.shortMean)
                
                DispatchQueue.main.async {
                    self.word = w
                    self.senses = s
                    self.relations = r
                    self.notes = n
                    self.isFav = fav
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

// FlowLayout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: currentY + lineHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
