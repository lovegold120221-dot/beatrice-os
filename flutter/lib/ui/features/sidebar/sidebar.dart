import 'package:flutter/material.dart';
import 'package:beatrice/ui/core/theme.dart';

class Sidebar extends StatelessWidget {
  final List<Map<String, dynamic>> chatHistory;
  final String? currentChatId;
  final Future<void> Function() onNewChat;
  final void Function(String) onLoadChat;
  final void Function(String) onDeleteChat;
  final VoidCallback onClose;
  final VoidCallback? onAccount;
  final VoidCallback? onSettings;
  final VoidCallback? onMobileUseAgent;
  final VoidCallback? onSignOut;

  const Sidebar({
    super.key,
    required this.chatHistory,
    this.currentChatId,
    required this.onNewChat,
    required this.onLoadChat,
    required this.onDeleteChat,
    required this.onClose,
    this.onAccount,
    this.onSettings,
    this.onMobileUseAgent,
    this.onSignOut,
  });

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      color: AppColors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset('logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Beatrice OS',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    child: const Icon(
                      Icons.close,
                      size: 24,
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
            ),
            // New Chat
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onNewChat(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            // History
            Expanded(
              child: chatHistory.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'No chat history yet',
                            style: TextStyle(
                              color: AppColors.neutral500,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: chatHistory.length,
                      itemBuilder: (context, index) {
                        final chat = chatHistory[index];
                        final chatId = chat['id'] as String;
                        final title = chat['title'] as String? ?? '';
                        final createdAt = chat['created_at'] as String? ?? '';
                        final isSelected = chatId == currentChatId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Material(
                            color: isSelected
                                ? AppColors.chip2121
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onLoadChat(chatId),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? AppColors.white
                                                  : AppColors.neutral400,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (createdAt.isNotEmpty)
                                            Text(
                                              _formatDate(createdAt),
                                              style: const TextStyle(
                                                color: AppColors.neutral600,
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => onDeleteChat(chatId),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.delete_outline,
                                          size: 14,
                                          color: AppColors.neutral400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                children: [
                  _menuItem(Icons.person_outline, 'Account', onAccount),
                  const SizedBox(height: 4),
                  _menuItem(Icons.settings_outlined, 'Settings', onSettings),
                  const SizedBox(height: 4),
                  _menuItem(
                    Icons.phone_android,
                    'Beatrice setup',
                    onMobileUseAgent,
                  ),
                  const SizedBox(height: 4),
                  _menuItem(
                    Icons.logout,
                    'Sign Out',
                    onSignOut,
                    color: AppColors.red400,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.neutral300),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color ?? AppColors.neutral300,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
