# Hanzi iOS Native (Swift & SwiftUI)

Ứng dụng Tra từ điển, Luyện viết chữ Hán, Học HSK, Flashcard SRS và Quét ảnh OCR viết hoàn toàn bằng **100% Native Swift & SwiftUI** cho nền tảng iOS.

---

## 🌟 Ưu điểm so với Cross-Platform (Flutter / React Native)

1. **Edge-Swipe Back Gesture mượt mà tuyệt đối 120Hz (ProMotion)**:
   - Sử dụng `NavigationStack` gốc của iOS với UINavigationController rendering native.
   - **Xoá bỏ triệt để hiện tượng lag hoặc nhấp nháy màn hình trắng** khi vuốt mép màn hình từ cạnh trái để quay lại.
   - Tối ưu bộ nhớ với lazy view lifecycle, không bị re-layout hay reload bàn phím khi pop view.
2. **Luyện viết chữ Hán (Hanzi Handwriting Canvas) không xung đột cuộn**:
   - Canvas viết nét chữ Hán xử lý `DragGesture(minimumDistance: 0)` riêng biệt, không bị chiếm cử chỉ bởi ScrollView khi kéo nét sổ thẳng từ trên xuống dưới.
   - Hỗ trợ 3 chế độ: **Xem mẫu (Watch)**, **Đồ nét (Trace)**, **Tự viết nhớ nét (Recall)**.
   - Chấm điểm độ chuẩn xác của nét viết tự động dựa trên vector khoảng cách, hướng nét và điểm mốc (medians).
3. **Phát âm Native AVFoundation**:
   - Sử dụng `AVSpeechSynthesizer` với giọng chuẩn tiếng Quan thoại (`zh-CN`), không giật lag mạng.
   - Hỗ trợ cả tốc độ đọc chuẩn và tốc độ chậm (`slowmo`).
4. **Nhận diện chữ Hán qua ảnh (OCR) bằng Apple Vision**:
   - Tích hợp trực tiếp `VNRecognizeTextRequest` từ framework `Vision` của Apple.
   - Nhận diện chữ Hán giản thể (`zh-Hans`) và phồn thể (`zh-Hant`) offline ngay trên chip Neural Engine của iPhone.
5. **Cơ sở dữ liệu SQLite cực nhanh**:
   - Kết nối trực tiếp C SQLite3 (`libsqlite3.tbd`) với `SQLITE_OPEN_READONLY` cho từ điển 165MB (`vi_full.db`).
   - SQLite riêng cho người dùng (`user.sqlite3`) lưu chuỗi ngày học (streak), từ yêu thích (favorites), lịch sử tra cứu và bộ nhớ ngắt quãng SM-2 (SRS flashcards).
6. **Không phụ thuộc thư viện thứ 3 (Zero CocoaPods / SPM)**:
   - Toàn bộ codebase dựa trên Swift Standard Library và Apple SDKs: `SwiftUI`, `SQLite3`, `AVFoundation`, `Vision`, `Speech`, `PhotosUI`.

---

## 📁 Cấu trúc Codebase

```
HanziNative/
├── Hanzi.xcodeproj/           # Xcode Project file & Scheme
├── Hanzi/
│   ├── HanziApp.swift         # @main entry point cấu hình Dark Theme & NavigationBar
│   ├── Theme.swift            # Bảng màu Dark Obsidian, Vermilion (#E5483B), Gold (#E8B86B), HSK
│   ├── Info.plist             # Cấu hình Bundle ID, Quyền Camera, Photos, Speech
│   ├── Assets.xcassets/       # AppIcon & AccentColor
│   ├── Models/
│   │   └── Models.swift       # Word, Sense, Example, HanChar, Topic, Grammar, SrsCard
│   ├── Database/
│   │   ├── DictDatabase.swift # C SQLite3 wrapper đọc vi_full.db (Search, Word, Char, HSK, Topic)
│   │   ├── UserDatabase.swift # SQLite3 ghi user.sqlite3 (Streak, Favorites, SRS, Stats)
│   │   └── TextUtils.swift    # Xử lý CJK unicode scalars, bóc tách ký tự Hán
│   ├── Services/
│   │   ├── Speaker.swift      # AVSpeechSynthesizer phát âm tiếng Trung
│   │   └── OcrService.swift   # Apple Vision AI nhận diện chữ Hán từ ảnh
│   ├── Writing/
│   │   ├── StrokeMatcher.swift # Thuật toán so khớp nét viết và phân tích SVG path
│   │   └── HanziCanvasView.swift # SwiftUI Canvas vẽ nét, lưới mễ Mễ tự (米), kéo nét sổ
│   └── Views/
│       ├── MainTabView.swift      # TabView gốc (Tra cứu, Luyện viết, Học tập, Sổ tay)
│       ├── Components.swift       # WordRowView, HskBadgeView, SpeakButton, SectionHeader
│       ├── SearchScreenView.swift # Màn hình tra cứu từ điển, debounce search, lịch sử tra
│       ├── WordDetailView.swift   # Chi tiết từ vựng, âm Hán Việt, các nét, giải nghĩa, ví dụ
│       ├── CharDetailView.swift   # Chi tiết chữ Hán, bộ thủ, số nét, nút luyện viết
│       ├── PracticeView.swift     # Luyện viết chữ Hán đa chế độ, chấm điểm, đếm lần viết
│       ├── WritingHomeView.swift  # Trang chủ luyện viết, bộ từ gợi ý, thống kê chữ đã luyện
│       ├── LearnHomeView.swift    # Tabs: HSK 1-6, Chủ đề, Ngữ pháp, Kiểm tra
│       ├── FlashcardView.swift    # Lật thẻ Flashcard 3D với thuật toán SM-2 SRS
│       ├── NotebookView.swift     # Bảng theo dõi chuỗi ngày học, thẻ cần ôn, từ yêu thích
│       ├── QuizView.swift         # Trắc nghiệm 4 đáp án: Nghĩa, Pinyin, Nghe đoán chữ
│       └── OcrScannerView.swift   # Quét chữ Hán từ ảnh thư viện hoặc camera
```

---

## 🚀 Cách mở và chạy dự án

1. Mở dự án trong Xcode:
   ```bash
   open HanziNative/Hanzi.xcodeproj
   ```
2. Đảm bảo file `vi_full.db` (165MB) được copy vào thư mục `HanziNative/Hanzi/Resources/vi_full.db` hoặc bundle vào app.
3. Chọn thiết bị đích (iPhone bất kỳ chạy iOS 16.0 trở lên, hoặc iOS Simulator).
4. Nhấn **Cmd + R** để build và chạy ngay!
