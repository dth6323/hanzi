import SwiftUI

struct HskBadgeView: View {
    let level: Int
    
    var body: some View {
        Text("HSK \(level)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(AppColors.hskColor(level))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(AppColors.hskColor(level).opacity(0.18))
            .cornerRadius(6)
    }
}

struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.primary)
                .frame(width: 4, height: 16)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppColors.text)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct SpeakButtonView: View {
    let text: String
    var slow: Bool = false
    var size: CGFloat = 20
    
    var body: some View {
        Button {
            Speaker.shared.speak(text, slow: slow)
        } label: {
            Image(systemName: slow ? "slowmo" : "speaker.wave.2.fill")
                .font(.system(size: size))
                .foregroundColor(AppColors.gold)
        }
        .buttonStyle(.plain)
    }
}

typealias SpeakButton = SpeakButtonView

struct WordRowView: View {
    let word: Word
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(word.simp)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(AppColors.text)
                .frame(minWidth: 54, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.pinyin)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.gold)
                    
                    if !word.hanviet.isEmpty {
                        Text(word.hanviet.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.muted)
                    }
                    
                    if let hsk = word.hsk {
                        HskBadgeView(level: hsk)
                    }
                    Spacer()
                }
                
                Text(word.shortMean)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.text.opacity(0.9))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppColors.surface)
        .cornerRadius(14)
    }
}
