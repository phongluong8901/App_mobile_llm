# 🏗️ Kiến trúc Kỹ thuật Chi tiết (ARCHITECTURE.md)

Tài liệu này mô tả luồng dữ liệu (Data Flow), thuật toán bên trong từng service của project `llm_app`, và hướng dẫn nâng cấp/nhúng các file trọng số nhị phân (`.gguf`, `.tflite`, `.onnx`) khi đóng gói bản Production.

---

## 1. Sơ đồ Luồng Dữ liệu Tổng thể (End-to-End Pipeline)

```text
[Microphone PCM 16kHz] 
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ 1. RNNoise DSP Filter (audio_ml_service.dart)          │
│    - Ước lượng nền nhiễu EMA + Spectral Gate           │
│    - Trích xuất 24 băng tần Mel-Spectrogram            │
└──────┬───────────────────────────┬─────────────────────┘
       │                           │
       ▼                           ▼
┌──────────────────────┐    ┌────────────────────────────┐
│ 2. YAMNet (521 lớp)  │    │ 3. Offline STT & Wake-word │
│ - Phát hiện kính vỡ, │    │ - Chuyển giọng nói -> Text │
│   trẻ khóc, còi hú   │    │ - Bắt từ khóa "Bật đèn",   │
│ - Tự bật đèn an ninh │    │   "Tắt quạt", "Mở cửa"     │
└──────────────────────┘    └──────┬─────────────────────┘
                                   │
       ┌───────────────────────────┘
       ▼
┌────────────────────────────────────────────────────────┐
│ 4. Toxic / Spam Shield & Digital Ink (x, y, t)         │
│    - Chặn tin nhắn lừa đảo OTP / Phishing              │
│    - Hoặc nhận văn bản từ nét viết tay Canvas (x,y,t)  │
└──────┬─────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ 5. Local Semantic Search & RAG (slm_rag_service.dart)  │
│    - Nhúng câu hỏi thành Vector 64 chiều chuẩn hóa L2  │
│    - Truy xuất Top-K đoạn PDF/Note bằng Cosine Sim     │
└──────┬─────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ 6. On-Device SLM (.gguf / .tflite) hoặc Hybrid Gemini  │
│    - Kết hợp Context RAG + Prompt để sinh câu trả lời  │
│    - Sinh 3 gợi ý Smart Reply tiếp theo                │
└──────┬─────────────────────────────────────────────────┘
       │
       ▼
┌────────────────────────────────────────────────────────┐
│ 7. Offline TTS (MainActivity.kt MethodChannel)         │
│    - Đọc phản hồi bằng giọng tự nhiên ngay trên máy    │
└────────────────────────────────────────────────────────┘
```

---

## 2. Chi tiết từng Module trong Codebase

### 2.1. Nhóm 5 — Ngôn ngữ, Văn bản & On-Device LLM / RAG
- **File lõi**: `lib/services/slm_rag_service.dart`
- **Thuật toán Vector Embedding cục bộ (`computeEmbedding`)**:
  - Mỗi đoạn tài liệu (Chunk) và câu truy vấn được ánh xạ vào không gian vector $\mathbb{R}^{64}$.
  - **Chiều `0..19`**: Đặc trưng cụm ngữ nghĩa (Semantic Topic Clusters) cho 10 miền chủ đề (SLM/AI, Vector/RAG, Audio/Speech, Smart Home IoT, YAMNet Security, DSP RNNoise, Digital Ink, Bảo mật/Chống lừa đảo, Lịch biểu, Phần cứng Mobile).
  - **Chiều `20..63`**: Băm từ vựng FNV-1a (`Word-level hashing`) kết hợp `Character 3-grams` giúp khớp chính xác cả khi người dùng gõ sai chính tả nhẹ hoặc viết tắt.
  - Cuối cùng chuẩn hóa L2 ($\|v\|_2 = 1$) để tích vô hướng chính là **Cosine Similarity**.
- **Nhận diện chữ viết tay Digital Ink (`recognizeDigitalInk`)**:
  - Thu nhận danh sách các nét (`List<InkStroke>`), mỗi nét chứa các điểm `InkPoint(x, y, t)`.
  - Tính toán: kích thước hộp bao ($W \times H$), tỉ lệ khung hình ($W/H$), vận tốc trung bình ($\text{px/ms}$), khoảng cách điểm đầu-cuối (phát hiện nét khép kín như chữ `O`, `0`, `a`) và số lượng nét rời để suy ra danh sách ứng viên từ khóa.

### 2.2. Nhóm 3 — Âm thanh & Giọng nói (On-Device Audio / Speech ML)
- **File lõi**: `lib/services/audio_ml_service.dart` & `android/app/src/main/kotlin/com/example/llm_app/MainActivity.kt`
- **Native Offline TTS (`MethodChannel`)**:
  - Được cài đặt trực tiếp trong `MainActivity.kt` bằng `android.speech.tts.TextToSpeech` với ngôn ngữ ưu tiên `Locale("vi", "VN")`.
  - Không phụ thuộc mạng Internet và không cần cài thêm plugin bên thứ ba.
- **Lọc ồn RNNoise & Mel-Spectrogram (`processRnnoiseFrame`)**:
  - Duy trì biến trạng thái `noiseFloorDb` cập nhật theo công thức trung bình trượt mũ:
    $$\text{NoiseFloor}_t = 0.92 \cdot \text{NoiseFloor}_{t-1} + 0.08 \cdot \min(\text{RawDb}_t, -35)$$
  - Khi tín hiệu thu vào nằm gần nền nhiễu (tiếng quạt, tiếng gió), cổng phổ (Spectral Gate) triệt tiêu tới `15.5 dB` ở các băng tần ngoài dải thoại con người (`300Hz - 3400Hz`).

---

## 3. Hướng dẫn Nâng cấp lên Trọng số Model Thực tế (Production Weights)

Khi bạn muốn gắn file model `.gguf`, `.tflite`, hoặc `.onnx` thực tế vào thư mục `assets/models/`:

| Thành phần | Thư viện Flutter khuyên dùng | File Model cần tải |
| :--- | :--- | :--- |
| **On-Device SLM (.gguf)** | `fllama` hoặc `llama_cpp_dart` | `qwen2.5-1.5b-instruct-q4_k_m.gguf` (~986 MB) |
| **On-Device Embedding** | `onnxruntime` hoặc `tflite_flutter` | `bge-micro-v2-quantized.onnx` (~22 MB) |
| **Digital Ink (x, y, t)** | `google_mlkit_digital_ink_recognition` | Model `vi` (tải tự động qua ML Kit ~15 MB) |
| **Offline STT + TTS + KWS** | `sherpa_onnx` | `sherpa-onnx-whisper-tiny` + `vits-piper-vi_VN` |
| **Audio Event (YAMNet)** | `tflite_flutter` | `yamnet.tflite` (từ TensorFlow Hub ~3.7 MB) |

