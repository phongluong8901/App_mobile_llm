# AI Mobile App: Google LLM (gemini-3.5-flash), Giọng Nói & Local RAG

## 🎙️ 1. Hiệu Ứng Trực Quan Khi Đang Nói (Voice Listening Effect):
- Khi bạn bấm vào nút **Micro 🎙️**:
  - Nút Micro đổi sang **màu đỏ kèm hiệu ứng phát sáng (Glow Pulse)**.
  - Phía trên thanh nhập xuất hiện **thanh trạng thái sóng âm thời gian thực** (7 cột sóng equalizer dao động theo biên độ âm thanh giọng nói thật).
  - Có **chấm đỏ 🔴 nhấp nháy** thông báo `Đang lắng nghe...`.
  - Khung nhập liệu đổi sang **viền đỏ nổi bật** và tự động điền từng từ bạn nói.
  - Khi bạn ngừng nói hoặc bấm tắt, hiệu ứng tự động biến mất và trở lại thanh nhập bình thường.

## ⚡ 2. Model Mặc Định:
- **`gemini-3.5-flash`** (Cấu hình sẵn trong file [.env](.env) tại `GEMINI_MODEL=gemini-3.5-flash`).
- Cơ chế fallback thông minh tự động sang `gemini-2.5-flash` / `gemini-1.5-flash` nếu server Google yêu cầu, chống lỗi 404.

## 🔒 3. Bảo Mật API Key:
- Key được lưu trong [.env](.env), **hoàn toàn ẩn khỏi màn hình giao diện**.

## 🔊 4. Âm Thanh Theo Yêu Cầu:
- Mặc định im lặng, chỉ đọc khi bấm icon **🔊** cạnh tin nhắn.
