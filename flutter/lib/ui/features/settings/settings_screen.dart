import 'package:flutter/material.dart';
import 'package:beatrice/data/services/live_api_service.dart';
import 'package:beatrice/data/services/ollama_service.dart';
import 'package:beatrice/data/services/opencode_service.dart';
import 'package:beatrice/ui/core/theme.dart';
import 'package:beatrice/ui/features/settings/language_picker.dart';

class SettingsScreen extends StatefulWidget {
  final String userContext;
  final String responseStyle;
  final String language;
  final String theme;
  final String voiceName;
  final String ollamaModel;
  final String ollamaBaseUrl;
  final String ollamaProvider;
  final String ollamaCloudApiKey;
  final OllamaService? ollamaService;
  final OpenCodeService? openCodeService;
  final String openCodeUrl;
  final ValueChanged<String> onOpenCodeUrlChanged;
  final ValueChanged<String> onUserContextChanged;
  final ValueChanged<String> onResponseStyleChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onVoiceChanged;
  final ValueChanged<String> onOllamaModelChanged;
  final ValueChanged<String> onOllamaBaseUrlChanged;
  final ValueChanged<String> onOllamaProviderChanged;
  final ValueChanged<String> onOllamaCloudApiKeyChanged;
  final ValueChanged<String> onThemeChanged;
  final VoidCallback onSave;

  const SettingsScreen({
    super.key,
    required this.userContext,
    required this.responseStyle,
    required this.language,
    required this.theme,
    required this.voiceName,
    required this.ollamaModel,
    required this.ollamaBaseUrl,
    required this.ollamaProvider,
    required this.ollamaCloudApiKey,
    this.ollamaService,
    this.openCodeService,
    required this.openCodeUrl,
    required this.onOpenCodeUrlChanged,
    required this.onUserContextChanged,
    required this.onResponseStyleChanged,
    required this.onLanguageChanged,
    required this.onVoiceChanged,
    required this.onOllamaModelChanged,
    required this.onOllamaBaseUrlChanged,
    required this.onOllamaProviderChanged,
    required this.onOllamaCloudApiKeyChanged,
    required this.onThemeChanged,
    required this.onSave,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _userContextCtrl;
  late TextEditingController _responseStyleCtrl;
  late TextEditingController _ollamaCtrl;
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _cloudKeyCtrl;
  late TextEditingController _openCodeUrlCtrl;
  List<String> _availableModels = [];
  bool _loadingModels = false;
  String? _connStatus;
  bool _testing = false;
  List<String> _openCodeModels = [];
  String? _openCodeModel;
  bool _loadingOpenCode = false;

  static const _stoneAliases = [
    'Diamond', 'Ruby', 'Emerald', 'Sapphire', 'Amethyst',
    'Topaz', 'Opal', 'Garnet', 'Jade', 'Pearl',
    'Onyx', 'Tanzanite', 'Citrine', 'Turquoise', 'Spinel',
  ];

  String _stoneFor(String modelId, List<String> allModels) {
    final idx = allModels.indexOf(modelId);
    if (idx < 0) return modelId;
    return _stoneAliases[idx % _stoneAliases.length];
  }

  @override
  void initState() {
    super.initState();
    _userContextCtrl = TextEditingController(text: widget.userContext);
    _responseStyleCtrl = TextEditingController(text: widget.responseStyle);
    _ollamaCtrl = TextEditingController(text: widget.ollamaModel);
    _baseUrlCtrl = TextEditingController(text: widget.ollamaBaseUrl);
    _cloudKeyCtrl = TextEditingController(text: widget.ollamaCloudApiKey);
    _openCodeUrlCtrl = TextEditingController(text: widget.openCodeUrl);
    _fetchModels();
    _loadOpenCodeModels();
  }

  Future<void> _loadOpenCodeModels() async {
    final service = widget.openCodeService;
    if (service == null) return;
    setState(() => _loadingOpenCode = true);
    service.baseUrl = _openCodeUrlCtrl.text;
    final models = await service.listModels();
    if (!mounted) return;
    setState(() {
      _openCodeModels = models;
      _loadingOpenCode = false;
      if (models.isNotEmpty && _openCodeModel == null) {
        _openCodeModel = models.first;
      }
    });
  }

  Future<void> _fetchModels() async {
    final service = widget.ollamaService;
    if (service == null) return;
    setState(() {
      _loadingModels = true;
      _connStatus = widget.ollamaProvider == 'cloud'
          ? 'Connecting to cloud provider...'
          : 'Looking for local provider...';
    });
    // Apply the current base URL before discovery so chips reflect the
    // configured Termux/host endpoint.
    if (widget.ollamaProvider == 'local') {
      service.configure(baseUrl: _baseUrlCtrl.text);
    }
    final discovery = await service.discoverModels();
    if (mounted) {
      setState(() {
        _availableModels = discovery.models;
        _loadingModels = false;
        _connStatus = discovery.status;
      });
      if (widget.ollamaProvider == 'local' &&
          discovery.endpoint != null &&
          discovery.endpoint != _baseUrlCtrl.text) {
        _baseUrlCtrl.text = discovery.endpoint!;
        service.configure(baseUrl: discovery.endpoint);
        widget.onOllamaBaseUrlChanged(discovery.endpoint!);
      }
      if (discovery.models.isNotEmpty &&
          !discovery.models.contains(_ollamaCtrl.text)) {
        _ollamaCtrl.text = discovery.models.first;
        widget.onOllamaModelChanged(discovery.models.first);
      }
    }
  }

  Future<void> _testConnection() async {
    final service = widget.ollamaService;
    if (service == null) return;
    setState(() {
      _testing = true;
      _connStatus = null;
    });
    if (widget.ollamaProvider == 'local') {
      service.configure(baseUrl: _baseUrlCtrl.text);
    }
    final discovery = await service.discoverModels();
    if (mounted) {
      setState(() {
        _availableModels = discovery.models;
        _connStatus = discovery.status;
        _testing = false;
      });
      if (widget.ollamaProvider == 'local' &&
          discovery.endpoint != null &&
          discovery.endpoint != _baseUrlCtrl.text) {
        _baseUrlCtrl.text = discovery.endpoint!;
        service.configure(baseUrl: discovery.endpoint);
        widget.onOllamaBaseUrlChanged(discovery.endpoint!);
      }
      if (discovery.models.isNotEmpty &&
          !discovery.models.contains(_ollamaCtrl.text)) {
        _ollamaCtrl.text = discovery.models.first;
        widget.onOllamaModelChanged(discovery.models.first);
      }
    }
  }

  @override
  void dispose() {
    _userContextCtrl.dispose();
    _responseStyleCtrl.dispose();
    _ollamaCtrl.dispose();
    _baseUrlCtrl.dispose();
    _cloudKeyCtrl.dispose();
    _openCodeUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeOptions = ['light', 'dark', 'system'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('What would you like Beatrice to know about you?'),
          const SizedBox(height: 8),
          TextField(
            controller: _userContextCtrl,
            onChanged: widget.onUserContextChanged,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            decoration: _inputDecoration("e.g., I'm a software developer..."),
          ),
          const SizedBox(height: 24),
          _label('How would you like Beatrice to respond?'),
          const SizedBox(height: 8),
          TextField(
            controller: _responseStyleCtrl,
            onChanged: widget.onResponseStyleChanged,
            maxLines: 5,
            minLines: 3,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            decoration: _inputDecoration(
              'e.g., Keep responses concise and use code examples...',
            ),
          ),
          const SizedBox(height: 24),
          _label('Language'),
          const SizedBox(height: 4),
          const Text(
            'Beatrice uses this as her preferred response language and aims '
            'for natural, idiomatic delivery. You can still request a '
            'different language during a conversation.',
            style: TextStyle(color: AppColors.neutral500, fontSize: 11),
          ),
          const SizedBox(height: 8),
          LanguagePickerField(
            selectedLanguage: widget.language,
            onSelected: widget.onLanguageChanged,
          ),
          const SizedBox(height: 24),
          _label('Voice'),
          const SizedBox(height: 4),
          const Text(
            'Select the voice used during Live voice conversations.',
            style: TextStyle(color: AppColors.neutral500, fontSize: 11),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: LiveApiService.labelForVoice(widget.voiceName),
            decoration: _inputDecoration('Voice'),
            items: LiveApiService.voiceOptions
                .map(
                  (v) => DropdownMenuItem(
                    value: v['label'],
                    child: Text(v['label']!),
                  ),
                )
                .toList(),
            onChanged: (label) {
              if (label != null) {
                widget.onVoiceChanged(
                  LiveApiService.apiNameForLabel(label),
                );
              }
            },
          ),
          const SizedBox(height: 24),
          _label('Chat provider'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: widget.ollamaProvider,
            decoration: _inputDecoration('Provider'),
            items: const [
              DropdownMenuItem(
                value: 'local',
                child: Text('Earth · local (offline)'),
              ),
              DropdownMenuItem(
                value: 'cloud',
                child: Text('Jupiter · cloud (online)'),
              ),
            ],
            onChanged: (provider) {
              if (provider != null) widget.onOllamaProviderChanged(provider);
            },
          ),
          const SizedBox(height: 4),
          Text(
            widget.ollamaProvider == 'cloud'
                ? 'Cloud requests and task observations are sent online '
                      'only when Cloud is selected.'
                : 'Local requests stay on this device and run offline.',
            style: TextStyle(color: AppColors.neutral500, fontSize: 11),
          ),
          const SizedBox(height: 8),
          if (widget.ollamaProvider == 'cloud') ...[
            TextField(
              controller: _cloudKeyCtrl,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: widget.onOllamaCloudApiKeyChanged,
              style: const TextStyle(color: AppColors.white, fontSize: 14),
              decoration: _inputDecoration('Cloud API key'),
            ),
            const SizedBox(height: 6),
            const Text(
              'Stored in Android encrypted secure storage. It is never '
              'included in chat text, logs, or builds.',
              style: TextStyle(color: AppColors.neutral500, fontSize: 10),
            ),
            const SizedBox(height: 8),
          ] else ...[
            _label('Local server URL'),
            const SizedBox(height: 4),
            const Text(
              'For a local server on this device, use http://127.0.0.1:11434',
              style: TextStyle(color: AppColors.neutral500, fontSize: 11),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _baseUrlCtrl,
                    onChanged: widget.onOllamaBaseUrlChanged,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                    ),
                    decoration: _inputDecoration('http://127.0.0.1:11434'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _testing ? null : _testConnection,
                    icon: _testing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.black,
                            ),
                          )
                        : const Icon(
                            Icons.wifi_find,
                            size: 16,
                            color: AppColors.black,
                          ),
                    label: const Text(
                      'Test',
                      style: TextStyle(color: AppColors.black, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_connStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _connStatus!,
                style: TextStyle(
                  fontSize: 12,
                  color: _connStatus!.startsWith('Connected')
                      ? AppColors.emerald
                      : AppColors.red400,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _label(
                widget.ollamaProvider == 'cloud'
                    ? 'Cloud model'
                    : 'Local model',
              ),
              IconButton(
                onPressed: _loadingModels ? null : _fetchModels,
                tooltip: 'Refresh models',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.neutral400,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('${_availableModels.join('|')}::${_ollamaCtrl.text}'),
            initialValue: _availableModels.contains(_ollamaCtrl.text)
                ? _ollamaCtrl.text
                : null,
            isExpanded: true,
            dropdownColor: AppColors.chip2121,
            iconEnabledColor: AppColors.neutral400,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
            decoration: _inputDecoration('Select a discovered model'),
            hint: Text(
              _loadingModels
                  ? 'Discovering models...'
                  : _availableModels.isEmpty
                  ? 'No models reported'
                  : 'Select a model',
              style: const TextStyle(color: AppColors.neutral400, fontSize: 14),
            ),
            items: _availableModels
                .map(
                  (model) => DropdownMenuItem<String>(
                    value: model,
                    child: Text(
                      model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _availableModels.isEmpty
                ? null
                : (model) {
                    if (model == null) return;
                    _ollamaCtrl.text = model;
                    widget.onOllamaModelChanged(model);
                  },
          ),
          const SizedBox(height: 8),
          if (_loadingModels)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neutral400,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Loading models...',
                    style: TextStyle(color: AppColors.neutral400, fontSize: 12),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _label('OpenCode Server URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _openCodeUrlCtrl,
            onChanged: widget.onOpenCodeUrlChanged,
            decoration: _inputDecoration('http://127.0.0.1:4096'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _loadingOpenCode
                      ? null
                      : () => _loadOpenCodeModels(),
                  child: _loadingOpenCode
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.black,
                          ),
                        )
                      : const Text('Connect OpenCode'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await widget.openCodeService?.startLocalServer();
                    if (mounted) {
                      setState(
                        () => _connStatus =
                            'OpenCode server start requested in Termux.',
                      );
                    }
                  } catch (_) {
                    if (mounted) {
                      setState(
                        () => _connStatus =
                            'Install Termux and Termux:API, then try again.',
                      );
                    }
                  }
                },
                child: const Text('Start in Termux'),
              ),
            ],
          ),
          if (_openCodeModels.isNotEmpty) ...[
            const SizedBox(height: 12),
            _label('Zen Free model'),
            const SizedBox(height: 4),
            const Text(
              'Auto-discovered from OpenCode. Each model is shown as a '
              'precious stone alias.',
              style: TextStyle(color: AppColors.neutral500, fontSize: 11),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'opencode::${_openCodeModels.join('|')}',
              ),
              initialValue: _openCodeModel,
              isExpanded: true,
              dropdownColor: AppColors.chip2121,
              iconEnabledColor: AppColors.neutral400,
              style: const TextStyle(color: AppColors.white, fontSize: 14),
              decoration: _inputDecoration('Select a Zen Free model'),
              items: _openCodeModels
                  .map(
                    (model) => DropdownMenuItem<String>(
                      value: model,
                      child: Text(
                        '${_stoneFor(model, _openCodeModels)} · $model',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (model) {
                if (model != null) {
                  setState(() => _openCodeModel = model);
                }
              },
            ),
          ] else if (!_loadingOpenCode)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Connect OpenCode to discover available Zen Free models.',
                style: TextStyle(color: AppColors.neutral500, fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),
          _label('Theme'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.chip2121,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: themeOptions.map((t) {
                final active = widget.theme == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => widget.onThemeChanged(t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppColors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t[0].toUpperCase() + t.substring(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: active
                              ? AppColors.black
                              : AppColors.neutral400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: const TextStyle(color: AppColors.white, fontSize: 14));

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.neutral400),
    filled: true,
    fillColor: AppColors.chip2121,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.neutral600),
    ),
    contentPadding: const EdgeInsets.all(12),
  );
}
