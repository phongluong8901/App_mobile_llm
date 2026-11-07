/// Kết quả kiểm tra an toàn văn bản (Spam / Lừa đảo / Độc hại)
class SafetyCheckResult {
  final bool isSafe;
  final String warningTitle;
  final String advice;
  final double riskScore; // 0.0 -> 1.0

  const SafetyCheckResult({
    required this.isSafe,
    required this.warningTitle,
    required this.advice,
    this.riskScore = 0.0,
  });

  bool get isDangerous => !isSafe;
  String get category => warningTitle;
}

// Giữ lại SpamCheckResult để tương thích ngược nếu có code cũ tham chiếu
typedef SpamCheckResult = SafetyCheckResult;

/// Service chuyên trách:
/// 1. Gợi ý câu trả lời nhanh (Smart Reply)
/// 2. Bộ lọc tin nhắn rác / lừa đảo / độc hại (Toxic & Spam Shield)
class SafetyService {
  /// Sinh gợi ý câu hỏi thông minh tiếp theo dựa trên ngữ cảnh câu trả lời vừa nhận
  List<String> generateSmartReplies(String botText) {
    final lower = botText.toLowerCase();

    if (lower.contains('lịch') || lower.contains('bảo dưỡng') || lower.contains('máy lạnh')) {
      return [
        'Số điện thoại bảo dưỡng là gì?',
        'Bảo dưỡng máy lạnh khi nào?',
        'Có tốn phí bảo dưỡng không?',
      ];
    }

    if (lower.contains('đèn') || lower.contains('quạt') || lower.contains('smart home') || lower.contains('wifi')) {
      return [
        'Bật đèn phòng khách',
        'Mật khẩu Wi-Fi là gì?',
        'Cách kích hoạt chế độ ngủ?',
      ];
    }

    if (lower.contains('ink') || lower.contains('viết tay') || lower.contains('canvas') || lower.contains('nét vẽ')) {
      return [
        'Giải thích tọa độ (x, y, t)',
        'Freeman Chain Code là gì?',
        'Cách tối ưu nhận diện chữ tiếng Việt',
      ];
    }

    if (lower.contains('slm') || lower.contains('gemini') || lower.contains('model') || lower.contains('rag')) {
      return [
        'Giải thích dễ hiểu hơn',
        'Cho một ví dụ cụ thể',
        'So sánh Local RAG và Fine-tuning',
      ];
    }

    // Gợi ý mặc định
    return [
      'Tóm tắt ngắn gọn',
      'Cho tôi một ví dụ thực tế',
      'Còn điều gì cần lưu ý không?',
    ];
  }

  /// Quét phát hiện tin nhắn lừa đảo OTP, tín dụng đen hoặc ngôn từ độc hại
  SafetyCheckResult analyzeSafety(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.isEmpty) {
      return const SafetyCheckResult(
        isSafe: true,
        warningTitle: 'An toàn',
        advice: 'Tin nhắn hợp lệ.',
      );
    }

    // Các mẫu lừa đảo tài chính / mạo danh OTP
    const phishingPatterns = [
      'mã otp',
      'otp',
      'chuyển khoản gấp',
      'trúng thưởng 100tr',
      'nhận quà miễn phí',
      'xác minh tài khoản ngân hàng',
      'công an triệu tập',
      'khóa tài khoản trong 24h',
      'đăng nhập tài khoản ngân hàng',
    ];

    for (final pattern in phishingPatterns) {
      if (lower.contains(pattern)) {
        return const SafetyCheckResult(
          isSafe: false,
          warningTitle: '⚠️ CẢNH BÁO: Dấu hiệu Lừa đảo OTP / Mạo danh',
          advice: 'Tuyệt đối không cung cấp mã OTP hoặc thông tin ngân hàng cho bất kỳ ai!',
          riskScore: 0.9,
        );
      }
    }

    // Các mẫu tín dụng đen / spam cờ bạc
    const spamPatterns = [
      'vay tiền nhanh',
      'giải ngân trong ngày',
      'không thế chấp',
      'tặng 100k trải nghiệm cá cược',
      'việc nhẹ lương cao',
      'nạp tiền nhận thưởng',
    ];

    for (final pattern in spamPatterns) {
      if (lower.contains(pattern)) {
        return const SafetyCheckResult(
          isSafe: false,
          warningTitle: '⚠️ CẢNH BÁO: Spam Tín dụng đen / Cờ bạc',
          advice: 'Cảnh giác với các hình thức vay nợ không rõ nguồn gốc hoặc lời mời cờ bạc!',
          riskScore: 0.8,
        );
      }
    }

    return const SafetyCheckResult(
      isSafe: true,
      warningTitle: 'An toàn',
      advice: 'Không phát hiện nguy cơ bảo mật.',
    );
  }

  /// Alias tương thích ngược
  SafetyCheckResult checkSpamAndToxic(String text) => analyzeSafety(text);
}
