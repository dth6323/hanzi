import SwiftUI

struct FlashcardView: View {
    let cards: [SrsCard]
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [SrsCard] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var reviewedCount: Int = 0
    @State private var isCompleted: Bool = false
    
    init(cards: [SrsCard], title: String = "Ôn tập Flashcard (SRS)") {
        self.cards = cards
        self.title = title
    }
    
    private var currentCard: SrsCard? {
        guard !queue.isEmpty, currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if isCompleted || queue.isEmpty {
                completedView
            } else if let card = currentCard {
                VStack(spacing: 16) {
                    // Header progress
                    HStack {
                        Text("\(currentIndex + 1) / \(queue.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.muted)
                        
                        Spacer()
                        
                        ProgressView(value: Double(currentIndex), total: Double(queue.count))
                            .progressViewStyle(LinearProgressViewStyle(tint: Theme.vermilion))
                            .frame(width: 120)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    Spacer()
                    
                    // Flippable Flashcard
                    ZStack {
                        if isFlipped {
                            backCardView(card: card)
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        } else {
                            frontCardView(card: card)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 380)
                    .padding(.horizontal, 20)
                    .rotation3DEffect(.degrees(rotationAngle), axis: (x: 0, y: 1, z: 0))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        flipCard()
                    }
                    
                    Spacer()
                    
                    // Bottom Controls
                    if !isFlipped {
                        Button(action: flipCard) {
                            Text("Nhấn để xem đáp án")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Theme.vermilion)
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    } else {
                        // Grading Buttons: Again (0), Hard (1), Good (2), Easy (3)
                        HStack(spacing: 10) {
                            gradeButton(label: "Quên", interval: "10p", color: Theme.vermilion, grade: 0)
                            gradeButton(label: "Khó", interval: intervalLabel(grade: 1), color: Color.orange, grade: 1)
                            gradeButton(label: "Tốt", interval: intervalLabel(grade: 2), color: Color.blue, grade: 2)
                            gradeButton(label: "Dễ", interval: intervalLabel(grade: 3), color: Theme.gold, grade: 3)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            queue = cards
        }
    }
    
    // Front side of card
    private func frontCardView(card: SrsCard) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text(card.front)
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(Theme.text)
            
            SpeakButton(text: card.front, size: 36)
            
            Spacer()
            
            Text("Chạm vào thẻ để lật")
                .font(.system(size: 13))
                .foregroundColor(Theme.muted.opacity(0.8))
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // Back side of card
    private func backCardView(card: SrsCard) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Text(card.front)
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(Theme.vermilion)
            
            if !card.pinyin.isEmpty {
                Text(card.pinyin)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Theme.gold)
            }
            
            if !card.hanViet.isEmpty {
                Text("Hán-Việt: \(card.hanViet)")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.muted)
            }
            
            Divider()
                .background(Theme.border)
                .padding(.horizontal, 24)
            
            Text(card.meaning)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.surface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.gold.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // Rating Button
    private func gradeButton(label: String, interval: String, color: Color, grade: Int) -> some View {
        Button(action: { rate(grade: grade) }) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(interval)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color)
            .cornerRadius(12)
        }
    }
    
    private func flipCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            rotationAngle += 180
            isFlipped.toggle()
        }
    }
    
    private func intervalLabel(grade: Int) -> String {
        guard let card = currentCard else { return "" }
        let preview = card.review(grade: grade)
        if preview.intervalDays <= 1 {
            return "1 ngày"
        } else {
            return "\(preview.intervalDays) ngày"
        }
    }
    
    private func rate(grade: Int) {
        guard let card = currentCard else { return }
        let updated = card.review(grade: grade)
        UserDatabase.shared.saveSrsCard(card: updated)
        reviewedCount += 1
        
        if grade == 0 {
            queue.append(updated)
        }
        
        if currentIndex < queue.count - 1 {
            withAnimation {
                currentIndex += 1
                isFlipped = false
                rotationAngle = 0
            }
        } else {
            withAnimation {
                isCompleted = true
            }
        }
    }
    
    // Finished view
    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(Theme.gold)
            
            Text("Xuất sắc!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.text)
            
            Text("Bạn đã hoàn thành phiên ôn tập \(reviewedCount) lượt thẻ hôm nay.")
                .font(.system(size: 15))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: { dismiss() }) {
                Text("Quay về sổ tay")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 240)
                    .frame(height: 50)
                    .background(Theme.vermilion)
                    .cornerRadius(14)
            }
            .padding(.top, 16)
        }
        .padding()
    }
}
