import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Card hiển thị Chữ in nhận diện được (Text) + Nút Đọc to (Speech) + Nút Sao chép
class RecognitionResultCard extends StatelessWidget {
  final TextEditingController controller;
  final bool isSpeaking;
  final VoidCallback onClear;
  final VoidCallback onSpeak;

  const RecognitionResultCard({
    super.key,
    required this.controller,
    required this.isSpeaking,
    required this.onClear,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.text_fields_rounded,
                color: Color(0xFF818CF8),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kết quả Chữ in (Text) & Phát âm (Speech):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                TextButton(
                  onPressed: onClear,
                  child: const Text(
                    'Xóa chữ',
                    style: TextStyle(fontSize: 11.5, color: Colors.white54),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            decoration: InputDecoration(
              hintText:
                  'Chữ in sau khi nhận diện sẽ hiện tại đây (có thể chỉnh sửa)...',
              hintStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.normal,
                color: Colors.white38,
              ),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isSpeaking
                        ? Colors.amber.shade700
                        : const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: onSpeak,
                  icon: Icon(
                    isSpeaking
                        ? Icons.stop_circle_outlined
                        : Icons.record_voice_over_rounded,
                  ),
                  label: Text(
                    isSpeaking
                        ? 'Đang đọc... (Nhấn để dừng)'
                        : '🔊 Đọc thành tiếng (Speech)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Đã sao chép văn bản chữ in!'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Copy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

