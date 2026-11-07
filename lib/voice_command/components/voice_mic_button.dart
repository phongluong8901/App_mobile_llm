import 'package:flutter/material.dart';

/// Nút bấm Microphone trung tâm có vòng sáng nhịp thở và hiệu ứng sóng âm theo dB thực tế
class VoiceMicButton extends StatelessWidget {
  final bool isListening;
  final double soundLevel;
  final VoidCallback onTap;

  const VoiceMicButton({
    super.key,
    required this.isListening,
    required this.soundLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isListening
                    ? [Colors.redAccent, Colors.deepOrange]
                    : [const Color(0xFF6366F1), const Color(0xFF38BDF8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isListening ? Colors.redAccent : const Color(0xFF6366F1))
                      .withValues(alpha: 0.45),
                  blurRadius: isListening ? 18 + (soundLevel * 18) : 16,
                  spreadRadius: isListening ? 3 + (soundLevel * 8) : 2,
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.mic : Icons.mic_none_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isListening
              ? 'Đang thu âm... Nhấn lại để dừng'
              : 'Nhấn vào Mic để ra lệnh giọng nói',
          style: TextStyle(
            fontSize: 12,
            color: isListening ? Colors.redAccent : Colors.white60,
            fontWeight: isListening ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

