import 'package:flutter/material.dart';

enum AppMode { ai, normal, online }

extension AppModeLabel on AppMode {
  String get label => this == AppMode.ai ? 'AI Mode' : 'Normal Mode';
}

Future<AppMode?> showModeSelectionDialog(BuildContext context) {
  return showDialog<AppMode>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'How would you like to proceed?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeOption(
            icon: Icons.auto_awesome,
            title: 'AI Mode',
            subtitle: 'Get AI assistance during inspections',
            color: Colors.deepPurple,
            onTap: () => Navigator.pop(ctx, AppMode.ai),
          ),
          const SizedBox(height: 12),
          _ModeOption(
            icon: Icons.assignment_outlined,
            title: 'Normal Mode',
            subtitle: 'Fill inspections manually',
            color: Colors.blue,
            onTap: () => Navigator.pop(ctx, AppMode.normal),
          ),
        ],
      ),
    ),
  );
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.06),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}