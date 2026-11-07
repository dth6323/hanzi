import SwiftUI

struct HandwritingSearchView: View {
    @Environment(\.presentationMode) var presentationMode
    let onSelect: (String) -> Void
    
    @State private var strokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var candidates: [(char: String, pinyin: String, hanviet: String, score: Double)] = []
    @State private var composedQuery: String = ""
    
    var body: some View {
        VStack(spacing: 12) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            // Header
            HStack {
                Image(systemName: "pencil.and.outline")
                    .foregroundColor(AppColors.gold)
                    .font(.system(size: 18, weight: .bold))
                Text("Nhận dạng chữ viết tay")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.text)
                
                Spacer()
                
                if !composedQuery.isEmpty {
                    Button(action: {
                        onSelect(composedQuery)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                            Text("Tìm: \(composedQuery)")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                } else {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(AppColors.muted)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // Candidate bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if strokes.isEmpty && candidates.isEmpty {
                        Text(composedQuery.isEmpty ? "Vẽ chữ Hán vào khung bên dưới để nhận dạng" : "Đã chọn: \(composedQuery) · Viết tiếp chữ tiếp theo")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.muted)
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(Array(candidates.enumerated()), id: \.offset) { idx, c in
                            Button(action: {
                                if composedQuery.isEmpty {
                                    onSelect(c.char)
                                    presentationMode.wrappedValue.dismiss()
                                } else {
                                    composedQuery.append(c.char)
                                    clearCanvas()
                                }
                            }) {
                                VStack(spacing: 2) {
                                    Text(c.char)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(idx == 0 ? AppColors.gold : AppColors.text)
                                    Text(!c.pinyin.isEmpty ? c.pinyin : c.hanviet)
                                        .font(.system(size: 10))
                                        .foregroundColor(AppColors.muted)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(idx == 0 ? AppColors.primary.opacity(0.25) : AppColors.surface2)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(idx == 0 ? AppColors.gold.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 56)
            .background(AppColors.surface)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            
            // Canvas with Rice Grid (米字格)
            GeometryReader { geo in
                let w = min(geo.size.width - 32, 320)
                let canvasSize = CGSize(width: w, height: w)
                
                VStack {
                    ZStack {
                        // Canvas background paper
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.98, green: 0.97, blue: 0.94))
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, y: 4)
                        
                        // Rice Grid Lines (米字格)
                        Canvas { context, size in
                            let stroke = StrokeStyle(lineWidth: 1.0, dash: [4, 4])
                            let redColor = Color(red: 0.83, green: 0.18, blue: 0.18, opacity: 0.22)
                            
                            // Cross
                            var vLine = Path()
                            vLine.move(to: CGPoint(x: size.width / 2, y: 0))
                            vLine.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                            context.stroke(vLine, with: .color(redColor), style: stroke)
                            
                            var hLine = Path()
                            hLine.move(to: CGPoint(x: 0, y: size.height / 2))
                            hLine.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                            context.stroke(hLine, with: .color(redColor), style: stroke)
                            
                            // Diagonals
                            var d1 = Path()
                            d1.move(to: CGPoint(x: 0, y: 0))
                            d1.addLine(to: CGPoint(x: size.width, y: size.height))
                            context.stroke(d1, with: .color(redColor), style: stroke)
                            
                            var d2 = Path()
                            d2.move(to: CGPoint(x: size.width, y: 0))
                            d2.addLine(to: CGPoint(x: 0, y: size.height))
                            context.stroke(d2, with: .color(redColor), style: stroke)
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        
                        // Drawing ink layer
                        Canvas { context, size in
                            let inkStyle = StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)
                            let inkColor = Color(red: 0.11, green: 0.11, blue: 0.11)
                            
                            for stroke in strokes {
                                guard stroke.count >= 2 else { continue }
                                var path = Path()
                                path.move(to: stroke[0])
                                for pt in stroke.dropFirst() {
                                    path.addLine(to: pt)
                                }
                                context.stroke(path, with: .color(inkColor), style: inkStyle)
                            }
                            
                            if currentStroke.count >= 2 {
                                var path = Path()
                                path.move(to: currentStroke[0])
                                for pt in currentStroke.dropFirst() {
                                    path.addLine(to: pt)
                                }
                                context.stroke(path, with: .color(inkColor), style: inkStyle)
                            }
                        }
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let pt = value.location
                                    if currentStroke.isEmpty {
                                        currentStroke = [pt]
                                    } else {
                                        currentStroke.append(pt)
                                    }
                                }
                                .onEnded { _ in
                                    if currentStroke.count >= 2 {
                                        strokes.append(currentStroke)
                                    }
                                    currentStroke = []
                                    recognize(canvasSize: canvasSize)
                                }
                        )
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Toolbar
                    HStack {
                        Button(action: {
                            if !strokes.isEmpty {
                                strokes.removeLast()
                                recognize(canvasSize: canvasSize)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Hoàn tác")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(strokes.isEmpty ? AppColors.muted.opacity(0.4) : AppColors.gold)
                        }
                        .disabled(strokes.isEmpty)
                        
                        Spacer()
                        
                        Text("Số nét: \(strokes.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.muted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColors.surface2)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Button(action: {
                            clearCanvas()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Xoá bảng")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(strokes.isEmpty ? AppColors.muted.opacity(0.4) : AppColors.primary)
                        }
                        .disabled(strokes.isEmpty)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .frame(height: 360)
        }
        .padding(.vertical, 8)
        .background(AppColors.bg.ignoresSafeArea())
    }
    
    private func clearCanvas() {
        strokes = []
        currentStroke = []
        candidates = []
    }
    
    private func recognize(canvasSize: CGSize) {
        guard !strokes.isEmpty else {
            candidates = []
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let res = DictDatabase.shared.recognizeHandwriting(strokes: strokes, canvasSize: canvasSize, limit: 12)
            DispatchQueue.main.async {
                self.candidates = res
            }
        }
    }
}
