import 'package:flutter/material.dart';
import '../voice/voice_service.dart';
import 'components/device_card.dart';
import 'components/voice_mic_button.dart';

/// Màn hình Nhận dạng giọng nói điều khiển thiết bị thông minh (Voice Smart Home)
class VoiceCommandScreen extends StatefulWidget {
  final VoiceService voiceService;

  const VoiceCommandScreen({super.key, required this.voiceService});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with SingleTickerProviderStateMixin {
  bool _isLightOn = false;
  double _lightBrightness = 1.0;
  bool _isFanOn = false;
  String _recognizedSpeech = 'Nhấn nút Mic bên dưới và nói "Bật đèn"...';
  String _actionStatus = 'Đang chờ khẩu lệnh giọng nói của bạn';
  final List<String> _commandLogs = [];

  String _lastProcessedWords = '';
  late AnimationController _fanController;

  @override
  void initState() {
    super.initState();
    _fanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.voiceService.addListener(_onVoiceServiceChanged);
  }

  void _onVoiceServiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.voiceService.removeListener(_onVoiceServiceChanged);
    _fanController.dispose();
    super.dispose();
  }

  void _processVoiceCommand(String rawText, {bool isManual = false}) {
    final cmd = rawText.toLowerCase().trim();
    if (cmd.isEmpty) return;

    if (!isManual && cmd == _lastProcessedWords) return;

    bool matched = false;
    String feedback = '';

    if (cmd.contains('tắt hết') ||
        cmd.contains('tắt tất cả') ||
        cmd.contains('đi ngủ') ||
        cmd.contains('chế độ ngủ')) {
      if (_isLightOn || _isFanOn || isManual) {
        _isLightOn = false;
        _isFanOn = false;
        _fanController.stop();
        matched = true;
        feedback = '🌙 Đã tắt toàn bộ đèn và quạt. Chúc bạn ngủ ngon!';
      }
    } else if (cmd.contains('bật hết') || cmd.contains('mở tất cả')) {
      if (!_isLightOn || !_isFanOn || isManual) {
        _isLightOn = true;
        _isFanOn = true;
        _fanController.repeat();
        matched = true;
        feedback = '✨ Đã bật cả đèn và quạt';
      }
    } else if (cmd.contains('bật đèn') ||
        cmd.contains('mở đèn') ||
        cmd.contains('sáng đèn') ||
        cmd.contains('bật điện') ||
        cmd.contains('mở điện')) {
      if (!_isLightOn || isManual) {
        _isLightOn = true;
        matched = true;
        feedback = '💡 Đã BẬT ĐÈN sáng rực rỡ!';
      }
    } else if (cmd.contains('tắt đèn') ||
        cmd.contains('tắt điện') ||
        cmd.contains('đóng đèn')) {
      if (_isLightOn || isManual) {
        _isLightOn = false;
        matched = true;
        feedback = '🌑 Đã TẮT ĐÈN tiết kiệm điện!';
      }
    } else if (cmd.contains('bật quạt') ||
        cmd.contains('mở quạt') ||
        cmd.contains('quay quạt')) {
      if (!_isFanOn || isManual) {
        _isFanOn = true;
        _fanController.repeat();
        matched = true;
        feedback = '🌀 Đã BẬT QUẠT làm mát!';
      }
    } else if (cmd.contains('tắt quạt') || cmd.contains('dừng quạt')) {
      if (_isFanOn || isManual) {
        _isFanOn = false;
        _fanController.stop();
        matched = true;
        feedback = '⏹️ Đã TẮT QUẠT!';
      }
    }

    if (matched) {
      _lastProcessedWords = cmd;
      final timeStr = TimeOfDay.now().format(context);
      setState(() {
        _actionStatus = feedback;
        _commandLogs.insert(0, '[$timeStr] 🗣️ "$rawText" → $feedback');
        if (_commandLogs.length > 6) _commandLogs.removeLast();
      });
      widget.voiceService.speak(
        feedback.replaceAll(RegExp(r'[💡🌑🌀⏹️🌙✨!]'), ''),
      );
    }
  }

  Future<void> _toggleVoiceCommandMic() async {
    if (widget.voiceService.isListening) {
      await widget.voiceService.stopListening();
    } else {
      _lastProcessedWords = '';
      setState(() {
        _recognizedSpeech = '🎙️ Đang lắng nghe... Hãy nói "Bật đèn" hoặc "Tắt đèn"';
      });
      final started = await widget.voiceService.startListening(
        onResult: (words, isFinal) {
          if (!mounted) return;
          setState(() {
            _recognizedSpeech = words;
          });
          _processVoiceCommand(words);
        },
      );
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Không thể mở Microphone. Hãy kiểm tra quyền ghi âm của ứng dụng!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isListening = widget.voiceService.isListening;
    final soundLevel = widget.voiceService.soundLevel;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Thẻ giới thiệu Voice Smart Home
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.record_voice_over_rounded, color: Color(0xFF38BDF8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Điều khiển Nhà thông minh bằng Giọng nói',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Nhận dạng giọng nói tiếng Việt thời gian thực và phân tích ý định (Intent). Nói "Bật đèn", bóng đèn sẽ phát sáng rực rỡ!',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Khu vực thiết bị thông minh (Đèn & Quạt)
        Row(
          children: [
            Expanded(
              child: DeviceCard(
                title: _isLightOn ? 'ĐÈN ĐANG SÁNG' : 'ĐÈN ĐANG TẮT',
                subtitle: _isLightOn
                    ? 'Độ sáng: ${(_lightBrightness * 100).round()}%'
                    : 'Nói "Bật đèn" hoặc chạm',
                isOn: _isLightOn,
                icon: _isLightOn
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded,
                activeColor: Colors.amberAccent,
                activeBgColor: const Color(0xFF422006),
                onTap: () => _processVoiceCommand(
                  _isLightOn ? 'Tắt đèn' : 'Bật đèn',
                  isManual: true,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DeviceCard(
                title: _isFanOn ? 'QUẠT ĐANG QUAY' : 'QUẠT ĐANG TẮT',
                subtitle: _isFanOn ? 'Gió mát tự nhiên' : 'Nói "Bật quạt" hoặc chạm',
                isOn: _isFanOn,
                icon: Icons.mode_fan_off_rounded,
                activeColor: Colors.cyanAccent,
                activeBgColor: const Color(0xFF083344),
                iconWidget: RotationTransition(
                  turns: _fanController,
                  child: Icon(
                    Icons.mode_fan_off_rounded,
                    size: 62,
                    color: _isFanOn ? Colors.cyanAccent : Colors.white38,
                  ),
                ),
                onTap: () => _processVoiceCommand(
                  _isFanOn ? 'Tắt quạt' : 'Bật quạt',
                  isManual: true,
                ),
              ),
            ),
          ],
        ),

        // Thanh trượt Dimmer độ sáng đèn
        if (_isLightOn) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.brightness_medium_rounded,
                  color: Colors.amberAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Độ sáng đèn:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Slider(
                    value: _lightBrightness,
                    min: 0.2,
                    max: 1.0,
                    activeColor: Colors.amberAccent,
                    onChanged: (val) => setState(() => _lightBrightness = val),
                  ),
                ),
                Text(
                  '${(_lightBrightness * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        // 3. Khung nhận diện giọng nói & Nút Mic lớn
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isListening ? Colors.redAccent : const Color(0xFF334155),
              width: isListening ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                _actionStatus,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🗣️ Văn bản nhận diện: "$_recognizedSpeech"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              VoiceMicButton(
                isListening: isListening,
                soundLevel: soundLevel,
                onTap: _toggleVoiceCommandMic,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Các nút khẩu lệnh nhanh
        const Text(
          '⚡ Hoặc chạm thử nhanh các khẩu lệnh mẫu:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickCommandChip('💡 "Bật đèn"', 'Bật đèn'),
            _buildQuickCommandChip('🌑 "Tắt đèn"', 'Tắt đèn'),
            _buildQuickCommandChip('🌀 "Bật quạt"', 'Bật quạt'),
            _buildQuickCommandChip('⏹️ "Tắt quạt"', 'Tắt quạt'),
            _buildQuickCommandChip('🌙 "Chế độ ngủ"', 'Chế độ ngủ'),
            _buildQuickCommandChip('✨ "Bật tất cả"', 'Bật hết'),
          ],
        ),

        // 5. Nhật ký lệnh
        if (_commandLogs.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📜 Nhật ký khẩu lệnh gần đây:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _commandLogs.clear()),
                child: const Text(
                  'Xóa nhật ký',
                  style: TextStyle(fontSize: 11.5, color: Colors.white54),
                ),
              ),
            ],
          ),
          ..._commandLogs.map(
            (log) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Text(
                log,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickCommandChip(String label, String commandText) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      backgroundColor: const Color(0xFF1E293B),
      side: const BorderSide(color: Color(0xFF334155)),
      onPressed: () {
        setState(() {
          _recognizedSpeech = commandText;
        });
        _processVoiceCommand(commandText, isManual: true);
      },
    );
  }
}
