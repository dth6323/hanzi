import SwiftUI

struct SearchScreenView: View {
    @State private var query: String = ""
    @State private var searchResults: [Word] = []
    @State private var history: [Word] = []
    @State private var showOcr = false
    @State private var searchWorkItem: DispatchWorkItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
                HStack(spacing: 10) {
                    Text("汉")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(AppColors.primary)
                    Text("Từ điển Trung – Việt")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.text)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Search Bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.muted)
                    
                    TextField("Chữ Hán, pinyin, Hán Việt hoặc nghĩa…", text: $query)
                        .foregroundColor(AppColors.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: query) { newValue in
                            onSearchChanged(newValue)
                        }
                    
                    if !query.isEmpty {
                        Button {
                            query = ""
                            searchResults.removeAll()
                            loadHistory()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.muted)
                        }
                    }
                    
                    Button {
                        showOcr = true
                    } label: {
                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.gold)
                    }
                }
                .padding(12)
                .background(AppColors.surface2)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                
                // Results or History
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                            if searchResults.isEmpty {
                                Text("Không tìm thấy kết quả")
                                    .foregroundColor(AppColors.muted)
                                    .padding(.top, 40)
                            } else {
                                ForEach(searchResults) { word in
                                    NavigationLink(destination: WordDetailView(wordId: word.id)) {
                                        WordRowView(word: word)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            if history.isEmpty {
                                VStack(spacing: 12) {
                                    Text("Thử gõ: 你好 · nihao · hảo · xin chào")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.muted)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            } else {
                                HStack {
                                    SectionHeaderView(title: "Tra gần đây")
                                    Button("Xoá") {
                                        UserDatabase.shared.clearHistory()
                                        history.removeAll()
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppColors.primary)
                                }
                                .padding(.horizontal, 4)
                                
                                ForEach(history) { word in
                                    NavigationLink(destination: WordDetailView(wordId: word.id)) {
                                        WordRowView(word: word)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .background(AppColors.bg.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showOcr) {
                OcrScannerView()
            }
            .onAppear {
                loadHistory()
            }
    }
    
    private func loadHistory() {
        history = UserDatabase.shared.history()
    }
    
    private func onSearchChanged(_ text: String) {
        searchWorkItem?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            searchResults.removeAll()
            loadHistory()
            return
        }
        
        let item = DispatchWorkItem {
            let res = DictDatabase.shared.search(trimmed, limit: 50)
            DispatchQueue.main.async {
                self.searchResults = res
            }
        }
        searchWorkItem = item
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.2, execute: item)
    }
}
