import 'package:flutter/material.dart';
import 'package:beatrice/ui/core/theme.dart';

class AttachmentTaskStarter {
  final String label;
  final String prompt;

  const AttachmentTaskStarter({required this.label, required this.prompt});
}

class AttachmentSheet extends StatelessWidget {
  static const taskStarters = <AttachmentTaskStarter>[
    AttachmentTaskStarter(
      label: 'Watch J-Learnout',
      prompt:
          'Go to YouTube, search for a video from J-Learnout, and watch it for 20 seconds.',
    ),
    AttachmentTaskStarter(
      label: 'Draft in Gmail',
      prompt:
          'Open Gmail and prepare a new email draft. Ask me for any missing recipient, subject, or message details.',
    ),
    AttachmentTaskStarter(
      label: 'Search the web',
      prompt: 'Open the browser and search the web for the topic I specify.',
    ),
    AttachmentTaskStarter(
      label: 'Open Settings',
      prompt: 'Open Android Settings and wait for my next instruction.',
    ),
    AttachmentTaskStarter(
      label: 'Prepare message',
      prompt:
          'Open the messaging app and prepare a message draft. Ask me for the recipient and message, but do not send it.',
    ),
  ];

  final VoidCallback onCamera;
  final VoidCallback onPhotos;
  final VoidCallback onFiles;
  final VoidCallback onCreateImage;
  final bool webLookupEnabled;
  final VoidCallback onToggleWebLookup;
  final bool visionImageReady;
  final VoidCallback onVisionImage;
  final bool ocrReady;
  final bool ocrSelected;
  final VoidCallback onOcrDocument;
  final VoidCallback onStudy;
  final VoidCallback onAgentMode;
  final ValueChanged<String> onTaskStarter;
  final VoidCallback onClose;

  const AttachmentSheet({
    super.key,
    required this.onCamera,
    required this.onPhotos,
    required this.onFiles,
    required this.onCreateImage,
    required this.webLookupEnabled,
    required this.onToggleWebLookup,
    required this.visionImageReady,
    required this.onVisionImage,
    required this.ocrReady,
    required this.ocrSelected,
    required this.onOcrDocument,
    required this.onStudy,
    required this.onAgentMode,
    required this.onTaskStarter,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.78,
      decoration: const BoxDecoration(
        color: AppColors.card1a,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add to Beatrice',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: AppColors.neutral400),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _actionItem(Icons.camera_alt, 'Camera', onCamera),
                        _actionItem(Icons.image, 'Photos', onPhotos),
                        _actionItem(Icons.description, 'Files', onFiles),
                      ],
                    ),
                    const Divider(color: Color(0xFF333333), height: 28),
                    const Text(
                      'Task starters',
                      style: TextStyle(
                        color: AppColors.neutral300,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: taskStarters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final starter = taskStarters[index];
                          return ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(starter.label),
                            onPressed: () => onTaskStarter(starter.prompt),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Color(0xFF333333), height: 28),
                    const Text(
                      'Chat tools',
                      style: TextStyle(
                        color: AppColors.neutral300,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: const Icon(
                          Icons.public,
                          color: AppColors.white,
                        ),
                        title: const Text(
                          'Web lookup',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Allow a user-triggered online lookup for this Chat turn',
                          style: TextStyle(
                            color: AppColors.neutral400,
                            fontSize: 12,
                          ),
                        ),
                        value: webLookupEnabled,
                        onChanged: (_) => onToggleWebLookup(),
                      ),
                    ),
                    _listItem(
                      Icons.image_search_outlined,
                      visionImageReady ? 'Vision image ready' : 'Vision image',
                      'Choose an image for a compatible Ollama vision model',
                      onVisionImage,
                    ),
                    _listItem(
                      Icons.document_scanner_outlined,
                      ocrReady
                          ? (ocrSelected ? 'OCR document ready' : 'Local OCR')
                          : 'Set up local OCR',
                      'Private on-device Tesseract text extraction',
                      onOcrDocument,
                    ),
                    const Divider(color: Color(0xFF333333), height: 24),
                    _listItem(
                      Icons.brush,
                      'Create image',
                      'Visualize anything',
                      onCreateImage,
                    ),
                    _listItem(
                      Icons.menu_book,
                      'Study and learn',
                      'Learn a new concept',
                      onStudy,
                    ),
                    _listItem(
                      Icons.smart_toy,
                      'Agent mode',
                      'Get work done for you',
                      onAgentMode,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.hover2f,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.white, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.neutral400, fontSize: 13),
        ),
        onTap: onTap,
      ),
    );
  }
}
