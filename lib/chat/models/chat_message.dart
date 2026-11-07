import '../../rag/rag_service.dart';
import '../../safety/safety_service.dart';

/// Mô hình tin nhắn trong khung Chat
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<RagSearchResult> citations;
  final SafetyCheckResult? safetyAlert;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.citations = const [],
    this.safetyAlert,
  });
}

