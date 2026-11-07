import 'package:flutter/material.dart';

/// Card điều khiển thiết bị thông minh (Đèn phát sáng / Quạt quay)
class DeviceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isOn;
  final IconData icon;
  final Color activeColor;
  final Color activeBgColor;
  final Widget? iconWidget;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isOn,
    required this.icon,
    required this.activeColor,
    required this.activeBgColor,
    this.iconWidget,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        decoration: BoxDecoration(
          color: isOn ? activeBgColor : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isOn ? activeColor : const Color(0xFF334155),
            width: isOn ? 2.2 : 1.0,
          ),
          boxShadow: isOn
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 3,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 380),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn
                    ? activeColor.withValues(alpha: 0.22)
                    : Colors.black26,
              ),
              child: iconWidget ??
                  Icon(
                    icon,
                    size: 62,
                    color: isOn ? activeColor : Colors.white38,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: isOn ? activeColor : Colors.white60,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

