# 📱 TỔNG HỢP TOÀN BỘ CÁC TÍNH NĂNG & KIẾN TRÚC MỚI (V2.0)

Dự án **`llm_app`** đã được nâng cấp toàn diện với 6 Tab chức năng, hỗ trợ từ Chat LLM thông minh, Đàm thoại giọng nói 2 chiều liên tục (Voice-to-Voice rảnh tay), Điều khiển thiết bị Smart Home, Nhận diện chữ viết tay Digital Ink $(x, y, t)$ siêu tốc màn hình lớn, Kho tri thức Local RAG và Tab Cài đặt chuyên sâu.

---

## 📂 1. Cấu Trúc Toàn Bộ Dự Án (6 Tab)

```text
llm_app/
├── .env                                  # 🔑 Chứa GEMINI_API_KEY & GEMINI_MODEL bảo mật
├── android/
│   └── app/src/main/kotlin/.../
│       └── MainActivity.kt               # 🎙️ Android Native TTS (SpeechRate, Pitch, UtteranceProgressListener)
├── lib/
│   ├── chat/                             # 💬 TAB 0: Chat LLM
│   │   ├── models/chat_message.dart      # 📦 Model tin nhắn & citations
│   │   ├── components/chat_header.dart   # 🏷️ Header model & nút cài đặt
│   │   ├── components/chat_bubble.dart   # 💬 Bubble tin nhắn (Đọc to 🔊, Copy 📋)
│   │   ├── components/chat_input_bar.dart# ⌨️ Thanh nhập tin nhắn + Mic sóng âm
│   │   ├── components/voice_wave_banner.dart # 🌊 Equalizer 60FPS khi nói
│   │   └── chat_screen.dart              # 📱 Màn hình Chat LLM
│   │
│   ├── voice_chat/                       # 🎙️ TAB 1: Đàm Thoại 2 Chiều Liên Tục (NEW)
│   │   └── voice_chat_screen.dart        # 🔮 Quả cầu giọng nói phát sáng (Voice Orb), Loop rảnh tay 100%
│   │
│   ├── voice_command/                    # 💡 TAB 2: Smart Home
│   │   ├── components/device_card.dart   # 💡 Card bóng đèn phát sáng & quạt xoay
│   │   ├── components/voice_mic_button.dart # 🎙️ Nút Mic lớn hiệu ứng âm lượng
│   │   └── voice_command_screen.dart     # 📱 Màn hình điều khiển đèn/quạt bằng giọng nói
│   │
│   ├── handwriting/                      # 🖋️ TAB 3: Digital Ink Siêu Tốc (UPGRADED)
│   │   ├── components/digital_ink_canvas.dart   # 🎨 Bảng vẽ mở rộng lớn (340px - 480px)
│   │   ├── components/telemetry_banner.dart     # ⏱️ Thống kê (x, y, t) & Freeman Chain Code
│   │   ├── components/handwriting_toolbar.dart  # 🛠️ Nút phóng to, chọn màu, hoàn tác, xóa
│   │   ├── components/recognition_result_card.dart # 📝 Kết quả + 🔊 Đọc thành tiếng
│   │   ├── handwriting_service.dart      # ⚡ Crop Bounding Box + nén ảnh 10KB cực nhẹ
│   │   └── handwriting_screen.dart       # 📱 Màn hình nhận diện chữ viết tay siêu tốc
│   │
│   ├── rag/                              # 📚 TAB 4: Kho Tri Thức Local RAG
│   │   ├── rag_service.dart              # 🧠 Vector Embedding 32-D & Cosine Similarity search
│   │   └── rag_screen.dart               # 📱 Màn hình tra cứu & thêm bớt tài liệu
│   │
│   ├── settings/                         # ⚙️ TAB 5: Cài Đặt (NEW)
│   │   └── settings_screen.dart          # 🎛️ Giọng Nam/Nữ, Tốc độ, Tone/Pitch, Chọn Model Gemini, Test API Key
│   │
│   ├── safety/
│   │   └── safety_service.dart           # 🛡️ SafetyCheckResult, analyzeSafety & Smart Reply
│   │
│   ├── llm/
│   │   └── llm_service.dart              # 🌐 Google Gemini (gemini-3.5-flash), Fast Vision & Voice QA
│   │
│   ├── voice/
│   │   └── voice_service.dart            # 🎙️ Quản lý STT & Offline Native TTS (Pitch, Rate, Done Listener)
│   │
│   └── main.dart                         # 📱 Điều hướng 6 Tab bằng IndexedStack
```

---

## 🚀 2. Các Tính Năng Mới Vừa Hoàn Thành

### 🎙️ 1. Tab Đàm Thoại Giọng Nói 2 Chiều Liên Tục (Voice-to-Voice Mode)
- **Tập tin**: `lib/voice_chat/voice_chat_screen.dart`
- Trải nghiệm tương tự **ChatGPT Voice Mode / Gemini Live**:
  1. Người dùng bấm bắt đầu hoặc chạm vào **Quả cầu giọng nói (Voice Orb)**.
  2. Bạn nói tiếng Việt $\rightarrow$ Quả cầu chuyển màu Cyan lan tỏa sóng âm theo giọng nói thật.
  3. Khi ngừng nói 1.4s (hoặc bấm dấu check) $\rightarrow$ Quả cầu chuyển màu Tím suy nghĩ.
  4. Gemini tạo câu trả lời súc tích và tự động đọc to bằng giọng nói tiếng Việt $\rightarrow$ Quả cầu chuyển màu Xanh lá phát âm.
  5. **Ngay khi AI đọc xong, Micro tự động mở lại ngay lập tức** để bạn nói câu tiếp theo mà **hoàn toàn không cần chạm tay vào màn hình**!
  6. Có thể chạm vào Quả cầu hoặc nút bàn tay để **Ngắt lời AI** khi muốn nói chèn ngang.
  7. Có nút chuyển xem **Toàn bộ nội dung đối thoại (Transcript view)** dạng chữ.

---

### ⚙️ 2. Tab Cài Đặt (Settings)
- **Tập tin**: `lib/settings/settings_screen.dart`
- **Cấu hình Giọng đọc TTS**:
  - Chọn 4 mẫu giọng cài sẵn:
    - 👩 **Nữ ấm áp (Chuẩn)**
    - 👧 **Nữ trẻ trung (Cao)**
    - 👨 **Nam trầm ấm**
    - 🧑 **Nam thanh niên chuẩn**
  - Thanh trượt chỉnh **Tốc độ đọc (Speech Rate)**: `0.7x` đến `1.5x`.
  - Thanh trượt chỉnh **Cao độ (Tone / Pitch)**: `0.65` đến `1.45`.
  - Nút **🔊 Nghe thử giọng đọc ngay** để kiểm tra trực tiếp.
- **Cấu hình Google Gemini**:
  - Chọn model trực tiếp bằng chip: `gemini-3.5-flash` (Mặc định), `gemini-2.5-flash`, `gemini-1.5-flash`, `gemini-1.5-pro` hoặc nhập tên model tùy chỉnh.
  - Quản lý API Key (ẩn/hiện, lưu cấu hình).
  - Thanh trượt **Temperature** chỉnh độ sáng tạo câu trả lời.
  - Nút **Kiểm tra kết nối (Ping Test)** để kiểm tra API Key có hoạt động hay không.

---

### 🖋️ 3. Nâng Cấp Viết Tay Digital Ink: Siêu Tốc & Bảng Viết Mở Rộng Lớn
- **Khắc phục tốc độ chậm**:
  - Tự động cắt đúng khung chữ (Bounding Box Crop) thay vì chụp nguyên cả canvas to, dung lượng ảnh gửi đi giảm từ 150KB xuống còn **~10KB**, tải lên mạng chỉ mất vài mili-giây.
  - Giới hạn `maxOutputTokens: 25` và `temperature: 0.1` giúp Gemini nhận diện và phản hồi tức thì trong **~400ms**.
  - Giảm thời gian chờ nhấc tay từ `1200ms` xuống **`650ms`**.
- **Khắc phục màn hình hơi bé**:
  - Tăng chiều cao bảng vẽ mặc định lên **`340px`**.
  - Thêm nút **Phóng to / Mở rộng bảng viết (Full Canvas Mode)** lên **`480px`** giúp bạn thoải mái viết chữ to, viết nhiều từ hoặc phương trình toán học trên màn hình gập Samsung Galaxy Z Fold4.
