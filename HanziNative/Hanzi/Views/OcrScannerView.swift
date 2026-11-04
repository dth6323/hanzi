import SwiftUI
import PhotosUI

struct OcrScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var recognizedText: String = ""
    @State private var segmentedWords: [Word] = []
    @State private var cjkCharacters: [String] = []
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header & Pickers
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Chọn từ thư viện")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Theme.vermilion)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    // Selected Image Preview
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 56))
                                .foregroundColor(Theme.muted.opacity(0.6))
                            Text("Chụp hoặc chọn ảnh có chữ Hán để quét OCR")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Theme.surface)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    if isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(Theme.vermilion)
                            Text("Đang nhận diện chữ Hán bằng Apple Vision AI...")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.muted)
                        }
                        .padding()
                    }
                    
                    // Recognized Text Box
                    if !recognizedText.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Nội dung nhận diện:")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.gold)
                                Spacer()
                                SpeakButton(text: recognizedText, size: 28)
                            }
                            
                            Text(recognizedText)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Theme.text)
                                .textSelection(.enabled)
                        }
                        .padding(16)
                        .background(Theme.surface)
                        .cornerRadius(14)
                        .padding(.horizontal, 16)
                    }
                    
                    // Recognized Words List
                    if !segmentedWords.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Từ vựng phát hiện trong ảnh (\(segmentedWords.count))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, 16)
                            
                            ForEach(segmentedWords) { word in
                                WordRowView(word: word)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // CJK Characters Grid
                    if !cjkCharacters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Từng chữ đơn lẻ (\(cjkCharacters.count))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, 16)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54))], spacing: 10) {
                                ForEach(cjkCharacters, id: \.self) { c in
                                    NavigationLink(destination: CharDetailView(char: c)) {
                                        Text(c)
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(Theme.text)
                                            .frame(width: 54, height: 54)
                                            .background(Theme.surface)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
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
        .navigationTitle("Quét chữ Hán (OCR)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = uiImage
                        self.runOcr(uiImage)
                    }
                }
            }
        }
    }
    
    private func runOcr(_ image: UIImage) {
        isProcessing = true
        errorMessage = nil
        
        OcrService.shared.recognizeChinese(image: image) { text in
            DispatchQueue.main.async {
                self.isProcessing = false
                guard let text = text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self.errorMessage = "Không tìm thấy văn bản tiếng Trung rõ ràng trong ảnh"
                    return
                }
                
                self.recognizedText = text
                self.cjkCharacters = TextUtils.cjkChars(in: text)
                
                DispatchQueue.global(qos: .userInitiated).async {
                    let words = DictDatabase.shared.segmentChineseText(text: text)
                    DispatchQueue.main.async {
                        self.segmentedWords = words
                    }
                }
            }
        }
    }
}
