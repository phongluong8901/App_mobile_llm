import 'package:flutter/material.dart';
import '../llm/llm_service.dart';
import '../rag/rag_service.dart';
import '../safety/safety_service.dart';
import '../voice/voice_service.dart';
import 'components/chat_bubble.dart';
import 'components/chat_header.dart';
import 'components/chat_input_bar.dart';
import 'components/voice_wave_banner.dart';
import 'models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  final LlmService llmService;
  final VoiceService voiceService;
  final RagService ragService;
  final SafetyService safetyService;
  final VoidCallback onOpenSettings;

  const ChatScreen({
    super.key,
    required this.llmService,
    required this.voiceService,
    required this.ragService,
    required this.safetyService,
    required this.onOpenSettings,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late List<ChatMessage> _messages;
  bool _isStreaming = false;
  late AnimationController _pulseAnimController;

  List<String> _smartReplies = [
    'Mật khẩu Wifi tầng 2 là gì?',
    'Lịch bảo dưỡng máy lạnh khi nào?',
    'Local RAG hoạt động thế nào?',
  ];

  @override
  void initState() {
    super.initState();
    _initWelcomeMessage();
    _pulseAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    widget.voiceService.addListener(_onVoiceServiceChanged);
  }

  void _initWelcomeMessage() {
    _messages = [
      ChatMessage(
        text:
            'Xin chào! 👋 Mình là Trợ lý AI Google Gemini (${widget.llmService.modelName}) tích hợp Local RAG.\n\n'
            '• 🔇 Mặc định mình sẽ **không tự động phát tiếng** khi trả lời.\n'
            '• 🔊 Khi nào bạn muốn nghe giọng đọc, hãy bấm vào nút **Đọc to** dưới tin nhắn nhé!',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }

  void _onVoiceServiceChanged() {
    if (!mounted) return;
    if (widget.voiceService.isListening) {
      if (!_pulseAnimController.isAnimating) {
        _pulseAnimController.repeat(reverse: true);
      }
    } else {
      if (_pulseAnimController.isAnimating) {
        _pulseAnimController.stop();
        _pulseAnimController.reset();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.voiceService.removeListener(_onVoiceServiceChanged);
    _pulseAnimController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (widget.voiceService.isListening) {
      await widget.voiceService.stopListening();
    } else {
      final started = await widget.voiceService.startListening(
        onResult: (words, isFinal) {
          if (!mounted) return;
          setState(() {
            _controller.text = words;
            _controller.selection = TextSelection.collapsed(
              offset: _controller.text.length,
            );
          });
        },
      );
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Không thể bật Microphone. Hãy cấp quyền ghi âm cho ứng dụng nhé!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _clearChat() {
    widget.llmService.clearHistory();
    widget.voiceService.stopSpeak();
    setState(() {
      _initWelcomeMessage();
      _smartReplies = [
        'Mật khẩu Wifi tầng 2 là gì?',
        'Lịch bảo dưỡng máy lạnh khi nào?',
        'Local RAG hoạt động thế nào?',
      ];
    });
  }

  Future<void> _sendMessage([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _isStreaming) return;

    if (widget.voiceService.isListening) {
      await widget.voiceService.stopListening();
    }

    _controller.clear();

    final safetyCheck = widget.safetyService.analyzeSafety(text);
    final ragResults = widget.ragService.searchRelevantDocs(text);

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
          safetyAlert: safetyCheck.isSafe ? null : safetyCheck,
        ),
      );
      _isStreaming = true;
      _messages.add(
        ChatMessage(
          text: '',
          isUser: false,
          timestamp: DateTime.now(),
          citations: ragResults,
        ),
      );
    });
    _scrollToBottom();

    String accumulated = '';
    final aiIndex = _messages.length - 1;

    final stream = widget.llmService.askLlmStream(
      query: text,
      retrievedDocs: ragResults,
    );

    await for (final chunk in stream) {
      accumulated += chunk;
      if (!mounted) return;
      setState(() {
        _messages[aiIndex] = ChatMessage(
          text: accumulated,
          isUser: false,
          timestamp: _messages[aiIndex].timestamp,
          citations: ragResults,
        );
      });
      _scrollToBottom();
    }

    if (!mounted) return;
    setState(() {
      _isStreaming = false;
      _smartReplies = widget.safetyService.generateSmartReplies(accumulated);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.voiceService.isListening;
    final soundLevel = widget.voiceService.soundLevel;

    return Column(
      children: [
        // 1. Header Model & Bảo mật
        ChatHeader(
          llmService: widget.llmService,
          voiceService: widget.voiceService,
          isStreaming: _isStreaming,
          onClearChat: _clearChat,
          onOpenSettings: widget.onOpenSettings,
        ),

        // 2. Danh sách tin nhắn
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return ChatBubble(
                message: msg,
                onSpeak: () => widget.voiceService.speak(msg.text),
              );
            },
          ),
        ),

        // 3. Smart Reply Chips
        if (_smartReplies.isNotEmpty && !_isStreaming && !isListening)
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _smartReplies.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final reply = _smartReplies[idx];
                return ActionChip(
                  avatar: const Icon(
                    Icons.bolt_rounded,
                    size: 15,
                    color: Color(0xFF38BDF8),
                  ),
                  label: Text(reply, style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFF1E293B),
                  side: BorderSide(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  ),
                  onPressed: () => _sendMessage(reply),
                );
              },
            ),
          ),

        const SizedBox(height: 6),

        // 4. Banner hiệu ứng sóng âm 60FPS khi người dùng đang nói
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: isListening
              ? VoiceWaveBanner(
                  pulseAnimController: _pulseAnimController,
                  soundLevel: soundLevel,
                  onStop: _toggleMic,
                )
              : const SizedBox.shrink(),
        ),

        // 5. Thanh nhập tin nhắn + Mic
        ChatInputBar(
          controller: _controller,
          isListening: isListening,
          soundLevel: soundLevel,
          isStreaming: _isStreaming,
          pulseAnimController: _pulseAnimController,
          onToggleMic: _toggleMic,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}
