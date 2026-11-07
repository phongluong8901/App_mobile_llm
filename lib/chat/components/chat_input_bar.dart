import 'package:flutter/material.dart';

/// Thanh nhập liệu phía dưới màn hình chat (Mic với vòng sóng âm Pulse + TextField + Send Button)
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final double soundLevel;
  final bool isStreaming;
  final AnimationController pulseAnimController;
  final VoidCallback onToggleMic;
  final VoidCallback onSend;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isListening,
    required this.soundLevel,
    required this.isStreaming,
    required this.pulseAnimController,
    required this.onToggleMic,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Nút Mic với vòng Ripple động
            GestureDetector(
              onTap: onToggleMic,
              child: AnimatedBuilder(
                animation: pulseAnimController,
                builder: (context, child) {
                  final rippleRadius = isListening
                      ? 6.0 +
                          (soundLevel * 10.0) +
                          (pulseAnimController.value * 4.0)
                      : 0.0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isListening
                          ? Colors.redAccent
                          : const Color(0xFF0F172A),
                      boxShadow: isListening
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withValues(
                                  alpha: 0.45 +
                                      pulseAnimController.value * 0.25,
                                ),
                                blurRadius: 12 + (soundLevel * 16),
                                spreadRadius: rippleRadius,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: isListening ? Colors.white : Colors.white70,
                      size: 22,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: isListening
                      ? '🎙️ Đang nghe giọng nói của bạn...'
                      : 'Nhập câu hỏi hoặc nhấn 🎙️ để nói...',
                  hintStyle: TextStyle(
                    color: isListening
                        ? Colors.redAccent.shade100
                        : Colors.white54,
                    fontWeight:
                        isListening ? FontWeight.w600 : FontWeight.normal,
                  ),
                  filled: true,
                  fillColor: isListening
                      ? Colors.redAccent.withValues(alpha: 0.08)
                      : const Color(0xFF0F172A),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: isListening
                          ? Colors.redAccent.withValues(alpha: 0.6)
                          : Colors.transparent,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: isListening
                          ? Colors.redAccent
                          : const Color(0xFF6366F1),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                disabledBackgroundColor: const Color(0xFF334155),
                padding: const EdgeInsets.all(12),
              ),
              onPressed: isStreaming ? null : onSend,
              icon: isStreaming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

