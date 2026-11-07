import 'package:flutter/material.dart';

/// Thanh công cụ: Chọn màu mực, Undo, Xóa bảng, Nút Nhận diện AI và các Chip tùy chọn
class HandwritingToolbar extends StatelessWidget {
  final Color selectedPenColor;
  final ValueChanged<Color> onColorChanged;
  final bool hasStrokes;
  final bool isRecognizing;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onRecognize;

  final bool autoRecognize;
  final ValueChanged<bool> onAutoRecognizeChanged;
  final bool appendMode;
  final ValueChanged<bool> onAppendModeChanged;
  final bool autoSpeak;
  final ValueChanged<bool> onAutoSpeakChanged;

  const HandwritingToolbar({
    super.key,
    required this.selectedPenColor,
    required this.onColorChanged,
    required this.hasStrokes,
    required this.isRecognizing,
    required this.onUndo,
    required this.onClear,
    required this.onRecognize,
    required this.autoRecognize,
    required this.onAutoRecognizeChanged,
    required this.appendMode,
    required this.onAppendModeChanged,
    required this.autoSpeak,
    required this.onAutoSpeakChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Bảng màu bút
            ...[
              const Color(0xFF38BDF8),
              Colors.amberAccent,
              const Color(0xFF34D399),
              const Color(0xFFF472B6),
            ].map((color) {
              final isSelected = selectedPenColor == color;
              return GestureDetector(
                onTap: () => onColorChanged(color),
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                ),
              );
            }),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: 'Hoàn tác nét vừa viết',
              onPressed: hasStrokes ? onUndo : null,
              icon: const Icon(Icons.undo_rounded, size: 19),
            ),
            const SizedBox(width: 6),
            IconButton.filledTonal(
              tooltip: 'Xóa sạch bảng viết',
              onPressed: hasStrokes ? onClear : null,
              icon: const Icon(
                Icons.layers_clear_rounded,
                size: 19,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: (!hasStrokes || isRecognizing) ? null : onRecognize,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text(
                'Nhận diện chữ',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilterChip(
              selected: autoRecognize,
              label: const Text(
                'Tự nhận diện khi ngừng tay',
                style: TextStyle(fontSize: 11.5),
              ),
              onSelected: onAutoRecognizeChanged,
            ),
            FilterChip(
              selected: appendMode,
              label: const Text(
                'Ghi nối tiếp thành câu',
                style: TextStyle(fontSize: 11.5),
              ),
              onSelected: onAppendModeChanged,
            ),
            FilterChip(
              selected: autoSpeak,
              label: const Text(
                'Tự động đọc khi nhận diện xong',
                style: TextStyle(fontSize: 11.5),
              ),
              onSelected: onAutoSpeakChanged,
            ),
          ],
        ),
      ],
    );
  }
}

