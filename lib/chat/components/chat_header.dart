import 'package:flutter/material.dart';
import '../../llm/llm_service.dart';
import '../../voice/voice_service.dart';

/// Header hiển thị model LLM đang dùng, trạng thái bảo mật API Key và các nút thao tác nhanh
class ChatHeader extends StatelessWidget {
  final LlmService llmService;
  final VoiceService voiceService;
  final bool isStreaming;
  final VoidCallback onClearChat;
  final VoidCallback onOpenSettings;

  const ChatHeader({
    super.key,
    required this.llmService,
    required this.voiceService,
    required this.isStreaming,
    required this.onClearChat,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.9),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF334155), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: Color(0xFF818CF8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model: ${llmService.modelName}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  llmService.hasApiKey
                      ? '🔒 API Key bảo mật (.env) • RAG sẵn sàng'
                      : '⚠️ Chưa nạp API Key trong .env',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: llmService.hasApiKey
                        ? const Color(0xFF34D399)
                        : Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ),
          if (voiceService.isSpeaking)
            TextButton.icon(
              onPressed: () => voiceService.stopSpeak(),
              icon: const Icon(
                Icons.stop_circle_outlined,
                size: 16,
                color: Colors.amberAccent,
              ),
              label: const Text(
                'Dừng đọc',
                style: TextStyle(fontSize: 11, color: Colors.amberAccent),
              ),
            ),
          IconButton(
            tooltip: 'Làm mới cuộc trò chuyện',
            onPressed: isStreaming ? null : onClearChat,
            icon: const Icon(
              Icons.cleaning_services_rounded,
              size: 18,
              color: Colors.white60,
            ),
          ),
          IconButton(
            tooltip: 'Cài đặt Model / Key',
            onPressed: onOpenSettings,
            icon: const Icon(
              Icons.tune_rounded,
              size: 19,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

