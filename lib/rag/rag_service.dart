import 'dart:math';

/// Mô hình 1 tài liệu lưu trong Kho Tri Thức (Vector Store)
class RagDocument {
  final String id;
  final String title;
  final String category;
  final String content;
  final List<double> vector;

  RagDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.content,
    required this.vector,
  });
}

/// Kết quả tìm kiếm tương đồng Cosine Similarity
class RagSearchResult {
  final RagDocument document;
  final double similarity;

  RagSearchResult({required this.document, required this.similarity});
}

/// Service quản lý Local RAG (Vector Embedding 32-D & Cosine Similarity)
class RagService {
  final List<RagDocument> vectorStore = [];

  RagService() {
    _seedInitialDocuments();
  }

  void _seedInitialDocuments() {
    final samples = [
      (
        'Mật khẩu Wifi & Mạng nội bộ',
        'Cá nhân',
        'Wifi tầng 1 là "Home_5G" mật khẩu "12345678@". Wifi phòng làm việc tầng 2 là "AI_Lab_Pro" mật khẩu "flutter2026".'
      ),
      (
        'Lịch bảo hành & Sửa chữa thiết bị',
        'Gia đình',
        'Máy lạnh Daikin phòng khách bảo dưỡng định kỳ ngày 15 hàng tháng. Số điện thoại kỹ thuật viên: 0909.123.456.'
      ),
      (
        'Kiến thức Đồ án: On-device SLM & Local RAG',
        'Học tập',
        'Local RAG giúp kết hợp dữ liệu cá nhân lưu cục bộ trên điện thoại với mô hình ngôn ngữ (SLM/LLM) thông qua tìm kiếm tương đồng Cosine Similarity mà không cần huấn luyện lại mô hình.'
      ),
      (
        'Hướng dẫn điều khiển Nhà thông minh (Smart Home)',
        'Smart Home',
        'Bạn có thể sang Tab Voice Smart Home và nói "Bật đèn", "Tắt đèn", "Bật quạt", "Tắt quạt" hoặc "Chế độ ngủ" để điều khiển thiết bị bằng giọng nói tiếng Việt.'
      ),
    ];

    for (var i = 0; i < samples.length; i++) {
      final (title, category, content) = samples[i];
      vectorStore.add(
        RagDocument(
          id: 'doc_$i',
          title: title,
          category: category,
          content: content,
          vector: createVector('$title $content'),
        ),
      );
    }
  }

  /// Chuẩn hóa chuỗi tiếng Việt (bỏ dấu câu, chuyển chữ thường)
  String _cleanText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:"()\[\]{}\-\/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Chuyển đổi văn bản thành Vector 32 chiều đã chuẩn hóa L2 (L2-Normalized Embedding)
  List<double> createVector(String text) {
    final List<double> vec = List.filled(32, 0.0);
    final cleaned = _cleanText(text);
    final words = cleaned.split(' ');
    for (final word in words) {
      if (word.isEmpty) continue;
      final hash1 = word.codeUnits.fold(0, (int p, int c) => p * 31 + c).abs();
      final hash2 = word.codeUnits.fold(0, (int p, int c) => p * 17 + c).abs();
      vec[hash1 % 32] += 1.0;
      vec[hash2 % 32] += 0.5;
    }
    double norm = sqrt(vec.fold(0.0, (p, c) => p + c * c));
    if (norm == 0) return vec;
    return vec.map((e) => e / norm).toList();
  }

  /// Tính độ tương đồng Cosine Similarity giữa 2 vector
  double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Truy xuất Top-K tài liệu liên quan nhất (Hybrid: Cosine Similarity + Keyword Overlap)
  List<RagSearchResult> searchRelevantDocs(String query, {int topK = 2}) {
    final qClean = _cleanText(query);
    if (qClean.isEmpty) return [];

    final queryWords =
        qClean.split(' ').where((w) => w.length >= 2).toSet();
    final qVec = createVector(query);

    final results = vectorStore.map((doc) {
      final cosSim = cosineSimilarity(qVec, doc.vector);
      final docClean = _cleanText('${doc.title} ${doc.content}');

      // Tính điểm khớp từ khóa trực tiếp để hỗ trợ truy vấn tiếng Việt ngắn
      int matchedWords = 0;
      for (final w in queryWords) {
        if (docClean.contains(w)) matchedWords++;
      }
      final keywordScore =
          queryWords.isEmpty ? 0.0 : matchedWords / queryWords.length;

      final combinedScore = (cosSim * 0.65 + keywordScore * 0.35).clamp(0.0, 1.0);
      return RagSearchResult(
        document: doc,
        similarity: combinedScore,
      );
    }).toList();

    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.where((r) => r.similarity > 0.12).take(topK).toList();
  }

  void addDocument({
    required String title,
    required String category,
    required String content,
  }) {
    vectorStore.insert(
      0,
      RagDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        content: content,
        vector: createVector('$title $content'),
      ),
    );
  }

  void removeDocument(String id) {
    vectorStore.removeWhere((doc) => doc.id == id);
  }
}
