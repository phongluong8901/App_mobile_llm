import 'dart:math';
import 'package:flutter/material.dart';

/// Dải hiển thị sóng âm Equalizer 60FPS khi người dùng đang nói vào Micro
class VoiceWaveBanner extends StatelessWidget {
  final AnimationController pulseAnimController;
  final double soundLevel;
  final VoidCallback onStop;

  const VoiceWaveBanner({
    super.key,
    required this.pulseAnimController,
    required this.soundLevel,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withValues(alpha: 0.22),
            const Color(0xFF6366F1).withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          // Chấm đỏ Recording nhấp nháy
          AnimatedBuilder(
            animation: pulseAnimController,
            builder: (context, _) {
              return Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(
                    alpha: 0.45 + (pulseAnimController.value * 0.55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Đang thu âm tiếng Việt... Hãy nói vào mic',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFECACA),
              ),
            ),
          ),
          // 7 cột sóng âm (Equalizer Bars) chuyển động mượt mà ở 60FPS
          AnimatedBuilder(
            animation: pulseAnimController,
            builder: (context, _) {
              return SizedBox(
                height: 26,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(7, (i) {
                    final waveFactor = sin(
                      (i * 0.85) + (pulseAnimController.value * pi * 2),
                    ).abs();
                    final barHeight = (6.0 +
                            (soundLevel * 18.0 * waveFactor) +
                            (pulseAnimController.value * 5.0))
                        .clamp(5.0, 26.0);
                    return Container(
                      width: 3.5,
                      height: barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? Colors.redAccent
                            : const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onStop,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Dừng',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

