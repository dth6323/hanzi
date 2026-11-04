import SwiftUI

struct LearnHomeView: View {
    @State private var selectedTab: Int = 0
    @State private var topics: [Topic] = []
    @State private var grammarPoints: [Grammar] = []
    @State private var isLoading: Bool = true
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Học & Kiểm tra")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.text)
                        Text("Lộ trình HSK · Chủ đề đời sống · Ngữ pháp")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.muted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
                
                // Custom Tab Bar
                HStack(spacing: 0) {
                    tabHeaderButton(title: "HSK", index: 0)
                    tabHeaderButton(title: "Chủ đề", index: 1)
                    tabHeaderButton(title: "Ngữ pháp", index: 2)
                    tabHeaderButton(title: "Kiểm tra", index: 3)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // Tab Views
                TabView(selection: $selectedTab) {
                    hskTabView.tag(0)
                    topicTabView.tag(1)
                    grammarTabView.tag(2)
                    quizLauncherView.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            loadData()
        }
    }
    
    private func tabHeaderButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? Theme.vermilion : Theme.muted)
                
                Rectangle()
                    .fill(selectedTab == index ? Theme.vermilion : Color.clear)
                    .frame(height: 2.5)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // Tab 1: HSK
    private var hskTabView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(1...6, id: \.self) { level in
                    NavigationLink(destination: WordListView(title: "Từ vựng HSK \(level)", fetchWords: {
                        DictDatabase.shared.wordsForHsk(level: level, limit: 100)
                    })) {
                        HStack(spacing: 16) {
                            HskBadgeView(level: level)
                                .scaleEffect(1.2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cấp độ HSK \(level)")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Theme.text)
                                Text("Khám phá từ vựng và bài tập trọng điểm")
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.muted)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(Theme.muted)
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .cornerRadius(14)
                    }
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    // Tab 2: Chủ đề
    private var topicTabView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(topics) { topic in
                    NavigationLink(destination: WordListView(title: topic.name, fetchWords: {
                        DictDatabase.shared.wordsForTopic(topicId: topic.id, limit: 100)
                    })) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(Theme.gold)
                                Spacer()
                                Text("\(topic.wordCount) từ")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted)
                            }
                            
                            Text(topic.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.text)
                            
                            if !topic.desc.isEmpty {
                                Text(topic.desc)
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.muted)
                                    .lineLimit(2)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
                        .background(Theme.surface)
                        .cornerRadius(14)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    // Tab 3: Ngữ pháp
    private var grammarTabView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(grammarPoints) { g in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(g.title)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.vermilion)
                            Spacer()
                            if let h = g.hsk, h > 0 {
                                HskBadgeView(level: h)
                            }
                        }
                        
                        if !g.pattern.isEmpty {
                            Text(g.pattern)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Theme.gold)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Theme.surfaceLight)
                                .cornerRadius(6)
                        }
                        
                        Text(g.explanation)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(14)
                    .background(Theme.surface)
                    .cornerRadius(14)
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    // Tab 4: Kiểm tra (Quiz Launcher)
    private var quizLauncherView: some View {
        ScrollView {
            VStack(spacing: 16) {
                quizCard(
                    title: "Chọn nghĩa đúng",
                    subtitle: "Hiển thị chữ Hán & Pinyin, chọn nghĩa tiếng Việt",
                    icon: "text.book.closed.fill",
                    color: Theme.vermilion,
                    type: .meaning
                )
                
                quizCard(
                    title: "Chọn Pinyin đúng",
                    subtitle: "Hiển thị chữ Hán & nghĩa, chọn phiên âm chính xác",
                    icon: "character.phonetic",
                    color: Theme.gold,
                    type: .pinyin
                )
                
                quizCard(
                    title: "Nghe âm đoán chữ",
                    subtitle: "Phát âm giọng đọc chuẩn, chọn chữ Hán khớp âm",
                    icon: "speaker.wave.3.fill",
                    color: Color.blue,
                    type: .listening
                )
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }
    
    private func quizCard(title: String, subtitle: String, icon: String, color: Color, type: QuizType) -> some View {
        NavigationLink(destination: QuizView(type: type, hskLevel: nil)) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.15))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(Theme.muted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.muted)
            }
            .padding(16)
            .background(Theme.surface)
            .cornerRadius(16)
        }
    }
    
    private func loadData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let t = DictDatabase.shared.allTopics()
            let g = DictDatabase.shared.allGrammar()
            DispatchQueue.main.async {
                self.topics = t
                self.grammarPoints = g
                self.isLoading = false
            }
        }
    }
}

struct WordListView: View {
    let title: String
    let fetchWords: () -> [Word]
    
    @State private var words: [Word] = []
    @State private var isLoading: Bool = true
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView()
                    .tint(Theme.vermilion)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        // Quick actions bar
                        if !words.isEmpty {
                            HStack(spacing: 12) {
                                let cjks = words.flatMap { TextUtils.cjkChars(in: $0.simp) }
                                NavigationLink(destination: PracticeView(chars: cjks, title: "Luyện viết: \(title)")) {
                                    HStack {
                                        Image(systemName: "pencil")
                                        Text("Luyện viết tất cả")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(Theme.vermilion)
                                    .cornerRadius(8)
                                }
                                
                                let srsCards = words.map { w in
                                    SrsCard(
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
                                }
                                NavigationLink(destination: FlashcardView(cards: srsCards, title: "Flashcard: \(title)")) {
                                    HStack {
                                        Image(systemName: "rectangle.on.rectangle")
                                        Text("Flashcard")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(Theme.gold)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 14)
                                    .background(Theme.surface)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        
                        ForEach(words) { word in
                            WordRowView(word: word)
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let w = fetchWords()
                DispatchQueue.main.async {
                    self.words = w
                    self.isLoading = false
                }
            }
        }
    }
}
