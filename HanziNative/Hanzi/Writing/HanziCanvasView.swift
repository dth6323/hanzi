import SwiftUI

enum WriteMode: String, CaseIterable, Identifiable {
    case watch = "Xem"
    case trace = "Tô theo"
    case recall = "Viết nhớ"
    var id: String { rawValue }
}

struct HanziCanvasView: View {
    let char: HanChar
    let mode: WriteMode
    var onComplete: ((Int) -> Void)?
    var onStroke: ((Int, StrokeResult) -> Void)?
    
    init(char: HanChar, mode: WriteMode, onComplete: ((Int) -> Void)? = nil, onStroke: ((Int, StrokeResult) -> Void)? = nil) {
        self.char = char
        self.mode = mode
        self.onComplete = onComplete
        self.onStroke = onStroke
    }
    
    init(charData: HanChar, mode: WriteMode, onStrokeCompleted: ((Int, StrokeResult) -> Void)? = nil, onCharCompleted: ((Int) -> Void)? = nil) {
        self.char = charData
        self.mode = mode
        self.onStroke = onStrokeCompleted
        self.onComplete = onCharCompleted
    }
    
    @State private var doneStrokes = 0
    @State private var mistakes = 0
    @State private var strokeMistakes = 0
    @State private var currentPoints: [CGPoint] = []
    @State private var wrongFlash = false
    @State private var hintStroke: Int? = nil
    
    @State private var isAnimating = false
    @State private var animTimer: Timer? = nil
    
    private var paths: [Path] {
        char.strokes.map { parseSvgPath($0) }
    }
    
    private var medians: [[Pt]] {
        char.medians.map { stroke in
            stroke.map { Pt(x: $0[0], y: $0[1]) }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let scale = size / 1024.0
            
            ZStack {
                // Background Paper
                AppColors.paper
                
                // Mễ tự cách (Grid lines)
                Canvas { ctx, size in
                    var p = Path()
                    // Border
                    p.addRect(CGRect(origin: .zero, size: size))
                    // Cross
                    p.move(to: CGPoint(x: size.width / 2, y: 0))
                    p.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                    p.move(to: CGPoint(x: 0, y: size.height / 2))
                    p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                    // Diagonals
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: size.width, y: size.height))
                    p.move(to: CGPoint(x: size.width, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: size.height))
                    
                    ctx.stroke(p, with: .color(AppColors.grid.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                
                // Completed & Outline Strokes
                Canvas { ctx, size in
                    ctx.scaleBy(x: scale, y: -scale)
                    ctx.translateBy(x: 0, y: -900)
                    
                    for (i, p) in paths.enumerated() {
                        if i < doneStrokes {
                            ctx.fill(p, with: .color(AppColors.ink))
                        } else if mode != .recall || doneStrokes == paths.count {
                            ctx.fill(p, with: .color(AppColors.outline.opacity(0.85)))
                        }
                    }
                    
                    // Hint stroke
                    if let hint = hintStroke, hint < paths.count {
                        ctx.fill(paths[hint], with: .color(AppColors.hint.opacity(0.8)))
                    }
                }
                
                // User active drawing ink
                Canvas { ctx, size in
                    if currentPoints.count >= 2 {
                        var p = Path()
                        p.move(to: currentPoints[0])
                        for pt in currentPoints.dropFirst() {
                            p.addLine(to: pt)
                        }
                        let strokeColor = wrongFlash ? AppColors.error : AppColors.userInk
                        ctx.stroke(p, with: .color(strokeColor), style: StrokeStyle(lineWidth: 12 * scale, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(wrongFlash ? AppColors.error : AppColors.outline, lineWidth: wrongFlash ? 3 : 1)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard mode != .watch, doneStrokes < paths.count else { return }
                        currentPoints.append(value.location)
                    }
                    .onEnded { _ in
                        guard mode != .watch, doneStrokes < paths.count else { return }
                        processUserStroke(scale: scale)
                    }
            )
            .onAppear {
                if mode == .watch {
                    startAnimation()
                }
            }
            .onChange(of: mode) { newMode in
                reset()
                if newMode == .watch {
                    startAnimation()
                }
            }
            .onChange(of: char) { _ in
                reset()
                if mode == .watch {
                    startAnimation()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    func reset() {
        animTimer?.invalidate()
        animTimer = nil
        isAnimating = false
        doneStrokes = 0
        mistakes = 0
        strokeMistakes = 0
        currentPoints.removeAll()
        hintStroke = nil
        wrongFlash = false
    }
    
    func replayAnimation() {
        reset()
        startAnimation()
    }
    
    private func startAnimation() {
        guard !paths.isEmpty else { return }
        isAnimating = true
        var current = 0
        doneStrokes = 0
        
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.65, repeats: true) { timer in
            if current < paths.count {
                withAnimation(.easeOut(duration: 0.3)) {
                    doneStrokes = current + 1
                }
                current += 1
            } else {
                timer.invalidate()
                isAnimating = false
            }
        }
    }
    
    private func processUserStroke(scale: Double) {
        guard currentPoints.count >= 2, doneStrokes < medians.count else {
            currentPoints.removeAll()
            return
        }
        
        // Convert screen coordinates to 1024x1024 Hanzi coordinates
        let pts: [Pt] = currentPoints.map { pt in
            Pt(x: Double(pt.x) / scale, y: 900.0 - Double(pt.y) / scale)
        }
        
        let targetMedian = medians[doneStrokes]
        let result = matchStroke(user: pts, median: targetMedian)
        
        onStroke?(doneStrokes, result)
        
        if result.ok {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                doneStrokes += 1
                strokeMistakes = 0
                hintStroke = nil
                currentPoints.removeAll()
            }
            if doneStrokes == paths.count {
                onComplete?(mistakes)
            }
        } else {
            mistakes += 1
            strokeMistakes += 1
            wrongFlash = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                wrongFlash = false
                currentPoints.removeAll()
                if strokeMistakes >= 3 {
                    withAnimation {
                        hintStroke = doneStrokes
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation {
                            hintStroke = nil
                        }
                    }
                }
            }
        }
    }
}
