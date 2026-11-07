import 'package:flutter/material.dart';
import '../handwriting_service.dart';

/// Bảng vẽ cảm ứng Digital Ink Canvas ghi nhận chuỗi điểm (x, y, t)
class DigitalInkCanvas extends StatelessWidget {
  final Size canvasSize;
  final List<InkStroke> strokes;
  final InkPoint? lastTouchPoint;
  final Color selectedPenColor;
  final bool isRecognizing;
  final void Function(PointerDownEvent) onPointerDown;
  final void Function(PointerMoveEvent) onPointerMove;
  final void Function(PointerUpEvent) onPointerUp;

  const DigitalInkCanvas({
    super.key,
    required this.canvasSize,
    required this.strokes,
    required this.lastTouchPoint,
    required this.selectedPenColor,
    required this.isRecognizing,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: canvasSize.width,
      height: canvasSize.height,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: lastTouchPoint != null
              ? selectedPenColor
              : const Color(0xFF334155),
          width: lastTouchPoint != null ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: [
            // Chặn cuộn dọc khi đang vẽ
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) {},
              onPanUpdate: (_) {},
              onPanEnd: (_) {},
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: onPointerDown,
                onPointerMove: onPointerMove,
                onPointerUp: onPointerUp,
                child: CustomPaint(
                  size: canvasSize,
                  painter: _DigitalInkPainter(
                    strokes: strokes,
                    activeTouch: lastTouchPoint,
                  ),
                ),
              ),
            ),

            // Hướng dẫn chìm khi bảng trống
            if (strokes.isEmpty)
              const IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.gesture_rounded,
                        size: 42,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Dùng ngón tay viết chữ vào đây...\n(VD: "Xin chào", "Việt Nam", "123")',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Trạng thái đang nhận diện AI
            if (isRecognizing)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Đang nhận diện nét vẽ...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DigitalInkPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final InkPoint? activeTouch;

  _DigitalInkPainter({
    required this.strokes,
    required this.activeTouch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Lưới ô ly mờ & Baseline
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.85)
      ..strokeWidth = 1.0;

    const double step = 34.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final baselineY = size.height * 0.68;
    final baselinePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.28)
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(16, baselineY),
      Offset(size.width - 16, baselineY),
      baselinePaint,
    );

    // 2. Nét vẽ Quadratic Bézier + Glow
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final glowPaint = Paint()
        ..color = stroke.color.withValues(alpha: 0.28)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth + 5.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

      final penPaint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth;

      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        canvas.drawCircle(p.offset, stroke.strokeWidth / 2, penPaint);
        continue;
      }

      final path = Path()..moveTo(stroke.points.first.x, stroke.points.first.y);
      for (int i = 1; i < stroke.points.length - 1; i++) {
        final p0 = stroke.points[i];
        final p1 = stroke.points[i + 1];
        final midX = (p0.x + p1.x) / 2;
        final midY = (p0.y + p1.y) / 2;
        path.quadraticBezierTo(p0.x, p0.y, midX, midY);
      }
      path.lineTo(stroke.points.last.x, stroke.points.last.y);

      canvas.drawPath(path, glowPaint);
      canvas.drawPath(path, penPaint);
    }

    // 3. Điểm chạm hiện tại
    if (activeTouch != null) {
      canvas.drawCircle(
        activeTouch!.offset,
        9.0,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
      canvas.drawCircle(
        activeTouch!.offset,
        4.0,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DigitalInkPainter oldDelegate) => true;
}

