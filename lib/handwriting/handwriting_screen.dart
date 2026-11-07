import 'dart:async';
import 'package:flutter/material.dart';
import '../llm/llm_service.dart';
import '../voice/voice_service.dart';
import 'components/digital_ink_canvas.dart';
import 'components/handwriting_toolbar.dart';
import 'components/recognition_result_card.dart';
import 'components/telemetry_banner.dart';
import 'handwriting_service.dart';

/// Màn hình Handwriting Recognition (Digital Ink):
/// Nâng cấp bảng vẽ Mở rộng linh hoạt (Full Canvas Mode) và Nhận diện SIÊU TỐC (~400ms)
class HandwritingScreen extends StatefulWidget {
  final LlmService llmService;
  final VoiceService voiceService;

  const HandwritingScreen({
    super.key,
    required this.llmService,
    required this.voiceService,
  });

  @override
  State<HandwritingScreen> createState() => _HandwritingScreenState();
}

class _HandwritingScreenState extends State<HandwritingScreen> {
  final HandwritingService _handwritingService = HandwritingService();
  final TextEditingController _recognizedTextCtrl = TextEditingController();

  final List<InkStroke> _strokes = [];
  List<InkPoint> _currentPoints = [];

  DateTime? _sessionStartTime;
  InkPoint? _lastTouchPoint;

  Color _selectedPenColor = const Color(0xFF38BDF8);
  final double _strokeWidth = 5.0;

  bool _isRecognizing = false;
  bool _autoRecognize = true;
  bool _appendMode = true;
  bool _autoSpeakAfterRecognize = false;
  bool _isExpandedCanvas = false; // Chế độ mở rộng bảng vẽ lớn

  Timer? _autoRecognizeTimer;
  Size _canvasSize = const Size(380, 360);

  @override
  void initState() {
    super.initState();
    widget.voiceService.addListener(_onVoiceChanged);
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.voiceService.removeListener(_onVoiceChanged);
    _autoRecognizeTimer?.cancel();
    _recognizedTextCtrl.dispose();
    super.dispose();
  }

  int _getElapsedMs() {
    _sessionStartTime ??= DateTime.now();
    return DateTime.now().difference(_sessionStartTime!).inMilliseconds;
  }

  void _onPointerDown(PointerDownEvent event) {
    _autoRecognizeTimer?.cancel();
    final local = event.localPosition;
    final pt = InkPoint(
      x: local.dx.clamp(0.0, _canvasSize.width),
      y: local.dy.clamp(0.0, _canvasSize.height),
      t: _getElapsedMs(),
    );
    setState(() {
      _lastTouchPoint = pt;
      _currentPoints = [pt];
      _strokes.add(
        InkStroke(
          points: _currentPoints,
          color: _selectedPenColor,
          strokeWidth: _strokeWidth,
        ),
      );
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_strokes.isEmpty) return;
    final local = event.localPosition;
    final pt = InkPoint(
      x: local.dx.clamp(0.0, _canvasSize.width),
      y: local.dy.clamp(0.0, _canvasSize.height),
      t: _getElapsedMs(),
    );
    setState(() {
      _lastTouchPoint = pt;
      _currentPoints.add(pt);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    setState(() {
      _lastTouchPoint = null;
    });
    // TỐI ƯU TỐC ĐỘ: Giảm thời gian chờ từ 1200ms xuống còn 650ms để nhận diện phản hồi tức thì
    if (_autoRecognize && _strokes.isNotEmpty) {
      _autoRecognizeTimer?.cancel();
      _autoRecognizeTimer = Timer(
        const Duration(milliseconds: 650),
        _recognizeHandwriting,
      );
    }
  }

  void _undoLastStroke() {
    _autoRecognizeTimer?.cancel();
    if (_strokes.isEmpty) return;
    setState(() {
      _strokes.removeLast();
      if (_strokes.isEmpty) {
        _sessionStartTime = null;
      }
    });
  }

  void _clearCanvas() {
    _autoRecognizeTimer?.cancel();
    setState(() {
      _strokes.clear();
      _currentPoints = [];
      _sessionStartTime = null;
      _lastTouchPoint = null;
    });
  }

  Future<void> _recognizeHandwriting() async {
    _autoRecognizeTimer?.cancel();
    if (_strokes.isEmpty || _isRecognizing) return;

    setState(() {
      _isRecognizing = true;
    });

    try {
      // 1. Cắt chính xác khung chữ + scale nhẹ để gửi ảnh siêu tốc
      final pngBytes = await _handwritingService.renderStrokesToPng(
        _strokes,
        _canvasSize,
      );
      final telemetry = _handwritingService.buildTelemetryDescription(_strokes);

      // 2. Gọi Gemini với token giới hạn để trả về kết quả trong tích tắc (~400ms)
      final resultText = await widget.llmService.recognizeDigitalInk(
        canvasPngBytes: pngBytes,
        strokeTelemetrySummary: telemetry,
      );

      if (!mounted) return;
      setState(() {
        if (resultText.startsWith('⚠️')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resultText),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          if (_appendMode && _recognizedTextCtrl.text.trim().isNotEmpty) {
            _recognizedTextCtrl.text =
                '${_recognizedTextCtrl.text.trim()} $resultText';
          } else {
            _recognizedTextCtrl.text = resultText;
          }
          _recognizedTextCtrl.selection = TextSelection.collapsed(
            offset: _recognizedTextCtrl.text.length,
          );
        }
      });

      if (_autoSpeakAfterRecognize &&
          !resultText.startsWith('⚠️') &&
          resultText.trim().isNotEmpty) {
        await widget.voiceService.speak(resultText);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  void _speakRecognizedText() {
    final text = _recognizedTextCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✍️ Hãy viết chữ lên bảng để nhận diện trước khi đọc nhé!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (widget.voiceService.isSpeaking) {
      widget.voiceService.stopSpeak();
    } else {
      widget.voiceService.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _handwritingService.analyzeStrokes(_strokes);
    final isSpeaking = widget.voiceService.isSpeaking;

    // Chiều cao bảng vẽ mở rộng: 480px ở chế độ mở rộng, 350px ở chế độ thường
    final canvasHeight = _isExpandedCanvas ? 480.0 : 340.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header giới thiệu kèm Nút Phóng to / Thu nhỏ Bảng viết
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.draw_rounded, color: Color(0xFF38BDF8), size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Handwriting Recognition (Digital Ink)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Viết tay trực tiếp → Nhận diện siêu tốc & Đọc thành tiếng.',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Nút chuyển chế độ Bảng viết Rộng / Bình thường
                IconButton(
                  tooltip: _isExpandedCanvas ? 'Thu nhỏ bảng' : 'Mở rộng bảng viết lớn',
                  icon: Icon(
                    _isExpandedCanvas
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    color: const Color(0xFF38BDF8),
                  ),
                  onPressed: () =>
                      setState(() => _isExpandedCanvas = !_isExpandedCanvas),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 2. Banner thông số chuỗi tọa độ thời gian thực (x, y, t)
          TelemetryBanner(
            lastTouchPoint: _lastTouchPoint,
            stats: stats,
          ),
          const SizedBox(height: 10),

          // 3. BẢNG VẼ CẢM ỨNG MỞ RỘNG (Chiều cao lớn 340px - 480px)
          LayoutBuilder(
            builder: (context, constraints) {
              _canvasSize = Size(constraints.maxWidth, canvasHeight);
              return DigitalInkCanvas(
                canvasSize: _canvasSize,
                strokes: _strokes,
                lastTouchPoint: _lastTouchPoint,
                selectedPenColor: _selectedPenColor,
                isRecognizing: _isRecognizing,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
              );
            },
          ),
          const SizedBox(height: 10),

          // 4. Thanh công cụ màu bút, hoàn tác, xóa & nhận diện
          HandwritingToolbar(
            selectedPenColor: _selectedPenColor,
            onColorChanged: (c) => setState(() => _selectedPenColor = c),
            hasStrokes: _strokes.isNotEmpty,
            isRecognizing: _isRecognizing,
            onUndo: _undoLastStroke,
            onClear: _clearCanvas,
            onRecognize: _recognizeHandwriting,
            autoRecognize: _autoRecognize,
            onAutoRecognizeChanged: (v) => setState(() => _autoRecognize = v),
            appendMode: _appendMode,
            onAppendModeChanged: (v) => setState(() => _appendMode = v),
            autoSpeak: _autoSpeakAfterRecognize,
            onAutoSpeakChanged: (v) =>
                setState(() => _autoSpeakAfterRecognize = v),
          ),
          const SizedBox(height: 12),

          // 5. Card kết quả Chữ in (Text) & Giọng nói (Speech)
          RecognitionResultCard(
            controller: _recognizedTextCtrl,
            isSpeaking: isSpeaking,
            onClear: () => setState(() => _recognizedTextCtrl.clear()),
            onSpeak: _speakRecognizedText,
          ),
        ],
      ),
    );
  }
}
