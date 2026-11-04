import SwiftUI

struct CharDetailView: View {
    let char: String
    @State private var hanChar: HanChar?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let c = hanChar {
                    // Stroke canvas / character display
                    VStack(spacing: 12) {
                        if c.canWrite {
                            HanziCanvasView(char: c, mode: .watch)
                                .frame(maxWidth: 280)
                                .shadow(color: Color.black.opacity(0.3), radius: 8, y: 4)
                            
                            NavigationLink(destination: PracticeView(chars: [c.char], title: "Luyện viết chữ \(c.char)")) {
                                Label("Luyện viết chữ này", systemImage: "pencil.tip")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(AppColors.primary)
                                    .cornerRadius(12)
                            }
                        } else {
                            Text(c.char)
                                .font(.system(size: 110, weight: .bold))
                                .foregroundColor(AppColors.text)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    
                    // Info card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(c.pinyin)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppColors.gold)
                            Spacer()
                            SpeakButtonView(text: c.char, size: 24)
                        }
                        
                        Text(c.hanviet.uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.muted)
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        infoRow(label: "Bộ thủ", value: "\(c.radical) (\(c.radPinyin)) · \(c.radMeaning)")
                        infoRow(label: "Số nét", value: "\(c.strokeCount) nét")
                        if c.pinyins.count > 1 {
                            infoRow(label: "Các âm đọc", value: c.pinyins.joined(separator: " · "))
                        }
                        if c.hanviets.count > 1 {
                            infoRow(label: "Các âm HV", value: c.hanviets.joined(separator: " · "))
                        }
                        infoRow(label: "Nghĩa cơ bản", value: c.shortMean)
                    }
                    .padding(16)
                    .background(AppColors.surface)
                    .cornerRadius(18)
                    
                    // Components
                    if !c.compDetail.isEmpty {
                        SectionHeaderView(title: "Cấu tạo chữ (bộ phận)")
                        FlowLayout(spacing: 10) {
                            ForEach(c.compDetail, id: \.self) { comp in
                                NavigationLink(destination: CharDetailView(char: comp)) {
                                    Text(comp)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(AppColors.text)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(AppColors.surface2)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                } else if isLoading {
                    ProgressView().tint(AppColors.primary).frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text("Chưa có dữ liệu cho chữ \(char)")
                        .foregroundColor(AppColors.muted)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding(16)
        }
        .background(AppColors.bg.ignoresSafeArea())
        .navigationTitle("Chữ \(char)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadChar()
        }
    }
    
    private func loadChar() {
        DispatchQueue.global(qos: .userInitiated).async {
            let res = DictDatabase.shared.char(char)
            DispatchQueue.main.async {
                self.hanChar = res
                self.isLoading = false
            }
        }
    }
    
    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(AppColors.muted)
                .frame(width: 95, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.text)
            Spacer()
        }
    }
}
