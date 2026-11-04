import SwiftUI

enum QuizType: CaseIterable {
    case meaning
    case pinyin
    case listening
    
    var title: String {
        switch self {
        case .meaning: return "Chọn nghĩa đúng"
        case .pinyin: return "Chọn Pinyin đúng"
        case .listening: return "Nghe âm đoán chữ"
        }
    }
}

struct QuizQuestion {
    let promptTitle: String
    let promptMain: String
    let promptSub: String?
    let audioZh: String?
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

struct QuizView: View {
    let type: QuizType
    let hskLevel: Int?
    
    @Environment(\.dismiss) private var dismiss
    @State private var questions: [QuizQuestion] = []
    @State private var currentIndex: Int = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var score: Int = 0
    @State private var isLoading: Bool = true
    @State private var isFinished: Bool = false
    
    private var currentQuestion: QuizQuestion? {
        guard !questions.isEmpty, currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            if isLoading {
                ProgressView("Đang chuẩn bị đề thi...")
                    .tint(Theme.vermilion)
            } else if isFinished {
                resultView
            } else if let q = currentQuestion {
                VStack(spacing: 20) {
                    // Progress & Score
                    HStack {
                        Text("Câu \(currentIndex + 1) / \(questions.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.muted)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(Theme.gold)
                            Text("\(score)")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.gold)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    ProgressView(value: Double(currentIndex), total: Double(questions.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: Theme.vermilion))
                        .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Question Prompt
                    VStack(spacing: 12) {
                        Text(q.promptTitle)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.muted)
                        
                        if type == .listening {
                            SpeakButton(text: q.audioZh ?? q.promptMain, size: 54)
                                .padding(.vertical, 8)
                            Text("Chạm vào loa để nghe lại")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.muted)
                        } else {
                            Text(q.promptMain)
                                .font(.system(size: 52, weight: .bold))
                                .foregroundColor(Theme.text)
                            
                            if let sub = q.promptSub {
                                Text(sub)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.gold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Theme.surface)
                    .cornerRadius(16)
                    .padding(.horizontal, 20)
                    
                    // 4 Options
                    VStack(spacing: 12) {
                        ForEach(0..<q.options.count, id: \.self) { optIdx in
                            optionButton(text: q.options[optIdx], index: optIdx, question: q)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Next Button (visible after user answered)
                    if selectedOptionIndex != nil {
                        Button(action: nextQuestion) {
                            Text(currentIndex < questions.count - 1 ? "Câu tiếp theo" : "Xem kết quả")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Theme.vermilion)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            buildQuiz()
        }
    }
    
    private func optionButton(text: String, index: Int, question: QuizQuestion) -> some View {
        let isSelected = selectedOptionIndex == index
        let isCorrect = question.correctIndex == index
        let hasAnswered = selectedOptionIndex != nil
        
        var bgColor = Theme.surface
        var borderColor = Theme.border
        var textColor = Theme.text
        
        if hasAnswered {
            if isCorrect {
                bgColor = Color.green.opacity(0.2)
                borderColor = Color.green
                textColor = Color.green
            } else if isSelected {
                bgColor = Color.red.opacity(0.2)
                borderColor = Color.red
                textColor = Color.red
            }
        }
        
        return Button(action: {
            guard selectedOptionIndex == nil else { return }
            selectAnswer(index: index, question: question)
        }) {
            HStack {
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
                Spacer()
                if hasAnswered && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if hasAnswered && isSelected && !isCorrect {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(bgColor)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1.5))
        }
        .disabled(hasAnswered)
    }
    
    private func selectAnswer(index: Int, question: QuizQuestion) {
        selectedOptionIndex = index
        if index == question.correctIndex {
            score += 10
        }
    }
    
    private func nextQuestion() {
        if currentIndex < questions.count - 1 {
            currentIndex += 1
            selectedOptionIndex = nil
            if type == .listening, let q = currentQuestion, let audio = q.audioZh {
                Speaker.shared.speak(audio)
            }
        } else {
            isFinished = true
        }
    }
    
    private func buildQuiz() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let pool = DictDatabase.shared.randomHskWords(level: self.hskLevel, limit: 30)
            guard pool.count >= 4 else {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            var generated: [QuizQuestion] = []
            let questionPool = Array(pool.shuffled().prefix(10))
            
            for item in questionPool {
                let distractors = pool.filter { $0.id != item.id }.shuffled()
                guard distractors.count >= 3 else { continue }
                
                switch self.type {
                case .meaning:
                    let correct = item.shortMean
                    let wrong = distractors.prefix(3).map { $0.shortMean }
                    let opts = (wrong + [correct]).shuffled()
                    if let correctIdx = opts.firstIndex(of: correct) {
                        generated.append(QuizQuestion(
                            promptTitle: "Chọn nghĩa tiếng Việt chính xác:",
                            promptMain: item.simp,
                            promptSub: item.pinyin,
                            audioZh: item.simp,
                            options: opts,
                            correctIndex: correctIdx,
                            explanation: "\(item.simp) (\(item.pinyin)): \(item.shortMean)"
                        ))
                    }
                    
                case .pinyin:
                    let correct = item.pinyin
                    let wrong = distractors.prefix(3).map { $0.pinyin }
                    let opts = (wrong + [correct]).shuffled()
                    if let correctIdx = opts.firstIndex(of: correct) {
                        generated.append(QuizQuestion(
                            promptTitle: "Chọn phiên âm Pinyin đúng:",
                            promptMain: item.simp,
                            promptSub: item.shortMean,
                            audioZh: item.simp,
                            options: opts,
                            correctIndex: correctIdx,
                            explanation: "\(item.simp) đọc là \(item.pinyin)"
                        ))
                    }
                    
                case .listening:
                    let correct = item.simp
                    let wrong = distractors.prefix(3).map { $0.simp }
                    let opts = (wrong + [correct]).shuffled()
                    if let correctIdx = opts.firstIndex(of: correct) {
                        generated.append(QuizQuestion(
                            promptTitle: "Nghe phát âm và chọn chữ Hán đúng:",
                            promptMain: item.simp,
                            promptSub: nil,
                            audioZh: item.simp,
                            options: opts,
                            correctIndex: correctIdx,
                            explanation: "\(item.simp) (\(item.pinyin)): \(item.shortMean)"
                        ))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.questions = generated
                self.isLoading = false
                if self.type == .listening, let first = generated.first, let audio = first.audioZh {
                    Speaker.shared.speak(audio)
                }
            }
        }
    }
    
    private var resultView: some View {
        VStack(spacing: 20) {
            Image(systemName: score >= 70 ? "crown.fill" : "rosette")
                .font(.system(size: 64))
                .foregroundColor(score >= 70 ? Theme.gold : Theme.vermilion)
            
            Text("Kết quả bài kiểm tra")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(Theme.text)
            
            Text("Bạn đạt được \(score) / \(questions.count * 10) điểm")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Theme.gold)
            
            Button(action: {
                currentIndex = 0
                selectedOptionIndex = nil
                score = 0
                isFinished = false
                buildQuiz()
            }) {
                Text("Làm lại bài kiểm tra")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 240)
                    .frame(height: 50)
                    .background(Theme.vermilion)
                    .cornerRadius(12)
            }
            .padding(.top, 16)
            
            Button(action: { dismiss() }) {
                Text("Quay lại")
                    .foregroundColor(Theme.muted)
            }
        }
        .padding()
    }
}
