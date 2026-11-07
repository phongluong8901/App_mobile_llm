import 'package:flutter/material.dart';
import '../handwriting_service.dart';

/// Banner hiển thị thông số chuỗi tọa độ thời gian thực (x, y, t) và Freeman Chain Code
class TelemetryBanner extends StatelessWidget {
  final InkPoint? lastTouchPoint;
  final DigitalInkStats stats;

  const TelemetryBanner({
    super.key,
    required this.lastTouchPoint,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline_rounded,
                size: 15,
                color: Color(0xFF38BDF8),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  lastTouchPoint != null
                      ? 'Đang viết: (x: ${lastTouchPoint!.x.toStringAsFixed(0)}, y: ${lastTouchPoint!.y.toStringAsFixed(0)}, t: ${lastTouchPoint!.t}ms)'
                      : 'Chuỗi (x, y, t): ${stats.strokeCount} nét • ${stats.pointCount} điểm • Δt = ${stats.durationMs}ms • v = ${stats.avgSpeedPxPerMs.toStringAsFixed(2)} px/ms',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (stats.pointCount > 0) ...[
            const SizedBox(height: 3),
            Text(
              'Vector hướng nét (Freeman Chain): ${stats.directionChain}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

