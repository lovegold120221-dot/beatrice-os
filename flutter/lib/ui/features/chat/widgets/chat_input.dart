import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final bool isThinking;
  final bool showImageSettings;
  final bool isLoading;
  final bool isRecording;
  final String? voiceStatus;
  final ValueChanged<String> onSend;
  final VoidCallback onMenuOpen;
  final VoidCallback onThinkingToggle;
  final VoidCallback onImageSettingsToggle;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onVoiceMode;

  const ChatInput({
    super.key,
    this.isThinking = false,
    this.showImageSettings = false,
    this.isLoading = false,
    this.isRecording = false,
    this.voiceStatus,
    required this.onSend,
    required this.onMenuOpen,
    required this.onThinkingToggle,
    required this.onImageSettingsToggle,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onVoiceMode,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSend(text);
      _controller.clear();
      setState(() => _hasText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.voiceStatus != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.voiceStatus!,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _iconButton(Icons.add, widget.onMenuOpen),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF212121),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      _iconButton(
                        Icons.brush,
                        widget.onImageSettingsToggle,
                        color: widget.showImageSettings ? Colors.purple : null,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          onChanged: (v) =>
                              setState(() => _hasText = v.isNotEmpty),
                          maxLines: 3,
                          minLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Ask Beatrice AI',
                            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 34,
                width: 34,
                child: _hasText
                    ? FloatingActionButton.small(
                        onPressed: _send,
                        backgroundColor: Colors.white,
                        child: const Icon(
                          Icons.arrow_upward,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        children: [
                          GestureDetector(
                            onTapDown: (_) => widget.onStartRecording(),
                            onTapUp: (_) => widget.onStopRecording(),
                            child: Icon(
                              widget.isRecording ? Icons.stop : Icons.mic,
                              size: 20,
                              color: widget.isRecording
                                  ? Colors.red
                                  : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: widget.onVoiceMode,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.wifi_tethering,
                                size: 18,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: color ?? Colors.grey[300]),
      ),
    );
  }
}
