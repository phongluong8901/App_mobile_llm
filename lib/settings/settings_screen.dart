import 'package:flutter/material.dart';
import '../llm/llm_service.dart';
import '../voice/voice_service.dart';

/// Tab Cài đặt (Settings): Cấu hình giọng đọc (Nam/Nữ, Tốc độ, Tone/Pitch),
/// và quản lý Mô hình Google Gemini LLM, API Key, Temperature
class SettingsScreen extends StatefulWidget {
  final LlmService llmService;
  final VoiceService voiceService;

  const SettingsScreen({
    super.key,
    required this.llmService,
    required this.voiceService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _customModelCtrl;
  bool _obscureKey = true;
  bool _isTestingKey = false;
  String? _testResultMsg;

  final List<String> _popularModels = [
    'gemini-3.5-flash',
    'gemini-2.5-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController(text: widget.llmService.rawApiKey);
    _customModelCtrl =
        TextEditingController(text: widget.llmService.modelName);
    widget.voiceService.addListener(_onVoiceChanged);
    widget.llmService.addListener(_onLlmChanged);
  }

  void _onVoiceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onLlmChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.voiceService.removeListener(_onVoiceChanged);
    widget.llmService.removeListener(_onLlmChanged);
    _apiKeyCtrl.dispose();
    _customModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _testApiConnection() async {
    setState(() {
      _isTestingKey = true;
      _testResultMsg = null;
    });

    final ok = await widget.llmService.testConnection();

    if (!mounted) return;
    setState(() {
      _isTestingKey = false;
      _testResultMsg = ok
          ? '✅ Kết nối thành công tới Gemini API!'
          : '❌ Không thể kết nối. Kiểm tra lại API Key hoặc mạng.';
    });
  }

  void _saveLlmConfig() {
    final newKey = _apiKeyCtrl.text.trim();
    final newModel = _customModelCtrl.text.trim();
    widget.llmService.updateConfig(
      apiKey: newKey.isEmpty ? null : newKey,
      modelName: newModel.isEmpty ? null : newModel,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('💾 Đã lưu cấu hình Google Gemini thành công!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _testVoiceSpeech() {
    widget.voiceService.speak(
      'Xin chào! Đây là giọng đọc mẫu tiếng Việt sau khi bạn điều chỉnh tốc độ và cao độ.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final vSettings = widget.voiceService.settings;
    final isSpeaking = widget.voiceService.isSpeaking;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ==========================================
        // PHẦN 1: CẤU HÌNH GIỌNG NÓI (TTS)
        // ==========================================
        _buildSectionHeader(
          icon: Icons.record_voice_over_rounded,
          title: 'Cấu hình Giọng nói & Phát âm (TTS)',
          subtitle: 'Tùy chỉnh chất giọng Nam / Nữ, tốc độ đọc và cao độ (tone)',
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎭 Chọn mẫu giọng đọc sẵn (Presets):',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildVoicePresetChip(
                    label: '👩 Nữ ấm áp (Chuẩn)',
                    presetKey: 'nu_am_ap',
                    currentPreset: vSettings.voicePreset,
                  ),
                  _buildVoicePresetChip(
                    label: '👧 Nữ trẻ trung (Cao)',
                    presetKey: 'nu_tre_trung',
                    currentPreset: vSettings.voicePreset,
                  ),
                  _buildVoicePresetChip(
                    label: '👨 Nam trầm ấm',
                    presetKey: 'nam_tram',
                    currentPreset: vSettings.voicePreset,
                  ),
                  _buildVoicePresetChip(
                    label: '🧑 Nam thanh niên',
                    presetKey: 'nam_chuan',
                    currentPreset: vSettings.voicePreset,
                  ),
                ],
              ),
              const Divider(height: 28, color: Color(0xFF334155)),

              // Tốc độ đọc (Speech Rate)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '⚡ Tốc độ đọc (Speech Rate):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${vSettings.speechRate.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: vSettings.speechRate,
                min: 0.7,
                max: 1.5,
                divisions: 16,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) {
                  widget.voiceService.updateVoiceConfig(speechRate: val);
                },
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.7x (Chậm)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  Text('1.0x (Chuẩn)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  Text('1.5x (Nhanh)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),

              const SizedBox(height: 16),

              // Cao độ giọng (Pitch / Tone)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🎵 Cao độ giọng (Tone / Pitch):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${vSettings.pitch.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.amberAccent,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: vSettings.pitch,
                min: 0.65,
                max: 1.45,
                divisions: 16,
                activeColor: Colors.amberAccent,
                onChanged: (val) {
                  widget.voiceService.updateVoiceConfig(pitch: val);
                },
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.65 (Trầm ấm)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  Text('1.0 (Tự nhiên)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                  Text('1.45 (Trong trẻo)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                ],
              ),

              const SizedBox(height: 18),

              // Nút Nghe thử giọng đọc
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isSpeaking
                      ? () => widget.voiceService.stopSpeak()
                      : _testVoiceSpeech,
                  icon: Icon(
                    isSpeaking
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_rounded,
                    color: const Color(0xFF38BDF8),
                  ),
                  label: Text(
                    isSpeaking ? 'Dừng phát âm' : '🔊 Nghe thử giọng đọc ngay',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ==========================================
        // PHẦN 2: CẤU HÌNH GOOGLE GEMINI API & MODEL
        // ==========================================
        _buildSectionHeader(
          icon: Icons.psychology_alt_rounded,
          title: 'Cấu hình Google Gemini LLM & API Key',
          subtitle: 'Chọn model xử lý, quản lý khóa API và độ sáng tạo (temperature)',
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🤖 Chọn Model Gemini:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _popularModels.map((m) {
                  final isSelected = widget.llmService.modelName == m;
                  return ChoiceChip(
                    label: Text(
                      m,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: const Color(0xFF0F172A),
                    onSelected: (selected) {
                      if (selected) {
                        _customModelCtrl.text = m;
                        widget.llmService.updateConfig(modelName: m);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customModelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên model tùy chỉnh',
                  hintText: 'VD: gemini-3.5-flash',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),

              const SizedBox(height: 16),

              // Quản lý API Key
              const Text(
                '🔑 Google Gemini API Key:',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  labelText: 'Khóa API Key',
                  hintText: 'AIzaSy...',
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Trạng thái: ${widget.llmService.maskedApiKey}',
                style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
              ),

              const SizedBox(height: 16),

              // Độ sáng tạo Temperature
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🎯 Độ sáng tạo (Temperature):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    widget.llmService.temperature.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF818CF8),
                    ),
                  ),
                ],
              ),
              Slider(
                value: widget.llmService.temperature,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                activeColor: const Color(0xFF6366F1),
                onChanged: (val) {
                  widget.llmService.updateConfig(temperature: val);
                },
              ),

              if (_testResultMsg != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _testResultMsg!,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTestingKey ? null : _testApiConnection,
                      icon: _isTestingKey
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: const Text('Kiểm tra kết nối'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                      ),
                      onPressed: _saveLlmConfig,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Lưu cấu hình'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Thông tin ứng dụng
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📱 Google Gemini AI Studio • Multimodal Suite',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                'Phiên bản 2.0 • Hỗ trợ Chat LLM, Smart Home, Digital Ink (x,y,t), Voice-to-Voice liên tục và Local RAG Vector Store.',
                style: TextStyle(fontSize: 11.5, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF818CF8), size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Colors.white60),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoicePresetChip({
    required String label,
    required String presetKey,
    required String currentPreset,
  }) {
    final isSelected = presetKey == currentPreset;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0284C7),
      backgroundColor: const Color(0xFF0F172A),
      onSelected: (selected) {
        if (selected) {
          widget.voiceService.updateVoiceConfig(preset: presetKey);
        }
      },
    );
  }
}

