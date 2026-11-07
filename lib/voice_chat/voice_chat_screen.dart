import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../llm/llm_service.dart';
import '../rag/rag_service.dart';
import '../voice/voice_service.dart';

enum VoiceCallState {
  idle, // Chưa bắt đầu cuộc trò chuyện
  listening, // Đang nghe người dùng nói tiếng Việt
  thinking, // Gemini đang xử lý suy nghĩ
  speaking, // AI đang đọc câu trả lời bằng giọng nói
}

class VoiceTurn {
  final String speaker; // 'user' hoặc 'ai'
  final String text;
  final DateTime time;

  VoiceTurn({required this.speaker, required this.text, required this.time});
}

/// Màn hình Chế độ Đàm thoại Giọng nói 2 chiều liên tục (Voice-to-Voice Mode)
/// Trải nghiệm tương tự ChatGPT Voice Mode / Gemini Live:
/// Người dùng nói → AI suy nghĩ → AI nói lại → Tự động mở mic nói tiếp rảnh tay 100%!
class VoiceChatScreen extends StatefulWidget {
  final LlmService llmService;
  final VoiceService voiceService;
  final RagService ragService;

  const VoiceChatScreen({
    super.key,
    required this.llmService,
    required this.voiceService,
    required this.ragService,
  });

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  VoiceCallState _callState = VoiceCallState.idle;
  String _currentTranscript = '';
  String _lastAiResponse = '';
  final List<VoiceTurn> _history = [];

  bool _isCallActive = false;
  bool _showTranscript = false;
  Timer? _silenceTimer;

  late AnimationController _orbAnimController;
  late AnimationController _waveAnimController;

  @override
  void initState() {
    super.initState();
    _orbAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();

    widget.voiceService.addListener(_onVoiceServiceStateChanged);
  }

  void _onVoiceServiceStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _orbAnimController.dispose();
    _waveAnimController.dispose();
    widget.voiceService.removeListener(_onVoiceServiceStateChanged);
    super.dispose();
  }

  /// Bắt đầu hoặc kết thúc phiên đàm thoại rảnh tay
  Future<void> _toggleCall() async {
    if (_isCallActive) {
      await _endCall();
    } else {
      await _startCall();
    }
  }

  Future<void> _startCall() async {
    setState(() {
      _isCallActive = true;
      _callState = VoiceCallState.listening;
      _currentTranscript = '';
      _lastAiResponse = '';
    });
    await _startListeningLoop();
  }

  Future<void> _endCall() async {
    _silenceTimer?.cancel();
    await widget.voiceService.stopListening();
    await widget.voiceService.stopSpeak();
    if (mounted) {
      setState(() {
        _isCallActive = false;
        _callState = VoiceCallState.idle;
        _currentTranscript = '';
      });
    }
  }

  /// Vòng lặp lắng nghe giọng nói
  Future<void> _startListeningLoop() async {
    if (!_isCallActive || !mounted) return;

    setState(() {
      _callState = VoiceCallState.listening;
      _currentTranscript = '';
    });

    final success = await widget.voiceService.startListening(
      onResult: (words, isFinal) {
        if (!mounted || !_isCallActive) return;
        setState(() {
          _currentTranscript = words;
        });

        // Hẹn giờ khi người dùng ngừng nói 1.4s thì tự động gửi câu hỏi đến AI
        _silenceTimer?.cancel();
        if (words.trim().isNotEmpty) {
          _silenceTimer = Timer(const Duration(milliseconds: 1400), () {
            if (_isCallActive && _callState == VoiceCallState.listening) {
              _processUserQuestion(words);
            }
          });
        }
      },
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Không thể kích hoạt Mic. Hãy kiểm tra quyền ghi âm!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _endCall();
    }
  }

  /// Gửi câu hỏi đến Gemini và nhận câu trả lời dạng đàm thoại
  Future<void> _processUserQuestion(String question) async {
    _silenceTimer?.cancel();
    await widget.voiceService.stopListening();

    if (!mounted || !_isCallActive) return;

    final trimmed = question.trim();
    if (trimmed.isEmpty) {
      _startListeningLoop();
      return;
    }

    setState(() {
      _callState = VoiceCallState.thinking;
      _history.insert(
        0,
        VoiceTurn(speaker: 'user', text: trimmed, time: DateTime.now()),
      );
    });

    final ragDocs = widget.ragService.searchRelevantDocs(trimmed, topK: 1);
    final reply = await widget.llmService.askLlmVoiceConversation(
      query: trimmed,
      retrievedDocs: ragDocs,
    );

    if (!mounted || !_isCallActive) return;

    setState(() {
      _callState = VoiceCallState.speaking;
      _lastAiResponse = reply;
      _history.insert(
        0,
        VoiceTurn(speaker: 'ai', text: reply, time: DateTime.now()),
      );
    });

    // Phát âm câu trả lời qua TTS -> Khi đọc xong tự động mở lại mic nói tiếp
    await widget.voiceService.speak(
      reply,
      onComplete: () {
        if (mounted && _isCallActive) {
          _startListeningLoop();
        }
      },
    );
  }

  /// Ngắt lời AI ngay lập tức khi người dùng muốn nói chèn ngang
  Future<void> _interruptAi() async {
    if (_callState == VoiceCallState.speaking) {
      await widget.voiceService.stopSpeak();
      if (_isCallActive) {
        _startListeningLoop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final soundLevel = widget.voiceService.soundLevel;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Thanh trạng thái trên cùng
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _isCallActive
                          ? Colors.green.withValues(alpha: 0.18)
                          : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isCallActive
                            ? Colors.greenAccent
                            : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCallActive
                                ? Colors.greenAccent
                                : Colors.white38,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isCallActive ? 'Đang đàm thoại trực tiếp' : 'Sẵn sàng',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isCallActive
                                ? Colors.greenAccent
                                : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Xem nhật ký văn bản',
                    icon: Icon(
                      _showTranscript
                          ? Icons.chat_bubble_rounded
                          : Icons.chat_bubble_outline_rounded,
                      color: _showTranscript
                          ? const Color(0xFF38BDF8)
                          : Colors.white70,
                    ),
                    onPressed: () =>
                        setState(() => _showTranscript = !_showTranscript),
                  ),
                ],
              ),
            ),

            // Khu vực trung tâm: Hiển thị Quả Cầu Giọng Nói (Animated Voice Orb)
            Expanded(
              child: _showTranscript
                  ? _buildTranscriptView()
                  : _buildVoiceOrbView(soundLevel),
            ),

            // Dòng văn bản trạng thái phản hồi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  Text(
                    _getStatusTitle(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getStatusSubtitle(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Colors.white70,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Thanh điều khiển dưới cùng (Nút Kết nối / Ngắt đàm thoại + Ngắt lời)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Nút ngắt lời AI khi AI đang đọc
                  if (_callState == VoiceCallState.speaking)
                    IconButton.filledTonal(
                      tooltip: 'Ngắt lời AI để nói luôn',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.amber.withValues(alpha: 0.25),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: _interruptAi,
                      icon: const Icon(
                        Icons.front_hand_rounded,
                        color: Colors.amberAccent,
                        size: 26,
                      ),
                    )
                  else
                    const SizedBox(width: 58),

                  // Nút Bắt đầu / Kết thúc cuộc gọi đàm thoại (Lớn)
                  GestureDetector(
                    onTap: _toggleCall,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isCallActive
                              ? [Colors.redAccent, Colors.red.shade700]
                              : [
                                  const Color(0xFF6366F1),
                                  const Color(0xFF0284C7),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isCallActive
                                    ? Colors.redAccent
                                    : const Color(0xFF6366F1))
                                .withValues(alpha: 0.5),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isCallActive
                            ? Icons.call_end_rounded
                            : Icons.mic_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Nút chuyển nhanh khi nói xong (nếu không muốn đợi timer 1.4s)
                  if (_callState == VoiceCallState.listening &&
                      _currentTranscript.isNotEmpty)
                    IconButton.filledTonal(
                      tooltip: 'Gửi câu hỏi ngay',
                      style: IconButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF38BDF8).withValues(alpha: 0.25),
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: () => _processUserQuestion(_currentTranscript),
                      icon: const Icon(
                        Icons.check_rounded,
                        color: Color(0xFF38BDF8),
                        size: 26,
                      ),
                    )
                  else
                    const SizedBox(width: 58),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quả cầu giọng nói biến đổi hình thái theo trạng thái (Listening/Thinking/Speaking)
  Widget _buildVoiceOrbView(double soundLevel) {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge([_orbAnimController, _waveAnimController]),
        builder: (context, _) {
          final scalePulse = 1.0 + (_orbAnimController.value * 0.12);
          final soundExpand = (_callState == VoiceCallState.listening)
              ? (soundLevel * 35.0)
              : 0.0;
          final orbSize = (140.0 * scalePulse + soundExpand).clamp(120.0, 240.0);

          return GestureDetector(
            onTap: () {
              if (_callState == VoiceCallState.speaking) {
                _interruptAi();
              } else if (!_isCallActive) {
                _startCall();
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vòng sóng lan tỏa bên ngoài (Ripple Waves)
                if (_callState == VoiceCallState.listening ||
                    _callState == VoiceCallState.speaking)
                  Container(
                    width: orbSize + 60,
                    height: orbSize + 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _getStatusColor().withValues(
                          alpha: (0.35 - _orbAnimController.value * 0.25)
                              .clamp(0.05, 0.4),
                        ),
                        width: 2.5,
                      ),
                    ),
                  ),

                // Quả cầu phát sáng chính
                Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: _getOrbGradientColors(),
                      stops: const [0.2, 0.75, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getStatusColor().withValues(alpha: 0.55),
                        blurRadius: 40 + (soundLevel * 20),
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      _getOrbCenterIcon(),
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTranscriptView() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: _history.isEmpty
          ? const Center(
              child: Text(
                'Chưa có cuộc trò chuyện nào.\nNhấn nút Mic để bắt đầu nói!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              reverse: true,
              itemCount: _history.length,
              itemBuilder: (context, idx) {
                final item = _history[idx];
                final isUser = item.speaker == 'user';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUser
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUser ? '🗣️ Bạn:' : '🤖 Gemini Voice:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isUser
                              ? const Color(0xFF818CF8)
                              : const Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.text,
                        style: const TextStyle(fontSize: 13.5, color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _getStatusTitle() {
    switch (_callState) {
      case VoiceCallState.idle:
        return 'Chạm nút để Bắt đầu Nói';
      case VoiceCallState.listening:
        return 'Đang lắng nghe bạn nói...';
      case VoiceCallState.thinking:
        return 'Gemini đang suy nghĩ...';
      case VoiceCallState.speaking:
        return 'Gemini đang trả lời...';
    }
  }

  String _getStatusSubtitle() {
    switch (_callState) {
      case VoiceCallState.idle:
        return 'Đàm thoại 2 chiều liên tục bằng tiếng Việt. Sau khi AI đọc xong, mic sẽ tự động mở lại rảnh tay.';
      case VoiceCallState.listening:
        return _currentTranscript.isEmpty
            ? 'Hãy nói câu hỏi của bạn vào micro...'
            : '"$_currentTranscript"';
      case VoiceCallState.thinking:
        return 'Đang tra cứu tri thức và tạo câu trả lời tự nhiên...';
      case VoiceCallState.speaking:
        return _lastAiResponse.isEmpty
            ? 'Đang phát âm qua loa...'
            : '🔊 "$_lastAiResponse" (Chạm vào quả cầu để ngắt lời)';
    }
  }

  Color _getStatusColor() {
    switch (_callState) {
      case VoiceCallState.idle:
        return const Color(0xFF38BDF8);
      case VoiceCallState.listening:
        return const Color(0xFF38BDF8);
      case VoiceCallState.thinking:
        return const Color(0xFFA855F7);
      case VoiceCallState.speaking:
        return const Color(0xFF34D399);
    }
  }

  List<Color> _getOrbGradientColors() {
    switch (_callState) {
      case VoiceCallState.idle:
        return [
          const Color(0xFF38BDF8),
          const Color(0xFF6366F1),
          const Color(0xFF0F172A),
        ];
      case VoiceCallState.listening:
        return [
          Colors.cyanAccent,
          const Color(0xFF0284C7),
          const Color(0xFF0F172A),
        ];
      case VoiceCallState.thinking:
        return [
          const Color(0xFFE879F9),
          const Color(0xFF9333EA),
          const Color(0xFF0F172A),
        ];
      case VoiceCallState.speaking:
        return [
          const Color(0xFF6EE7B7),
          const Color(0xFF059669),
          const Color(0xFF0F172A),
        ];
    }
  }

  IconData _getOrbCenterIcon() {
    switch (_callState) {
      case VoiceCallState.idle:
        return Icons.play_arrow_rounded;
      case VoiceCallState.listening:
        return Icons.mic_rounded;
      case VoiceCallState.thinking:
        return Icons.psychology_rounded;
      case VoiceCallState.speaking:
        return Icons.volume_up_rounded;
    }
  }
}

