import 'package:flutter/material.dart';

import 'chat/chat_screen.dart';
import 'handwriting/handwriting_screen.dart';
import 'llm/llm_service.dart';
import 'rag/rag_screen.dart';
import 'rag/rag_service.dart';
import 'safety/safety_service.dart';
import 'settings/settings_screen.dart';
import 'voice/voice_service.dart';
import 'voice_chat/voice_chat_screen.dart';
import 'voice_command/voice_command_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final llmService = LlmService();
  await llmService.loadFromEnv();
  runApp(MyApp(llmService: llmService));
}

class MyApp extends StatelessWidget {
  final LlmService llmService;

  const MyApp({super.key, required this.llmService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Gemini AI Studio • Multimodal Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF38BDF8),
          surface: const Color(0xFF1E293B),
        ),
      ),
      home: MainTabsScreen(llmService: llmService),
    );
  }
}

class MainTabsScreen extends StatefulWidget {
  final LlmService llmService;

  const MainTabsScreen({super.key, required this.llmService});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  late final LlmService _llmService = widget.llmService;
  final VoiceService _voiceService = VoiceService();
  final RagService _ragService = RagService();
  final SafetyService _safetyService = SafetyService();

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _voiceService.initializeSpeech();
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  void _navigateToSettings() {
    setState(() => _selectedIndex = 5); // Chuyển sang Tab Cài đặt (index 5)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.psychology_alt_rounded, color: Color(0xFF38BDF8)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Google Gemini AI Studio',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Model: ${_llmService.modelName} • Voice • Digital Ink',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cài đặt Giọng nói & Gemini API',
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      // Sử dụng IndexedStack để giữ nguyên trạng thái tất cả các Tab khi chuyển đổi
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Tab 0: Chat LLM
          ChatScreen(
            llmService: _llmService,
            voiceService: _voiceService,
            ragService: _ragService,
            safetyService: _safetyService,
            onOpenSettings: _navigateToSettings,
          ),

          // Tab 1: Đàm thoại Giọng nói 2 chiều liên tục (Voice-to-Voice Mode)
          VoiceChatScreen(
            llmService: _llmService,
            voiceService: _voiceService,
            ragService: _ragService,
          ),

          // Tab 2: Điều khiển thiết bị (Bật đèn / Quạt)
          VoiceCommandScreen(voiceService: _voiceService),

          // Tab 3: Viết tay Digital Ink (x, y, t)
          HandwritingScreen(
            llmService: _llmService,
            voiceService: _voiceService,
          ),

          // Tab 4: Kho Tri Thức Local RAG
          RagScreen(ragService: _ragService),

          // Tab 5: Cài đặt Giọng nói & Model Gemini
          SettingsScreen(
            llmService: _llmService,
            voiceService: _voiceService,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1E293B),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) {
          if (_selectedIndex != idx && _voiceService.isListening) {
            _voiceService.stopListening();
          }
          if (_selectedIndex != idx && _voiceService.isSpeaking) {
            _voiceService.stopSpeak();
          }
          setState(() => _selectedIndex = idx);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat LLM',
          ),
          NavigationDestination(
            icon: Icon(Icons.record_voice_over_outlined),
            selectedIcon: Icon(Icons.record_voice_over_rounded),
            label: 'Đàm thoại',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline_rounded),
            selectedIcon: Icon(Icons.lightbulb_rounded),
            label: 'Smart Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.draw_outlined),
            selectedIcon: Icon(Icons.draw_rounded),
            label: 'Viết tay',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books_rounded),
            label: 'Kho RAG',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
