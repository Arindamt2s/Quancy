import 'package:flutter/material.dart';
import 'package:quincy/Dashboard/ViewModel/VoiceAssistantViewModel.dart';

class AIGuidePanel extends StatelessWidget {
  final VoiceAssistantViewModel vm;

  const AIGuidePanel({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final status = vm.isSpeaking
            ? 'Speaking…'
            : vm.isListening
                ? 'Listening…'
                : 'Tap the mic to talk';

        return Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: avatar + name + close
                Row(
                  children: [
                    _Avatar(active: vm.isSpeaking || vm.isListening),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Guide',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: vm.isListening
                                  ? Colors.red
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Hide AI Guide',
                      onPressed: vm.closePanel,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Guide's speech bubble
                if (vm.botMessage.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(right: 40),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Text(
                        vm.botMessage,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),

                // What the user said
                if (vm.userText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(left: 40, right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Text(
                        vm.userText,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Mic button
                GestureDetector(
                  onTap: vm.isListening ? vm.stopListening : vm.startListening,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: vm.isListening ? Colors.red : Colors.blue,
                      boxShadow: [
                        BoxShadow(
                          color: (vm.isListening ? Colors.red : Colors.blue)
                              .withOpacity(0.4),
                          blurRadius: vm.isListening ? 18 : 8,
                          spreadRadius: vm.isListening ? 4 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      vm.isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool active;
  const _Avatar({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? Colors.blue : Colors.grey.shade300,
          width: 2.5,
        ),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.blue.shade100,
        child: ClipOval(
          child: Image.asset(
            'assets/images/ai_guide.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Icon(
              Icons.support_agent,
              size: 30,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ),
    );
  }
}