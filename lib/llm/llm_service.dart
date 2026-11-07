import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../rag/rag_service.dart';

/// Service quản lý kết nối Google Gemini LLM
/// Nạp cấu hình từ .env, hỗ trợ chọn model linh hoạt, chỉnh temperature và Digital Ink siêu tốc
class LlmService extends ChangeNotifier {
  String _apiKey = '';
  String _modelName = 'gemini-3.5-flash';
  double _temperature = 0.7;

  /// Lưu lịch sử hội thoại ngắn hạn (tối đa 6 lượt gần nhất) để AI trả lời có ngữ cảnh
  final List<Map<String, String>> _history = [];

  /// Đọc GEMINI_API_KEY và GEMINI_MODEL từ file .env thông qua rootBundle
  Future<void> loadFromEnv() async {
    try {
      final envContent = await rootBundle.loadString('.env');
      for (final rawLine in envContent.split('\n')) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final idx = line.indexOf('=');
        if (idx == -1) continue;
        final key = line.substring(0, idx).trim();
        final value = line
            .substring(idx + 1)
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", '');
        if (key == 'GEMINI_API_KEY' &&
            value.isNotEmpty &&
            value != 'YOUR_GOOGLE_GEMINI_API_KEY_HERE') {
          _apiKey = value;
        } else if (key == 'GEMINI_MODEL' && value.isNotEmpty) {
          _modelName = value;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Env load note: $e');
    }
  }

  /// Kiểm tra đã có API Key hợp lệ chưa (không lộ nội dung key)
  bool get hasApiKey => _apiKey.trim().isNotEmpty;

  /// Trả về chuỗi đã che mật khẩu để hiển thị an toàn trên UI (VD: ••••••••••••)
  String get maskedApiKey {
    if (!hasApiKey) return 'Chưa cấu hình trong .env';
    return '•••••••••••••••••••• (Đã nạp bảo mật)';
  }

  String get rawApiKey => _apiKey;

  String get modelName => _modelName;
  double get temperature => _temperature;

  void updateConfig({
    String? apiKey,
    String? modelName,
    double? temperature,
  }) {
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      _apiKey = apiKey.trim();
    }
    if (modelName != null && modelName.trim().isNotEmpty) {
      _modelName = modelName.trim();
    }
    if (temperature != null) {
      _temperature = temperature.clamp(0.0, 1.0);
    }
    notifyListeners();
  }

  /// Thử nghiệm kết nối API Key và Model
  Future<bool> testConnection() async {
    if (!hasApiKey) return false;
    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(maxOutputTokens: 10),
      );
      final resp = await model.generateContent([Content.text('Ping')]);
      return resp.text != null;
    } catch (e) {
      debugPrint('Test connection failed: $e');
      return false;
    }
  }

  /// Xóa lịch sử hội thoại khi người dùng làm mới đoạn chat
  void clearHistory() {
    _history.clear();
  }

  /// Danh sách model ưu tiên kèm fallback tự động
  List<String> get _candidateModels => [
        _modelName,
        if (_modelName != 'gemini-2.5-flash') 'gemini-2.5-flash',
        if (_modelName != 'gemini-1.5-flash') 'gemini-1.5-flash',
      ];

  /// Nhận diện chữ viết tay Digital Ink siêu tốc (Tối ưu token, giới hạn 25 tokens để phản hồi ngay trong ~400ms)
  Future<String> recognizeDigitalInk({
    required Uint8List canvasPngBytes,
    required String strokeTelemetrySummary,
  }) async {
    if (!hasApiKey) {
      return '⚠️ Chưa có GEMINI_API_KEY trong file .env';
    }

    const prompt = 'OCR nhận diện chữ viết tay: Đọc chính xác chữ hoặc số trong ảnh đính kèm. CHỈ TRẢ VỀ DUY NHẤT CHỮ ĐÓ, không thêm lời chào, không giải thích.';

    Object? lastError;
    // Với nhận diện ảnh viết tay, ưu tiên model flash nhanh nhất
    final fastCandidates = [
      _modelName,
      'gemini-2.5-flash',
      'gemini-1.5-flash',
    ];

    for (final candidate in fastCandidates) {
      try {
        final model = GenerativeModel(
          model: candidate,
          apiKey: _apiKey,
          generationConfig: GenerationConfig(
            maxOutputTokens: 25,
            temperature: 0.1,
          ),
        );
        final response = await model.generateContent([
          Content.multi([
            TextPart(prompt),
            DataPart('image/png', canvasPngBytes),
          ]),
        ]);
        final text = response.text?.trim() ?? '';
        if (text.isNotEmpty) {
          // Làm sạch dấu ngoặc kép thừa nếu model tự ý bọc lại
          return text.replaceAll('"', '').replaceAll("'", '').trim();
        }
      } catch (e) {
        lastError = e;
        final errStr = e.toString().toLowerCase();
        final isModelError = errStr.contains('not found') ||
            errStr.contains('not supported') ||
            errStr.contains('404') ||
            errStr.contains('invalid argument');
        if (isModelError) {
          continue;
        } else {
          break;
        }
      }
    }

    final safeErr =
        (lastError?.toString() ?? 'Lỗi kết nối').replaceAll(_apiKey, '***');
    return '⚠️ Lỗi nhận diện: $safeErr';
  }

  /// Gọi Google Gemini API theo dạng Stream (hỗ trợ RAG Context + Lịch sử hội thoại + Fallback)
  Stream<String> askLlmStream({
    required String query,
    required List<RagSearchResult> retrievedDocs,
  }) async* {
    if (!hasApiKey) {
      yield '⚠️ Chưa tìm thấy `GEMINI_API_KEY` trong file `.env`.\n\n'
          'Bạn hãy mở tab Cài đặt ⚙️ để nhập API Key nhé!';
      return;
    }

    final contextText = retrievedDocs.isEmpty
        ? 'Không có tài liệu nội bộ liên quan trực tiếp.'
        : retrievedDocs
            .asMap()
            .entries
            .map(
              (entry) =>
                  '[Tài liệu ${entry.key + 1} - ${entry.value.title} (Độ khớp ${(entry.value.similarity * 100).toStringAsFixed(0)}%)]: ${entry.value.content}',
            )
            .join('\n');

    final historyText = _history.isEmpty
        ? ''
        : '\n--- LỊCH SỬ HỘI THOẠI GẦN ĐÂY ---\n'
            '${_history.map((h) => "Người dùng: ${h['user']}\nAI: ${h['ai']}").join('\n')}\n';

    final prompt = '''
Bạn là Trợ lý AI thông minh tiếng Việt tích hợp trên ứng dụng di động Flutter.
Hãy trả lời câu hỏi của người dùng một cách tự nhiên, rõ ràng, súc tích và hữu ích.
Nếu thông tin có trong phần [TÀI LIỆU NỘI BỘ (RAG CONTEXT)] bên dưới, hãy ưu tiên sử dụng chính xác thông tin đó và trích dẫn nguồn. Nếu câu hỏi nằm ngoài tài liệu nội bộ, hãy trả lời bằng kiến thức của bạn.

--- TÀI LIỆU NỘI BỘ (RAG CONTEXT) ---
$contextText
$historyText
--- CÂU HỎI HIỆN TẠI CỦA NGƯỜI DÙNG ---
$query
''';

    String fullAiResponse = '';
    Object? lastException;

    for (final candidate in _candidateModels) {
      try {
        final model = GenerativeModel(
          model: candidate,
          apiKey: _apiKey,
          generationConfig: GenerationConfig(temperature: _temperature),
        );
        final responseStream =
            model.generateContentStream([Content.text(prompt)]);

        await for (final chunk in responseStream) {
          if (chunk.text != null && chunk.text!.isNotEmpty) {
            fullAiResponse += chunk.text!;
            yield chunk.text!;
          }
        }

        if (fullAiResponse.trim().isNotEmpty) {
          _history.add({
            'user': query,
            'ai': fullAiResponse.length > 350
                ? '${fullAiResponse.substring(0, 350)}...'
                : fullAiResponse,
          });
          if (_history.length > 6) {
            _history.removeAt(0);
          }
        }
        return;
      } catch (e) {
        lastException = e;
        final errStr = e.toString().toLowerCase();
        final isModelError = errStr.contains('not found') ||
            errStr.contains('not supported') ||
            errStr.contains('404') ||
            errStr.contains('invalid argument');
        if (isModelError && fullAiResponse.isEmpty) {
          debugPrint('Model $candidate unavailable, falling back...');
          continue;
        } else {
          break;
        }
      }
    }

    final safeError = (lastException?.toString() ?? 'Lỗi không xác định')
        .replaceAll(_apiKey, '***');
    yield '\n⚠️ Không thể kết nối tới Google Gemini API.\n'
        'Chi tiết: $safeError\n'
        '💡 Gợi ý: Mở tab Cài đặt ⚙️ để kiểm tra API Key hoặc chọn model khác.';
  }

  /// Trả lời nhanh cho chế độ Voice-to-Voice (câu trả lời súc tích, ngắn gọn để đọc to tự nhiên)
  Future<String> askLlmVoiceConversation({
    required String query,
    required List<RagSearchResult> retrievedDocs,
  }) async {
    if (!hasApiKey) {
      return 'Bạn hãy vào tab Cài đặt để nạp khóa Gemini A P I nhé!';
    }

    final contextText = retrievedDocs.isEmpty
        ? ''
        : 'Thông tin nội bộ: ${retrievedDocs.map((d) => d.content).join(". ")}';

    final prompt = '''
Bạn là Trợ lý AI đang trò chuyện bằng giọng nói trực tiếp với người dùng qua tai nghe/loa.
Quy tắc quan trọng:
1. Trả lời súc tích, ngắn gọn trong 1 đến 3 câu dễ hiểu.
2. Không dùng ký tự markdown như *, #, _, gạch đầu dòng vì nội dung này sẽ được phát qua loa.
3. Văn phong tự nhiên, thân thiện như đang đàm thoại trực tiếp.

$contextText
Người dùng hỏi: $query
Trợ lý trả lời:
''';

    for (final candidate in _candidateModels) {
      try {
        final model = GenerativeModel(
          model: candidate,
          apiKey: _apiKey,
          generationConfig: GenerationConfig(
            maxOutputTokens: 150,
            temperature: 0.6,
          ),
        );
        final resp = await model.generateContent([Content.text(prompt)]);
        final text = resp.text?.trim() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      } catch (e) {
        debugPrint('Voice conversation fallback from $candidate: $e');
        continue;
      }
    }
    return 'Xin lỗi bạn, kết nối Gemini gặp sự cố, bạn vui lòng nói lại nhé!';
  }
}

extension _RagResultTitle on RagSearchResult {
  String get title => document.title;
  String get content => document.content;
}
