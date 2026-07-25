import 'package:flutter/material.dart';
import 'package:beatrice/data/models/message.dart';
import 'package:beatrice/ui/features/chat/widgets/message_bubble.dart';
import 'package:beatrice/ui/features/chat/widgets/chat_input.dart';
import 'package:beatrice/ui/features/chat/widgets/typing_indicator.dart';

class ChatScreen extends StatelessWidget {
  final List<Message> messages;
  final bool isLoading;
  final bool isThinking;
  final bool showImageSettings;
  final bool isRecording;
  final String? voiceStatus;
  final ValueChanged<String> onSend;
  final VoidCallback onMenuOpen;
  final VoidCallback onThinkingToggle;
  final VoidCallback onImageSettingsToggle;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onVoiceMode;
  final ScrollController scrollController;

  const ChatScreen({
    super.key,
    required this.messages,
    this.isLoading = false,
    this.isThinking = false,
    this.showImageSettings = false,
    this.isRecording = false,
    this.voiceStatus,
    required this.onSend,
    required this.onMenuOpen,
    required this.onThinkingToggle,
    required this.onImageSettingsToggle,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onVoiceMode,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
            itemCount: messages.length + (isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length && isLoading) {
                return const TypingIndicator();
              }
              final msg = messages[index];
              return MessageBubble(message: msg, isUser: msg.role == 'user');
            },
          ),
        ),
        ChatInput(
          isThinking: isThinking,
          showImageSettings: showImageSettings,
          isLoading: isLoading,
          isRecording: isRecording,
          voiceStatus: voiceStatus,
          onSend: onSend,
          onMenuOpen: onMenuOpen,
          onThinkingToggle: onThinkingToggle,
          onImageSettingsToggle: onImageSettingsToggle,
          onStartRecording: onStartRecording,
          onStopRecording: onStopRecording,
          onVoiceMode: onVoiceMode,
        ),
      ],
    );
  }
}
