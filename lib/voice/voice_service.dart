import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Cấu hình giọng đọc TTS
class VoiceSettings {
  double speechRate; // 0.7x -> 1.5x (Mặc định 1.0)
  double pitch; // 0.7x -> 1.4x (Mặc định 1.0)
  String voicePreset; // 'nu_tre_trung', 'nu_am_ap', 'nam_tram', 'nam_chuan'

  VoiceSettings({
    this.speechRate = 1.0,
    this.pitch = 1.0,
    this.voicePreset = 'nu_am_ap',
  });

  void applyPreset(String preset) {
    voicePreset = preset;
    switch (preset) {
      case 'nu_tre_trung':
        pitch = 1.22;
        speechRate = 1.05;
        break;
      case 'nu_am_ap':
        pitch = 1.0;
        speechRate = 1.0;
        break;
      case 'nam_tram':
        pitch = 0.76;
        speechRate = 0.95;
        break;
      case 'nam_chuan':
        pitch = 0.88;
        speechRate = 1.0;
        break;
    }
  }
}

/// Service quản lý Nhận diện giọng nói (STT) và Đọc văn bản (Offline Native TTS)
/// Kế thừa ChangeNotifier để đồng bộ trạng thái Mic & Sóng âm mượt mà giữa các Tab
class VoiceService extends ChangeNotifier {
  static const MethodChannel _ttsChannel =
      MethodChannel('com.example.llm_app/tts');

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool isSpeechInitialized = false;
  bool isListening = false;
  bool isSpeaking = false;

  final VoiceSettings settings = VoiceSettings();

  /// Callback khi TTS hoàn tất câu đọc (hỗ trợ chế độ Voice-to-Voice liên tục)
  VoidCallback? onTtsFinished;

  /// Mức âm lượng thực tế từ microphone (-2.0 đến 10.0), chuẩn hóa 0.0 -> 1.0
  double soundLevel = 0.0;

  /// Lưu lỗi gần nhất (nếu có) để hiển thị gợi ý thân thiện
  String? lastError;

  VoiceService() {
    _initChannelHandler();
  }

  void _initChannelHandler() {
    _ttsChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onTtsStart':
          isSpeaking = true;
          notifyListeners();
          break;
        case 'onTtsDone':
        case 'onTtsError':
          isSpeaking = false;
          notifyListeners();
          onTtsFinished?.call();
          break;
      }
    });
  }

  /// Khởi tạo Speech-to-Text
  Future<bool> initializeSpeech({
    Function(String status)? onStatus,
    Function(String error)? onError,
  }) async {
    if (isSpeechInitialized) return true;
    try {
      isSpeechInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            isListening = false;
            soundLevel = 0.0;
          } else if (status == 'listening') {
            isListening = true;
          }
          notifyListeners();
          onStatus?.call(status);
        },
        onError: (errorNotification) {
          isListening = false;
          soundLevel = 0.0;
          lastError = errorNotification.errorMsg;
          notifyListeners();
          onError?.call(errorNotification.errorMsg);
        },
      );
      notifyListeners();
      return isSpeechInitialized;
    } catch (e) {
      debugPrint('Speech init error: $e');
      lastError = e.toString();
      isSpeechInitialized = false;
      notifyListeners();
      return false;
    }
  }

  /// Bắt đầu nghe giọng nói tiếng Việt (tự động khởi tạo nếu chưa init)
  Future<bool> startListening({
    required Function(String recognizedWords, bool isFinal) onResult,
    Function(double normalizedLevel)? onSoundLevel,
  }) async {
    lastError = null;
    if (!isSpeechInitialized) {
      final ok = await initializeSpeech();
      if (!ok) return false;
    }

    // Dừng TTS nếu đang đọc để tránh thu âm tiếng của chính điện thoại
    if (isSpeaking) {
      await stopSpeak();
    }

    // Nếu đang nghe ở phiên trước thì dừng lại trước khi mở phiên mới
    if (_speech.isListening) {
      await _speech.stop();
    }

    isListening = true;
    soundLevel = 0.15;
    notifyListeners();

    try {
      await _speech.listen(
        localeId: 'vi_VN',
        listenFor: const Duration(seconds: 40),
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
          if (result.finalResult) {
            isListening = false;
            soundLevel = 0.0;
            notifyListeners();
          }
        },
        onSoundLevelChange: (level) {
          final normalized = ((level + 2.0) / 12.0).clamp(0.05, 1.0);
          soundLevel = normalized;
          notifyListeners();
          onSoundLevel?.call(normalized);
        },
      );
      return true;
    } catch (e) {
      debugPrint('Start listening error: $e');
      isListening = false;
      soundLevel = 0.0;
      lastError = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Dừng nghe
  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Stop listening error: $e');
    } finally {
      isListening = false;
      soundLevel = 0.0;
      notifyListeners();
    }
  }

  /// Đọc văn bản bằng Android Native Offline TextToSpeech với pitch và speechRate đã cấu hình
  Future<void> speak(String text, {VoidCallback? onComplete}) async {
    if (text.trim().isEmpty) return;
    try {
      isSpeaking = true;
      notifyListeners();
      if (onComplete != null) {
        onTtsFinished = onComplete;
      }
      final cleanText = text
          .replaceAll(RegExp(r'[*#_`~>]'), '')
          .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'), r'$1')
          .trim();
      await _ttsChannel.invokeMethod('speak', {
        'text': cleanText,
        'rate': settings.speechRate,
        'pitch': settings.pitch,
        'utteranceId': 'utt_${DateTime.now().millisecondsSinceEpoch}',
      });
    } catch (e) {
      debugPrint('TTS Error: $e');
      isSpeaking = false;
      notifyListeners();
      onComplete?.call();
    }
  }

  /// Dừng đọc ngay lập tức
  Future<void> stopSpeak() async {
    try {
      await _ttsChannel.invokeMethod('stop');
    } catch (e) {
      debugPrint('TTS Stop Error: $e');
    } finally {
      isSpeaking = false;
      onTtsFinished = null;
      notifyListeners();
    }
  }

  /// Cập nhật cấu hình giọng đọc
  void updateVoiceConfig({
    double? speechRate,
    double? pitch,
    String? preset,
  }) {
    if (preset != null) {
      settings.applyPreset(preset);
    }
    if (speechRate != null) {
      settings.speechRate = speechRate;
    }
    if (pitch != null) {
      settings.pitch = pitch;
    }
    notifyListeners();
  }
}
