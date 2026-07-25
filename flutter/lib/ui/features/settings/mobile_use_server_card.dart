import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beatrice/data/services/mobile_use_service.dart';
import 'package:beatrice/data/services/mobile_use_agent_runtime.dart';
import 'package:beatrice/data/services/mobile_planner_provider.dart';
import 'package:beatrice/data/services/ollama_service.dart';
import 'package:beatrice/ui/core/theme.dart';

class MobileUseServerCard extends StatefulWidget {
  final OllamaService ollamaService;
  final String selectedModel;
  final ValueChanged<String> onModelChanged;
  final String ollamaProvider;
  final String plannerProvider;
  final ValueChanged<String> onPlannerProviderChanged;

  const MobileUseServerCard({
    super.key,
    required this.ollamaService,
    required this.selectedModel,
    required this.onModelChanged,
    required this.ollamaProvider,
    required this.plannerProvider,
    required this.onPlannerProviderChanged,
  });

  @override
  State<MobileUseServerCard> createState() => _MobileUseServerCardState();
}

class _MobileUseServerCardState extends State<MobileUseServerCard>
    with WidgetsBindingObserver {
  final MobileUseService _service = MobileUseService();
  final MobileUseAgentRuntime _planner = MobileUseAgentRuntime.instance;
  MobileUseStatus? _status;
  bool _busy = false;
  String? _message;
  List<String> _ollamaModels = const [];
  String _ollamaStatus = 'Not checked';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _discoverOllama();
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

  @override
  void didUpdateWidget(covariant MobileUseServerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plannerProvider != widget.plannerProvider &&
        MobilePlannerProviders.byId(widget.plannerProvider).isIntegrated) {
      _discoverOllama();
    }
  }

  Future<void> _refresh() async {
    try {
      final status = await _service.getStatus();
      if (mounted) setState(() => _status = status);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _message = error.message);
    }
  }

  Future<void> _discoverOllama() async {
    if (!MobilePlannerProviders.byId(widget.plannerProvider).isIntegrated) {
      if (mounted) {
        setState(
          () => _ollamaStatus =
              'This provider needs an authenticated planner adapter.',
        );
      }
      return;
    }
    if (mounted) setState(() => _ollamaStatus = 'Checking local Ollama…');
    final discovery = await widget.ollamaService.discoverModels();
    if (!mounted) return;
    if (discovery.endpoint != null) {
      widget.ollamaService.configure(baseUrl: discovery.endpoint);
    }
    setState(() {
      _ollamaModels = discovery.models;
      _ollamaStatus = discovery.status;
    });
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      await _refresh();
      if (mounted) setState(() => _message = success);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _message = error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _explainAndOpenAccessibility() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable phone interaction?'),
        content: const Text(
          'Android Accessibility lets MobileUseAgent read semantic controls '
          'shown in other apps and perform taps, text entry, gestures, Back, '
          'and Home only while you run a task.\n\n'
          'It does not grant screen recording, contacts, SMS, calls, shell, '
          'or unrestricted app access. Beatrice is excluded from observation. '
          'You can turn the service off in Android Settings at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Android Settings'),
          ),
        ],
      ),
    );
    if (accepted == true) await _service.openAccessibilitySettings();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final running = status?.runtimeRunning ?? false;
    final accessibility = status?.accessibilityEnabled ?? false;
    final plannerProvider = MobilePlannerProviders.byId(widget.plannerProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.chip2121,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.phone_android, size: 18, color: AppColors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Beatrice mobile service',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Consent-first v1',
                style: TextStyle(color: AppColors.neutral500, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _statusRow(
            'Automation runtime',
            running ? 'Ready' : 'Stopped',
            running,
          ),
          if (running)
            _statusRow(
              'Current task',
              status?.runtimeTaskDetail ?? 'No task is running',
              status?.runtimeTaskState == 'active',
            ),
          _statusRow(
            'Accessibility',
            accessibility ? 'Enabled by Android' : 'Not enabled',
            accessibility,
          ),
          _statusRow(
            'Semantic screen visibility',
            status?.accessibilityConnected == true
                ? 'Active while service is on'
                : 'Off',
            status?.accessibilityConnected == true,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface0a,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accessibility
                    ? AppColors.emerald.withValues(alpha: 0.6)
                    : AppColors.neutral500,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Android Accessibility setup',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  accessibility
                      ? 'Android reports Beatrice mobile control is enabled. '
                            'You can review or turn it off in Android Settings.'
                      : 'Required only for user-approved screen reading, taps, '
                            'text entry, gestures, Back, and Home. Android must '
                            'grant it; Beatrice cannot enable it silently.',
                  style: const TextStyle(
                    color: AppColors.neutral400,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _explainAndOpenAccessibility,
                    icon: const Icon(Icons.accessibility_new, size: 17),
                    label: Text(
                      accessibility
                          ? 'Review Accessibility in Android Settings'
                          : 'Set up Accessibility in Android Settings',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _run(
                          _refresh,
                          'Checked the current Android-granted status.',
                        ),
                  child: const Text('I returned — check status'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Task mode → selected MobileUseAgent planner\n'
            'Chat mode → ordinary configured chat model\n'
            'Beatrice Live (online) → concise task → same selected planner\n'
            'A dispatched task may continue while the app is minimized through '
            'the visible Beatrice foreground-service notification. Stop is '
            'available from that notification. Voice listening itself does '
            'not continue in the background. Android process termination '
            'stops inference; tasks are not silently restarted.',
            style: const TextStyle(
              color: AppColors.neutral400,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const Divider(height: 22, color: AppColors.divider),
          const Text(
            'MobileUseAgent planner provider',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            key: ValueKey(widget.plannerProvider),
            initialValue: plannerProvider.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'LLM provider',
              isDense: true,
            ),
            items: MobilePlannerProviders.options
                .map(
                  (provider) => DropdownMenuItem(
                    value: provider.id,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            provider.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!provider.isIntegrated)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              'Setup needed',
                              style: TextStyle(
                                color: AppColors.neutral500,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (provider) {
              if (provider != null) {
                widget.onPlannerProviderChanged(provider);
              }
            },
          ),
          const SizedBox(height: 5),
          Text(
            plannerProvider.description,
            style: TextStyle(
              color: plannerProvider.isIntegrated
                  ? AppColors.neutral400
                  : AppColors.yellow,
              fontSize: 10,
            ),
          ),
          if (plannerProvider.isIntegrated) ...[
            const SizedBox(height: 5),
            Text(
              widget.ollamaProvider == 'cloud'
                  ? 'Task briefs and sanitized observations are sent to '
                        'ollama.com. Native actions remain locally validated.'
                  : 'Recommended: qwen2.5:0.5b for low memory, or '
                        'qwen2.5:1.5b for better quality.',
              style: const TextStyle(color: AppColors.neutral500, fontSize: 10),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _ollamaModels.contains(widget.selectedModel)
                  ? widget.selectedModel
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Exact discovered Ollama model',
                isDense: true,
              ),
              items: _ollamaModels
                  .map(
                    (model) => DropdownMenuItem(
                      value: model,
                      child: Text(
                        model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (model) {
                if (model != null) widget.onModelChanged(model);
              },
            ),
            const SizedBox(height: 4),
            Text(
              _ollamaStatus,
              style: const TextStyle(color: AppColors.neutral400, fontSize: 10),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _discoverOllama,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh Ollama models'),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Visible for provider planning only. MobileUseAgent will stop '
              'with a clear setup error instead of silently using another '
              'provider. Choose Ollama Local or Ollama Cloud for working '
              'execution in this build.',
              style: TextStyle(color: AppColors.neutral500, fontSize: 10),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: const TextStyle(color: AppColors.neutral300, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy || !accessibility
                    ? null
                    : running
                    ? () => _run(() async {
                        _planner.cancelCurrentTask();
                        await _service.stopRuntime();
                      }, 'Runtime stopped and the current task was cancelled.')
                    : () => _run(_service.startRuntime, 'Runtime started.'),
                child: Text(running ? 'Stop' : 'Start'),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          final ok = await _service.testRuntime();
                          await _refresh();
                          if (mounted) {
                            setState(
                              () => _message = ok
                                  ? 'Runtime and Accessibility are ready.'
                                  : 'Setup is incomplete.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: const Text('Test'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, bool positive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            positive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: positive ? AppColors.emerald : AppColors.neutral500,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.neutral300, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: positive ? AppColors.emerald : AppColors.neutral400,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
