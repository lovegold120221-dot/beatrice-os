import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beatrice/data/services/mobile_use_service.dart';
import 'package:beatrice/data/services/ollama_service.dart';
import 'package:beatrice/ui/core/theme.dart';
import 'mobile_use_server_card.dart';

class MobileUseSetupScreen extends StatefulWidget {
  final OllamaService ollamaService;
  final String selectedModel;
  final ValueChanged<String> onModelChanged;
  final String ollamaProvider;
  final String plannerProvider;
  final ValueChanged<String> onPlannerProviderChanged;
  final String geminiApiKey;
  final String groqApiKey;
  final String geminiModel;
  final String groqModel;
  final HostedPlannerSettingsSaved onHostedPlannerSettingsSaved;

  const MobileUseSetupScreen({
    super.key,
    required this.ollamaService,
    required this.selectedModel,
    required this.onModelChanged,
    required this.ollamaProvider,
    required this.plannerProvider,
    required this.onPlannerProviderChanged,
    required this.geminiApiKey,
    required this.groqApiKey,
    required this.geminiModel,
    required this.groqModel,
    required this.onHostedPlannerSettingsSaved,
  });

  @override
  State<MobileUseSetupScreen> createState() => _MobileUseSetupScreenState();
}

class _MobileUseSetupScreenState extends State<MobileUseSetupScreen>
    with WidgetsBindingObserver {
  final MobileUseService _service = MobileUseService();
  MobileUseStatus? _status;
  String? _message;
  String? _requesting;

  static const _capabilities = [
    (
      key: 'microphone',
      title: 'Microphone',
      impact: 'Lets Beatrice hear voice requests while you use voice mode.',
      icon: Icons.mic_outlined,
    ),
    (
      key: 'notifications',
      title: 'Notifications',
      impact: 'Lets Beatrice show runtime and task-status notifications.',
      icon: Icons.notifications_outlined,
    ),
    (
      key: 'contacts',
      title: 'Contacts',
      impact:
          'Allows future confirmed tasks to look up a recipient you name. '
          'It does not send anything.',
      icon: Icons.contacts_outlined,
    ),
    (
      key: 'phone',
      title: 'Phone',
      impact:
          'Allows a separately confirmed call action. Granting it never '
          'places a call by itself.',
      icon: Icons.phone_outlined,
    ),
    (
      key: 'sms',
      title: 'SMS',
      impact:
          'Allows future confirmed SMS reading/sending. Every send remains '
          'confirmation-gated.',
      icon: Icons.sms_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await _service.getStatus();
      if (mounted) setState(() => _status = status);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _message = error.message ?? error.code);
    }
  }

  Future<void> _request(String key) async {
    setState(() {
      _requesting = key;
      _message = null;
    });
    try {
      final granted = await _service.requestOptionalPermission(key);
      await _refresh();
      if (mounted) {
        setState(
          () => _message = granted
              ? 'Android granted this optional capability.'
              : 'Not granted. Beatrice remains usable without it.',
        );
      }
    } on PlatformException catch (error) {
      if (mounted) setState(() => _message = error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _requesting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Set up only the capabilities you choose. Selecting the internal '
          'MobileUseAgent model does not enable phone control.',
          style: TextStyle(color: AppColors.neutral300, fontSize: 13),
        ),
        const SizedBox(height: 12),
        MobileUseServerCard(
          ollamaService: widget.ollamaService,
          selectedModel: widget.selectedModel,
          onModelChanged: widget.onModelChanged,
          ollamaProvider: widget.ollamaProvider,
          plannerProvider: widget.plannerProvider,
          onPlannerProviderChanged: widget.onPlannerProviderChanged,
          geminiApiKey: widget.geminiApiKey,
          groqApiKey: widget.groqApiKey,
          geminiModel: widget.geminiModel,
          groqModel: widget.groqModel,
          onHostedPlannerSettingsSaved: widget.onHostedPlannerSettingsSaved,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.chip2121,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional app permissions',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap Allow individually to show Android’s standard prompt. '
                'Denied permissions do not block chat, configured planning, or '
                'other granted capabilities.',
                style: TextStyle(color: AppColors.neutral400, fontSize: 11),
              ),
              const SizedBox(height: 8),
              for (final capability in _capabilities)
                _permissionRow(
                  capability.key,
                  capability.title,
                  capability.impact,
                  capability.icon,
                ),
              if (_message != null) ...[
                const SizedBox(height: 6),
                Text(
                  _message!,
                  style: const TextStyle(
                    color: AppColors.neutral300,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _permissionRow(
    String key,
    String title,
    String impact,
    IconData icon,
  ) {
    final granted = _status?.optionalPermissions[key] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: granted ? AppColors.emerald : AppColors.neutral400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title · ${granted ? 'Granted' : 'Not granted'}',
                  style: const TextStyle(
                    color: AppColors.neutral200,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  impact,
                  style: const TextStyle(
                    color: AppColors.neutral500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (!granted)
            TextButton(
              onPressed: _requesting == null ? () => _request(key) : null,
              child: Text(_requesting == key ? 'Waiting…' : 'Allow'),
            ),
        ],
      ),
    );
  }
}
