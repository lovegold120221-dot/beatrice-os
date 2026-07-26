import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:beatrice/data/models/message.dart';
import 'package:beatrice/data/repositories/supabase_repository.dart';
import 'package:beatrice/data/services/gemini_service.dart';
import 'package:beatrice/data/services/ollama_service.dart';
import 'package:beatrice/data/services/web_lookup_service.dart';
import 'package:beatrice/data/services/local_ocr_service.dart';
import 'package:beatrice/data/services/opencode_service.dart';
import 'package:beatrice/data/services/flux_service.dart';
import 'package:beatrice/data/services/audio_service.dart';
import 'package:beatrice/data/services/live_api_service.dart';
import 'package:beatrice/data/services/memory_service.dart';
import 'package:beatrice/data/services/profile_service.dart';
import 'package:beatrice/data/services/mobile_use_agent_runtime.dart';
import 'package:beatrice/data/services/mobile_planner_provider.dart';
import 'package:beatrice/data/services/hosted_planner_service.dart';
import 'package:beatrice/data/services/mobile_task_coordinator.dart';
import 'package:beatrice/data/services/mobile_use_service.dart';
import 'package:beatrice/data/services/language_preferences.dart';
import 'package:beatrice/data/services/voice_opening_service.dart';
import 'package:beatrice/ui/core/theme.dart';
import 'package:beatrice/ui/features/home/home_screen.dart';
import 'package:beatrice/ui/features/chat/widgets/message_bubble.dart';
import 'package:beatrice/ui/features/voice/voice_screen.dart';
import 'package:beatrice/ui/features/sidebar/sidebar.dart';
import 'package:beatrice/ui/features/auth/auth_screen.dart';
import 'package:beatrice/ui/features/settings/settings_screen.dart';
import 'package:beatrice/ui/features/settings/mobile_use_setup_screen.dart';
import 'package:beatrice/ui/features/attachment/attachment_sheet.dart';

bool shouldSuspendLiveCapture(AppLifecycleState state) =>
    state == AppLifecycleState.paused ||
    state == AppLifecycleState.hidden ||
    state == AppLifecycleState.detached;

class BeatriceApp extends StatelessWidget {
  const BeatriceApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The MaterialApp lives in BeatriceHome so the theme can react to the
    // user's saved theme preference (light/dark/system) via setState.
    return const BeatriceHome();
  }
}

class BeatriceHome extends StatefulWidget {
  const BeatriceHome({super.key});

  @override
  State<BeatriceHome> createState() => _BeatriceHomeState();
}

class _BeatriceHomeState extends State<BeatriceHome>
    with WidgetsBindingObserver {
  static const _secureStorage = FlutterSecureStorage();
  static const _geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _geminiFallbackKey =
      String.fromEnvironment('GEMINI_API_KEY_FALLBACK');
  static const _groqKey = String.fromEnvironment('GROQ_API_KEY');
  static const _preferredOllamaModel = String.fromEnvironment(
    'OLLAMA_MODEL',
    defaultValue: 'eburon-code-fast:latest',
  );
  late final SupabaseRepository _repo;
  late final GeminiService _gemini;
  late OllamaService _ollama;
  late OpenCodeService _openCode;
  late final FluxService _flux;
  late final AudioService _audioService;
  late final LiveApiService _liveApi;
  late final MemoryService _memoryService;
  late final ProfileService _profileService;
  late final WebLookupService _webLookup;
  late final LocalOcrService _localOcr;
  late final VoiceOpeningService _voiceOpening;
  late final HostedPlannerService _geminiPlanner;
  late final HostedPlannerService _groqPlanner;
  final MobileUseAgentRuntime _mobileUseAgent = MobileUseAgentRuntime.instance;
  final MobileTaskCoordinator _liveTaskPreflight = MobileTaskCoordinator();
  StreamSubscription<MobileUseWorkflowEvent>? _mobileUseEventSub;
  final List<MobileUseWorkflowEvent> _pendingMobileVoiceEvents = [];
  final Set<String> _handledLiveToolCallIds = {};
  final VoiceOpeningGate _liveOpeningGate = VoiceOpeningGate();
  bool _liveUserTurnActive = false;
  DateTime? _lastMobileVoiceUpdate;
  Timer? _mobileVoiceFlushTimer;
  Timer? _liveOpeningTimer;
  late final ScrollController _scrollController;
  late final TextEditingController _inputController;

  bool _isInitialized = false;

  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isThinking = false;
  bool _isFastMode = false;
  bool _showImageSettings = false;
  bool _isRecording = false;
  bool _isVoiceOpen = false;
  bool _isLiveActive = false;
  bool _isSpeaking = false;
  double _micInputLevel = 0;
  int _lastMicVisualizerUpdateMicros = 0;
  bool _isSidebarOpen = false;
  bool _showHeaderMenu = false;
  String _liveTranscription = '';
  String? _voiceStatus;
  CameraController? _liveCamera;
  Timer? _liveCameraTimer;
  bool _isLiveCameraActive = false;
  bool _liveCameraCapturing = false;
  bool _backgroundLiveShutdown = false;
  String? _lastRestoredRuntimeStatus;
  bool _taskMode = false;
  bool _webToolEnabled = false;
  bool _ocrToolEnabled = false;
  bool _ocrEnglishReady = false;
  Uint8List? _pendingVisionImage;
  String? _pendingVisionImageName;

  // Image-gen settings (mirror root input popover).
  String _imageSize = '1K';
  String _imageAspect = '1:1';

  String _userContext = '';
  String _responseStyle = '';
  String _language = LanguagePreferences.defaultLanguage;
  String _theme = 'system';
  String _ollamaModel = '';
  String _ollamaProvider = 'local';
  String _mobilePlannerProvider = MobilePlannerProviders.ollamaLocal;
  String _localOllamaModel = '';
  String _cloudOllamaModel = '';
  String _ollamaCloudApiKey = '';
  String _geminiPlannerApiKey = '';
  String _groqPlannerApiKey = '';
  String _geminiPlannerModel = '';
  String _groqPlannerModel = '';
  String _ollamaBaseUrl = 'http://127.0.0.1:11434';
  String _openCodeUrl = 'http://127.0.0.1:4096';
  String _voiceName = LiveApiService.koreVoiceName;

  String? _currentChatId;
  List<Map<String, dynamic>> _chatHistory = [];
  String _conversationContext = '';
  List<Map<String, dynamic>> _memories = [];

  User? _user;
  String? _authError;

  String? _activeModal; // 'account', 'settings', null
  bool _isAttachmentSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repo = SupabaseRepository(Supabase.instance.client);
    _gemini = GeminiService(
      _geminiKey,
      apiKeyFallback: _geminiFallbackKey,
    );
    _ollama = OllamaService(baseUrl: _ollamaBaseUrl);
    _openCode = OpenCodeService(baseUrl: _openCodeUrl);
    _flux = FluxService(const String.fromEnvironment('HF_TOKEN'));
    _audioService = AudioService();
    _liveApi = LiveApiService();
    _memoryService = MemoryService(_repo);
    _profileService = ProfileService(_repo);
    _webLookup = WebLookupService();
    _localOcr = LocalOcrService();
    _voiceOpening = VoiceOpeningService();
    // Warm optional public opening context in the background. Entering Live
    // never waits on news; user speech and connection readiness come first.
    unawaited(_voiceOpening.loadDailyBrief());
    _geminiPlanner = HostedPlannerService(
      providerId: MobilePlannerProviders.gemini,
    );
    _groqPlanner = HostedPlannerService(
      providerId: MobilePlannerProviders.groq,
    );
    _scrollController = ScrollController();
    _inputController = TextEditingController();
    _mobileUseEventSub = _mobileUseAgent.verifiedEvents.listen((event) {
      if (!mounted) return;
      _handleVerifiedMobileUseEvent(event);
    });

    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreRuntimeStatus());
      return;
    }
    if (shouldSuspendLiveCapture(state)) {
      unawaited(_suspendLiveCaptureForBackground());
    }
  }

  Future<void> _init() async {
    _repo.client.auth.onAuthStateChange.listen((data) {
      setState(() => _user = data.session?.user);
      if (data.session?.user != null) {
        _loadMemories();
        _fetchChatHistory();
        if (_isInitialized) {
          unawaited(_restoreSyncedMobileAgentSettings());
        }
      }
    });

    final session = _repo.client.auth.currentSession;
    setState(() => _user = session?.user);

    final settings = await _profileService.loadLocalSettings();
    final prefs = await SharedPreferences.getInstance();
    final cloudKey =
        await _secureStorage.read(key: 'eburon_ollama_cloud_api_key') ?? '';
    final geminiPlannerKey =
        await _secureStorage.read(key: 'eburon_gemini_planner_api_key') ?? '';
    final groqPlannerKey =
        await _secureStorage.read(key: 'eburon_groq_planner_api_key') ?? '';
    setState(() {
      _userContext = settings['userContext']!;
      _responseStyle = settings['responseStyle']!;
      _language = LanguagePreferences.normalize(settings['language']);
      _theme = settings['theme']!;
      _ollamaProvider = prefs.getString('eburon_ollamaProvider') ?? 'local';
      _mobilePlannerProvider =
          prefs.getString('eburon_mobilePlannerProvider') ??
          (_ollamaProvider == 'cloud'
              ? MobilePlannerProviders.ollamaCloud
              : MobilePlannerProviders.ollamaLocal);
      _localOllamaModel =
          prefs.getString('eburon_ollamaLocalModel') ??
          settings['ollamaModel']!;
      _cloudOllamaModel = prefs.getString('eburon_ollamaCloudModel') ?? '';
      _ollamaModel = _ollamaProvider == 'cloud'
          ? _cloudOllamaModel
          : _localOllamaModel;
      _ollamaBaseUrl = settings['ollamaBaseUrl']!;
      _ollamaCloudApiKey = cloudKey;
      _geminiPlannerApiKey = geminiPlannerKey;
      _groqPlannerApiKey = groqPlannerKey.isNotEmpty ? groqPlannerKey : _groqKey;
      _geminiPlannerModel = prefs.getString('eburon_geminiPlannerModel') ?? '';
      _groqPlannerModel = prefs.getString('eburon_groqPlannerModel') ?? '';
      _taskMode = prefs.getBool('eburon_chatTaskMode') ?? false;
      _voiceName = prefs.getString('eburon_voiceName') ??
          LiveApiService.koreVoiceName;
    });
    _geminiPlanner.configure(apiKey: _geminiPlannerApiKey);
    _groqPlanner.configure(apiKey: _groqPlannerApiKey);
    _configureSelectedOllama();
    try {
      _ocrEnglishReady = await _localOcr.isEnglishReady();
    } catch (_) {
      _ocrEnglishReady = false;
    }

    try {
      final profile = await _profileService.loadCloudProfile();
      if (profile != null) {
        setState(() {
          if (profile.userContext.isNotEmpty) {
            _userContext = profile.userContext;
            _saveSetting('userContext', profile.userContext);
          }
          if (profile.responseStyle.isNotEmpty) {
            _responseStyle = profile.responseStyle;
            _saveSetting('responseStyle', profile.responseStyle);
          }
          if (profile.theme.isNotEmpty) {
            _theme = profile.theme;
            _saveSetting('theme', profile.theme);
          }
          if (profile.ollamaModel.isNotEmpty && _ollamaProvider == 'local') {
            _ollamaModel = profile.ollamaModel;
            _localOllamaModel = profile.ollamaModel;
            _saveSetting('ollamaModel', profile.ollamaModel);
            _ollama.configure(defaultModel: _ollamaModel);
          }
        });
      }
    } catch (_) {}

    await _restoreSyncedMobileAgentSettings();
    await _autoSelectOllamaModel();
    _configureSelectedOllama();

    if (_user != null) {
      await _loadMemories();
      await _fetchChatHistory();
    }

    setState(() => _isInitialized = true);
    unawaited(_restoreRuntimeStatus());
  }

  Future<void> _autoSelectOllamaModel() async {
    _configureSelectedOllama();
    final discovery = await _ollama.discoverModels();
    if (!mounted || !discovery.isConnected) return;

    if (_ollamaProvider == 'local' && discovery.endpoint != _ollamaBaseUrl) {
      setState(() => _ollamaBaseUrl = discovery.endpoint!);
      _ollama.configure(baseUrl: discovery.endpoint);
      await _saveSetting('ollamaBaseUrl', discovery.endpoint!);
    }
    final models = discovery.models;
    if (models.isEmpty) return;

    final model = models.contains(_ollamaModel)
        ? _ollamaModel
        : models.contains(_preferredOllamaModel)
        ? _preferredOllamaModel
        : models.first;
    if (model == _ollamaModel) return;
    await _changeSelectedOllamaModel(model);
  }

  Future<void> _saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eburon_$key', value);
  }

  String get _effectiveResponseStyle {
    final languageInstruction = LanguagePreferences.responseInstruction(
      _language,
    );
    final style = _responseStyle.trim();
    return style.isEmpty
        ? languageInstruction
        : '$style\n\n$languageInstruction';
  }

  String _plannerModelForProvider(String providerId) {
    return switch (providerId) {
      MobilePlannerProviders.ollamaLocal => _localOllamaModel,
      MobilePlannerProviders.ollamaCloud => _cloudOllamaModel,
      MobilePlannerProviders.gemini => _geminiPlannerModel,
      MobilePlannerProviders.groq => _groqPlannerModel,
      _ => '',
    };
  }

  void _configureSelectedPlanner() {
    _mobileUseAgent.configurePlannerProvider(_mobilePlannerProvider);
    switch (_mobilePlannerProvider) {
      case MobilePlannerProviders.gemini:
        _geminiPlanner.configure(apiKey: _geminiPlannerApiKey);
        _mobileUseAgent.configureHostedPlanner(
          _geminiPlanner,
          _geminiPlannerModel,
        );
      case MobilePlannerProviders.groq:
        _groqPlanner.configure(apiKey: _groqPlannerApiKey);
        _mobileUseAgent.configureHostedPlanner(_groqPlanner, _groqPlannerModel);
      default:
        _mobileUseAgent.configureHostedPlanner(null, '');
    }
  }

  void _configureSelectedOllama() {
    final cloud = _ollamaProvider == 'cloud';
    _ollama.configure(
      baseUrl: cloud ? 'https://ollama.com/api' : _ollamaBaseUrl,
      defaultModel: _ollamaModel,
      isCloud: cloud,
      apiKey: cloud ? _ollamaCloudApiKey : '',
    );
    _mobileUseAgent.configureOllama(_ollama, _ollamaModel);
    _configureSelectedPlanner();
  }

  Future<void> _changeMobilePlannerProvider(String providerId) async {
    final provider = MobilePlannerProviders.byId(providerId);
    setState(() => _mobilePlannerProvider = provider.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eburon_mobilePlannerProvider', provider.id);

    if (provider.id == MobilePlannerProviders.ollamaLocal) {
      await _changeOllamaProvider('local');
    } else if (provider.id == MobilePlannerProviders.ollamaCloud) {
      await _changeOllamaProvider('cloud');
    }
    _configureSelectedOllama();
    final model = _plannerModelForProvider(provider.id);
    if (_user != null && provider.isIntegrated && model.isNotEmpty) {
      try {
        await _repo.saveMobileAgentSettings(
          provider: provider.id,
          model: model,
        );
      } catch (error) {
        debugPrint('MobileUseAgent settings sync unavailable: $error');
      }
    }
  }

  Future<String> _saveHostedPlannerSettings({
    required String providerId,
    required String model,
    required String apiKey,
  }) async {
    final provider = MobilePlannerProviders.byId(providerId);
    if (provider.id != MobilePlannerProviders.gemini &&
        provider.id != MobilePlannerProviders.groq) {
      throw StateError('Only Neptune or Mars uses hosted planner settings.');
    }
    final selectedModel = model.trim();
    final selectedKey = apiKey.trim();
    if (selectedKey.isEmpty) {
      throw StateError('${provider.label} API key is required.');
    }
    if (selectedModel.isEmpty) {
      throw StateError('Select an exact ${provider.label} model first.');
    }
    final service = provider.id == MobilePlannerProviders.gemini
        ? _geminiPlanner
        : _groqPlanner;
    service.configure(apiKey: selectedKey);
    final discovery = await service.discoverModels();
    if (!discovery.isConnected) {
      throw StateError(discovery.error ?? discovery.status);
    }
    if (!discovery.models.contains(selectedModel)) {
      throw StateError(
        'The selected model is no longer available. Refresh and choose an '
        'exact model returned for this key.',
      );
    }

    final secureKeyName = provider.id == MobilePlannerProviders.gemini
        ? 'eburon_gemini_planner_api_key'
        : 'eburon_groq_planner_api_key';
    final modelPreference = provider.id == MobilePlannerProviders.gemini
        ? 'eburon_geminiPlannerModel'
        : 'eburon_groqPlannerModel';
    await _secureStorage.write(key: secureKeyName, value: selectedKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(modelPreference, selectedModel);
    await prefs.setString('eburon_mobilePlannerProvider', provider.id);

    if (mounted) {
      setState(() {
        _mobilePlannerProvider = provider.id;
        if (provider.id == MobilePlannerProviders.gemini) {
          _geminiPlannerApiKey = selectedKey;
          _geminiPlannerModel = selectedModel;
        } else {
          _groqPlannerApiKey = selectedKey;
          _groqPlannerModel = selectedModel;
        }
      });
    }
    _configureSelectedPlanner();

    if (_user != null) {
      try {
        await _repo.saveMobileAgentSettings(
          provider: provider.id,
          model: selectedModel,
        );
      } catch (_) {
        throw StateError(
          'Saved securely on this device, but Supabase account sync is not '
          'available yet. Apply the mobile_agent_settings migration in db.sql '
          'to the configured Supabase project, then tap Save settings again.',
        );
      }
      return 'Saved securely on this device. Provider and model synced to '
          'your signed-in Beatrice account.';
    }
    return 'Saved securely on this device. Sign in to sync the provider and '
        'model to your other devices.';
  }

  Future<void> _restoreSyncedMobileAgentSettings() async {
    if (_user == null) return;
    final synced = await _repo.loadMobileAgentSettings();
    if (synced == null) return;
    final providerId = synced['provider']?.toString() ?? '';
    final model = synced['model']?.toString().trim() ?? '';
    final provider = MobilePlannerProviders.byId(providerId);
    if (provider.id != providerId || !provider.isIntegrated || model.isEmpty) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eburon_mobilePlannerProvider', providerId);
    switch (providerId) {
      case MobilePlannerProviders.ollamaLocal:
        _ollamaProvider = 'local';
        _localOllamaModel = model;
        _ollamaModel = model;
        await prefs.setString('eburon_ollamaProvider', 'local');
        await prefs.setString('eburon_ollamaLocalModel', model);
      case MobilePlannerProviders.ollamaCloud:
        _ollamaProvider = 'cloud';
        _cloudOllamaModel = model;
        _ollamaModel = model;
        await prefs.setString('eburon_ollamaProvider', 'cloud');
        await prefs.setString('eburon_ollamaCloudModel', model);
      case MobilePlannerProviders.gemini:
        _geminiPlannerModel = model;
        await prefs.setString('eburon_geminiPlannerModel', model);
      case MobilePlannerProviders.groq:
        _groqPlannerModel = model;
        await prefs.setString('eburon_groqPlannerModel', model);
    }
    if (mounted) {
      setState(() => _mobilePlannerProvider = providerId);
    } else {
      _mobilePlannerProvider = providerId;
    }
    _configureSelectedOllama();
  }

  Future<void> _changeOllamaProvider(String provider) async {
    if (provider == _ollamaProvider) return;
    setState(() {
      _ollamaProvider = provider;
      _ollamaModel = provider == 'cloud'
          ? _cloudOllamaModel
          : _localOllamaModel;
    });
    _configureSelectedOllama();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eburon_ollamaProvider', provider);
  }

  Future<void> _changeVoice(String voiceApiName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eburon_voiceName', voiceApiName);
    if (mounted) setState(() => _voiceName = voiceApiName);
  }

  Future<void> _changeOllamaCloudKey(String key) async {
    _ollamaCloudApiKey = key.trim();
    await _secureStorage.write(
      key: 'eburon_ollama_cloud_api_key',
      value: _ollamaCloudApiKey,
    );
    _configureSelectedOllama();
    if (mounted) setState(() {});
  }

  Future<void> _changeSelectedOllamaModel(String model) async {
    setState(() {
      _ollamaModel = model;
      if (_ollamaProvider == 'cloud') {
        _cloudOllamaModel = model;
      } else {
        _localOllamaModel = model;
      }
    });
    _configureSelectedOllama();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _ollamaProvider == 'cloud'
          ? 'eburon_ollamaCloudModel'
          : 'eburon_ollamaLocalModel',
      model,
    );
    await _saveSetting('ollamaModel', model);
    final selectedOllamaProvider = _ollamaProvider == 'cloud'
        ? MobilePlannerProviders.ollamaCloud
        : MobilePlannerProviders.ollamaLocal;
    if (_user != null && _mobilePlannerProvider == selectedOllamaProvider) {
      try {
        await _repo.saveMobileAgentSettings(
          provider: selectedOllamaProvider,
          model: model,
        );
      } catch (error) {
        debugPrint('MobileUseAgent settings sync unavailable: $error');
      }
    }
  }

  Future<void> _autoSaveProfile() async {
    await _profileService.saveCloudProfile(
      userContext: _userContext,
      responseStyle: _responseStyle,
      theme: _theme,
      ollamaModel: _localOllamaModel,
    );
  }

  Future<void> _loadMemories() async {
    if (_user == null) return;
    final data = await _repo.getMemories();
    setState(() => _memories = data);
  }

  Future<void> _fetchChatHistory() async {
    if (_user == null) return;
    final data = await _repo.getChats();
    setState(() => _chatHistory = data);
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Image generation mode: produce an image instead of a chat reply.
    if (_showImageSettings) {
      await _sendImageGen(text);
      return;
    }

    setState(() {
      _messages.add(Message(role: 'user', text: text));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    _saveMessageToDb(Message(role: 'user', text: text));

    try {
      final modelMessage = Message(role: 'model', text: '');
      setState(() => _messages.add(modelMessage));

      final history = <Map<String, dynamic>>[];
      String expectedRole = 'user';

      for (final m in _messages) {
        if (m.text.isEmpty || m.isImageGen) continue;
        if (m.role == expectedRole) {
          history.add({
            'role': m.role,
            'parts': [
              {'text': m.text},
            ],
          });
          expectedRole = expectedRole == 'user' ? 'model' : 'user';
        } else if (history.isNotEmpty) {
          final last = history.last;
          (last['parts'] as List).first['text'] += '\n\n${m.text}';
        }
      }
      if (history.isNotEmpty && history.last['role'] == 'user') {
        history.removeLast();
      }

      StringBuffer fullText = StringBuffer();
      if (_taskMode) {
        _mobileUseAgent.configureOllama(_ollama, _ollamaModel);
        _mobileUseAgent.configurePlannerProvider(_mobilePlannerProvider);
        final localPlan = await _mobileUseAgent.planTypedTask(text);
        fullText.write(localPlan);
        setState(() {
          _messages.last = _messages.last.copyWith(text: localPlan);
        });
      } else {
        if (_ollamaModel.isEmpty) {
          throw Exception(
            'Chat needs a discovered model. Start a local server, '
            'then choose an installed model in Beatrice setup.',
          );
        }
        final discovery = await _ollama.discoverModels(
          candidates: [_ollamaBaseUrl],
        );
        if (!discovery.isConnected) {
          throw Exception(
            _ollamaProvider == 'cloud'
                ? 'Cloud provider is unavailable. Check internet access and '
                      'the Cloud API key in Settings.'
                : 'Local provider is offline. Start a local server, '
                      'then retry.',
          );
        }
        if (!discovery.models.contains(_ollamaModel)) {
          throw Exception(
            'The selected model "$_ollamaModel" is not currently '
            'reported by the provider. Refresh models in '
            'Settings.',
          );
        }
        if (_ollamaProvider == 'local' &&
            discovery.endpoint != _ollamaBaseUrl) {
          _ollamaBaseUrl = discovery.endpoint!;
          await _saveSetting('ollamaBaseUrl', discovery.endpoint!);
        }
        _ollama.configure(baseUrl: _ollamaBaseUrl, defaultModel: _ollamaModel);
        final image = _pendingVisionImage;
        final response = await _ollama.generateChatWithTools(
          prompt: text,
          model: _ollamaModel,
          history: history,
          base64Images: image == null || _ocrToolEnabled
              ? const []
              : [base64Encode(image)],
          enableWebLookup: _webToolEnabled,
          webLookup: _webLookup.lookup,
          enableLocalOcr: _ocrToolEnabled && image != null,
          localOcr: image == null
              ? null
              : () async => (await _localOcr.recognize(image)).toJson(),
          userContext: [
            _userContext,
            if (_memories.isNotEmpty)
              _memoryService.buildMemoryContext(_memories),
            if (_conversationContext.isNotEmpty) _conversationContext,
          ].where((value) => value.isNotEmpty).join('\n\n'),
          responseStyle: _effectiveResponseStyle,
        );
        fullText.write(response);
        setState(() {
          _messages.last = _messages.last.copyWith(text: response);
          _pendingVisionImage = null;
          _pendingVisionImageName = null;
          _ocrToolEnabled = false;
        });
      }

      final finalText = fullText.toString();
      _saveMessageToDb(Message(role: 'model', text: finalText));

      if (_isVoiceOpen && !_isLiveActive && finalText.isNotEmpty) {
        try {
          setState(() => _isSpeaking = true);
          final audioBase64 = await _gemini.textToSpeech(finalText);
          if (audioBase64 != null) {
            final base64Data = audioBase64.split(',').last;
            await _audioService.playBase64Audio(base64Data);
          }
        } catch (e) {
          debugPrint('TTS failed: $e');
        }
        setState(() => _isSpeaking = false);
      }

      if (_user != null) {
        await _memoryService.extractAndStoreMemories(text, finalText);
        await _loadMemories();
      }
    } catch (e) {
      final clean = e.toString()
          .replaceFirst(RegExp(r'^(Exception|Bad state|FormatException):\s*'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      setState(() {
        _messages.add(
          Message(role: 'model', text: clean),
        );
      });
      _saveMessageToDb(
        Message(
          role: 'model',
          text: 'Sorry, something went wrong. ${e.toString()}',
        ),
      );
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendImageGen(String prompt) async {
    setState(() => _isLoading = true);
    _inputController.clear();
    setState(() => _showImageSettings = false);
    _messages.add(Message(role: 'user', text: prompt));
    _saveMessageToDb(Message(role: 'user', text: prompt));
    _scrollToBottom();

    try {
      String? imageData;
      try {
        imageData = await _flux.generateImage(
          prompt,
          size: _imageSize,
          aspectRatio: _imageAspect,
        );
      } catch (_) {
        imageData = null;
      }
      imageData ??= await _gemini.generateImage(
        prompt,
        size: _imageSize,
        aspectRatio: _imageAspect,
      );

      if (imageData != null) {
        setState(() {
          _messages.add(
            Message(
              role: 'model',
              text: '',
              image: imageData,
              isImageGen: true,
              originalPrompt: prompt,
            ),
          );
        });
        _saveMessageToDb(
          Message(
            role: 'model',
            text: '',
            image: imageData,
            isImageGen: true,
            originalPrompt: prompt,
          ),
        );
      } else {
        setState(() {
          _messages.add(
            const Message(
              role: 'model',
              text: 'I could not generate that image.',
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          Message(
            role: 'model',
            text: 'Image generation failed: ${e.toString()}',
          ),
        );
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _saveMessageToDb(Message msg) async {
    if (_user == null) return;
    try {
      String? chatId = _currentChatId;

      if (chatId == null) {
        final title = msg.text.length > 30
            ? '${msg.text.substring(0, 30)}...'
            : msg.text;
        final chat = await _repo.createChat(title, '');
        chatId = chat['id'] as String;
        setState(() => _currentChatId = chatId);
        _fetchChatHistory();
      }

      final roleLabel = msg.role == 'user' ? 'User' : 'Beatrice';
      final contextLine = '$roleLabel: ${msg.text}';

      final existing = await _repo.getChatContext(chatId);
      final prevContext = existing?['context_text'] as String? ?? '';
      final newContext = prevContext.isEmpty
          ? contextLine
          : '$prevContext\n$contextLine';
      await _repo.updateChatContext(chatId, newContext);

      await _repo.insertMessage({
        'chat_id': chatId,
        'role': msg.role,
        'text': msg.text,
        'image_url': msg.image ?? '',
        'is_image_gen': msg.isImageGen,
        'original_prompt': msg.originalPrompt ?? '',
      });

      setState(() => _conversationContext = newContext);
    } catch (e) {
      debugPrint('Failed to save message: $e');
    }
  }

  Future<void> _loadChat(String chatId) async {
    setState(() => _isLoading = true);
    _closeSidebar();

    try {
      final chatData = await _repo.getChatContext(chatId);
      setState(() {
        _currentChatId = chatId;
        _conversationContext = chatData?['context_text'] as String? ?? '';
      });

      final data = await _repo.getMessages(chatId);
      final msgs = data.map((m) => Message.fromJson(m)).toList();
      setState(() => _messages = msgs);
    } catch (_) {}

    setState(() => _isLoading = false);
  }

  void _createNewChat() {
    setState(() {
      _messages = [];
      _currentChatId = null;
      _conversationContext = '';
    });
    _closeSidebar();
  }

  void _clearChat() {
    setState(() {
      _showHeaderMenu = false;
      _messages = [];
      _currentChatId = null;
      _conversationContext = '';
    });
  }

  Future<void> _deleteChat(String chatId) async {
    await _repo.deleteChat(chatId);
    if (_currentChatId == chatId) _createNewChat();
    _fetchChatHistory();
  }

  void _handleSignUp(String email, String password) async {
    try {
      final result = await _repo.signUp(email, password);
      if (result.session?.user != null) {
        setState(() {
          _user = result.session!.user;
          _activeModal = null;
        });
      }
    } catch (e) {
      setState(() => _authError = e.toString());
    }
  }

  void _handleSignIn(String email, String password) async {
    try {
      final result = await _repo.signIn(email, password);
      if (result.session?.user != null) {
        setState(() {
          _user = result.session!.user;
          _activeModal = null;
        });
      }
    } catch (e) {
      setState(() => _authError = e.toString());
    }
  }

  void _handleSignOut() async {
    await _repo.signOut();
    setState(() {
      _user = null;
      _messages = [];
      _currentChatId = null;
      _chatHistory = [];
      _memories = [];
      _activeModal = null;
    });
  }

  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _voiceStatus = 'Recording...';
    });
    try {
      await _audioService.startRecording();
    } catch (e) {
      setState(() {
        _voiceStatus = 'Microphone access denied.';
        _isRecording = false;
      });
    }
  }

  void _stopRecording() async {
    setState(() => _voiceStatus = 'Processing...');
    try {
      final base64 = await _audioService.stopRecording();
      if (base64 != null) {
        final transcription = await _gemini.transcribeAudio(
          base64,
          'audio/mp4',
        );
        if (transcription != null && transcription.isNotEmpty) {
          _sendMessage(transcription);
        } else {
          setState(() => _voiceStatus = null);
        }
      }
    } catch (e) {
      setState(() => _voiceStatus = 'Transcription failed.');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _voiceStatus = null);
      });
    }
    setState(() {
      _isRecording = false;
      _voiceStatus = null;
    });
  }

  // ---- Voice-to-voice (Live API) ----
  StreamSubscription? _pcmSub;
  String _liveModelText = ''; // model output transcription
  String _liveUserText = ''; // user input transcription
  bool _liveDisconnecting = false;
  int _liveAudioSampleRate = 24000;

  String _liveOpeningPastContext() {
    final parts = <String>[];
    final conversation = _conversationContext.trim();
    if (conversation.isNotEmpty) {
      parts.add('Recent conversation summary: $conversation');
    }
    for (final memory in _memories) {
      final category = memory['category']?.toString() ?? '';
      if (category != 'user_preference' && category != 'instruction') {
        continue;
      }
      final content = memory['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) parts.add(content);
      if (parts.length >= 4) break;
    }
    return parts.join('\n');
  }

  void _toggleVoiceMode() async {
    if (_liveDisconnecting) return;
    _liveOpeningTimer?.cancel();
    _liveOpeningTimer = null;
    _liveOpeningGate.reset();
    setState(() {
      _isVoiceOpen = true;
      _isLiveActive = false;
      _isSpeaking = false;
      _micInputLevel = 0;
      _lastMicVisualizerUpdateMicros = 0;
      _voiceStatus = 'Connecting...';
      _liveModelText = '';
      _liveUserText = '';
      _liveTranscription = '';
      _handledLiveToolCallIds.clear();
    });

    try {
      final permission = await MobileUseService().getStatus();
      if (permission.optionalPermissions['microphone'] != true) {
        final granted = await MobileUseService().requestOptionalPermission(
          'microphone',
        );
        if (!granted) {
          throw Exception(
            'Microphone permission was not granted. Voice remains off; '
            'enable Microphone from Beatrice setup when ready.',
          );
        }
      }
      final openingInstruction = VoiceOpeningService.buildOpeningInstruction(
        pastContext: _liveOpeningPastContext(),
        dailyBrief: _voiceOpening.cachedBriefForToday,
      );
      final systemInstruction =
          '${GeminiService.voicePersonalityPrompt}\n\n'
          '${LanguagePreferences.responseInstruction(_language)}\n\n'
          '${LiveApiService.secretaryHandoffInstruction}\n\n'
          'BACKGROUND LIMIT: After a verified task handoff, the visible '
          'Android task service may continue the accepted workflow when '
          'Beatrice is minimized. Do not imply that Live microphone or camera '
          'capture continues in the background, and do not promise recovery '
          'after force-stop or Android process termination.\n\n'
          '$openingInstruction';
      final stream = await _liveApi.connect(
        apiKey: _gemini.apiKey,
        model: GeminiService.models['live']!,
        systemInstruction: systemInstruction,
        voiceName: _voiceName,
      );
      unawaited(_audioService.prepareLivePlayback());

      stream.listen((event) {
        if (_liveDisconnecting) return;
        switch (event.type) {
          case LiveApiEventType.inputTranscription:
            // User speech: accumulate and surface as the live transcript.
            _liveOpeningGate.observeTranscription(event.text ?? '');
            _liveUserTurnActive = true;
            setState(() {
              _liveUserText += event.text ?? '';
              _liveTranscription = _liveUserText;
            });
          case LiveApiEventType.outputTranscription:
            // Model speech text.
            setState(() {
              _liveModelText += event.text ?? '';
              _liveTranscription = _liveModelText;
            });
          case LiveApiEventType.audioData:
            if (event.audioData != null) {
              _liveAudioSampleRate = event.sampleRate ?? 24000;
              unawaited(
                _audioService.streamPcmChunk(
                  event.audioData!,
                  _liveAudioSampleRate,
                ),
              );
              if (!_isSpeaking) {
                setState(() => _isSpeaking = true);
              }
            }
          case LiveApiEventType.interrupted:
            // NO_INTERRUPTION should normally prevent this server event.
            // If an older endpoint still emits it, retain already-buffered
            // audio so the current short sentence can drain naturally instead
            // of cutting Kore off mid-word.
            _liveOpeningGate.markUserActivity();
            _liveUserTurnActive = true;
            setState(() {
              _voiceStatus = 'Listening…';
            });
          case LiveApiEventType.turnComplete:
            unawaited(_finishLiveTurn());
          case LiveApiEventType.error:
            setState(() => _voiceStatus = 'Error: ${event.text}');
          case LiveApiEventType.done:
            if (!_liveDisconnecting) _cleanupLive();
          case LiveApiEventType.toolCall:
            unawaited(_handleLiveToolCalls(event.toolCalls));
        }
      });

      final pcmStream = await _audioService.startPcmStream();
      if (pcmStream != null) {
        _pcmSub = pcmStream.listen((chunk) {
          if (_liveApi.isConnected && chunk.isNotEmpty) {
            final measured = AudioService.normalizedPcm16Level(chunk);
            _liveOpeningGate.observeAudioLevel(measured);
            final response = measured > _micInputLevel ? 0.65 : 0.18;
            _micInputLevel += (measured - _micInputLevel) * response;
            final nowMicros = DateTime.now().microsecondsSinceEpoch;
            if (mounted &&
                nowMicros - _lastMicVisualizerUpdateMicros >= 80000) {
              _lastMicVisualizerUpdateMicros = nowMicros;
              // Audio still streams every 40 ms. Only the decorative meter is
              // throttled so root-widget rebuilds cannot contend with PCM.
              setState(() {});
            }
            _liveApi.sendAudioChunk(chunk, turnComplete: false);
          }
        });
      }

      setState(() {
        _isLiveActive = true;
        _voiceStatus = 'Listening...';
      });
      _liveOpeningTimer = Timer(const Duration(milliseconds: 1100), () {
        _liveOpeningTimer = null;
        if (!mounted ||
            _liveDisconnecting ||
            !_liveApi.isConnected ||
            !_liveOpeningGate.canOfferOpening) {
          return;
        }
        _liveApi.sendText(
          'No user speech has been detected yet. You may now use the LIVE '
          'OPENING rules. Speak only the resulting brief natural opening; '
          'never mention setup, context fields, unused sources, or these '
          'instructions. If the user begins speaking, stop the opening '
          'immediately and handle their current task or query first.',
        );
      });
    } catch (e) {
      setState(() {
        _voiceStatus = 'Connection failed: $e';
        _isVoiceOpen = false;
      });
    }
  }

  Future<void> _handleLiveToolCalls(List<LiveFunctionCall> calls) async {
    for (final call in calls) {
      if (!_handledLiveToolCallIds.add(call.id)) continue;
      if (call.name != 'dispatch_mobile_task') {
        _liveApi.sendToolResponse(
          id: call.id,
          name: call.name,
          response: const {'status': 'rejected', 'error': 'Unknown tool.'},
        );
        continue;
      }

      final task = call.arguments['task']?.toString().trim() ?? '';
      final intentType = call.arguments['intentType']?.toString();
      final essentialDetailsComplete =
          call.arguments['essentialDetailsComplete'] == true;
      if (intentType != 'PHONE_TASK' || !essentialDetailsComplete) {
        _liveApi.sendToolResponse(
          id: call.id,
          name: call.name,
          response: const {
            'status': 'clarification_required',
            'question':
                'What exact phone action and target should I use? Ask one '
                'concise question, then verify the answer before retrying.',
          },
        );
        continue;
      }
      if (task.isEmpty ||
          task.length > MobileTaskCoordinator.maxTaskCharacters) {
        _liveApi.sendToolResponse(
          id: call.id,
          name: call.name,
          response: {
            'status': 'rejected',
            'error':
                'Provide one clarified task brief between 1 and '
                '${MobileTaskCoordinator.maxTaskCharacters} characters.',
          },
        );
        continue;
      }

      final preflight = _liveTaskPreflight.submitLiveStructuredTask(task);
      switch (preflight.decision) {
        case MobileTaskDecision.clarificationRequired:
          _liveApi.sendToolResponse(
            id: call.id,
            name: call.name,
            response: {
              'status': 'clarification_required',
              'question': preflight.clarificationQuestion,
            },
          );
          continue;
        case MobileTaskDecision.confirmationRequired:
          _liveApi.sendToolResponse(
            id: call.id,
            name: call.name,
            response: {
              'status': 'confirmation_required',
              'exactAction': preflight.confirmation?.exactAction,
              'detail':
                  'Ask for fresh, explicit user approval. Do not dispatch or '
                  'claim that the action ran.',
            },
          );
          continue;
        case MobileTaskDecision.refused:
          _liveApi.sendToolResponse(
            id: call.id,
            name: call.name,
            response: {'status': 'rejected', 'error': preflight.explanation},
          );
          continue;
        case MobileTaskDecision.readyForLocalPlanning:
          break;
      }

      _mobileUseAgent.configureOllama(_ollama, _ollamaModel);
      _mobileUseAgent.configurePlannerProvider(_mobilePlannerProvider);
      try {
        // Start the visible Android foreground service before acknowledging
        // delivery. Android can reject a new service start after the user
        // minimizes Beatrice.
        await _mobileUseAgent.prepareLiveTaskForBackground(task);
      } catch (error) {
        final detail = error.toString().replaceFirst('Bad state: ', '');
        _liveApi.sendToolResponse(
          id: call.id,
          name: call.name,
          response: {'status': 'setup_required', 'error': detail},
        );
        if (mounted) setState(() => _voiceStatus = detail);
        continue;
      }

      _liveApi.sendToolResponse(
        id: call.id,
        name: call.name,
        response: const {
          'status': 'verified_and_delivered',
          'detail':
              'The app verified one actionable phone task and delivered the '
              'brief to the user-selected planner. The visible Android task '
              'service is active, so the accepted workflow may continue if '
              'the app is minimized. Live microphone and camera do not '
              'continue in the background. Do not claim task success; wait '
              'for coordinator-verified events.',
        },
      );
      if (mounted) {
        setState(() => _voiceStatus = 'Task received. Checking setup…');
      }
      unawaited(_runDispatchedLiveTask(task));
    }
  }

  Future<void> _runDispatchedLiveTask(String task) async {
    _mobileUseAgent.configureOllama(_ollama, _ollamaModel);
    _mobileUseAgent.configurePlannerProvider(_mobilePlannerProvider);
    final result = await _mobileUseAgent.planLiveStructuredTask(task);
    if (!_liveApi.isConnected || _liveDisconnecting) {
      if (!mounted) return;
      final message = Message(role: 'model', text: result);
      final status = await MobileUseService().getStatus();
      _lastRestoredRuntimeStatus =
          '${status.runtimeTaskState}|${status.runtimeTaskDetail}';
      if (!mounted) return;
      setState(() => _messages.add(message));
      unawaited(_saveMessageToDb(message));
      _scrollToBottom();
      return;
    }
    _liveApi.sendText(
      'Coordinator-verified task result: $result\n'
      'Tell the user this result in one brief, natural sentence. Do not add '
      'any action, success, or progress that is not explicitly stated. '
      'Speak in the selected language: $_language.',
    );
  }

  Future<void> _finishLiveTurn() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _isSpeaking = false);
    if (!mounted || _liveDisconnecting) return;
    _finalizeLiveTurn();
    _liveUserTurnActive = false;
    _flushPendingMobileVoiceEvent();
  }

  void _handleVerifiedMobileUseEvent(MobileUseWorkflowEvent event) {
    setState(() => _voiceStatus = event.spokenText);
    if (!_isLiveActive || !_liveApi.isConnected) return;
    final recentlySpoke =
        _lastMobileVoiceUpdate != null &&
        DateTime.now().difference(_lastMobileVoiceUpdate!) <
            const Duration(seconds: 3);
    if (_liveUserTurnActive || _isSpeaking || recentlySpoke) {
      if (event.type == MobileUseWorkflowEventType.actionVerified) {
        _pendingMobileVoiceEvents.removeWhere(
          (queued) => queued.type == MobileUseWorkflowEventType.actionVerified,
        );
      }
      _pendingMobileVoiceEvents.add(event);
      _scheduleMobileVoiceFlush();
      return;
    }
    _speakVerifiedMobileUseEvent(event);
  }

  void _flushPendingMobileVoiceEvent() {
    if (_pendingMobileVoiceEvents.isEmpty ||
        _liveUserTurnActive ||
        _isSpeaking ||
        !_liveApi.isConnected) {
      _scheduleMobileVoiceFlush();
      return;
    }
    final event = _pendingMobileVoiceEvents.removeLast();
    _pendingMobileVoiceEvents.clear();
    _handledLiveToolCallIds.clear();
    _speakVerifiedMobileUseEvent(event);
  }

  void _scheduleMobileVoiceFlush() {
    _mobileVoiceFlushTimer?.cancel();
    _mobileVoiceFlushTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _flushPendingMobileVoiceEvent();
    });
  }

  void _speakVerifiedMobileUseEvent(MobileUseWorkflowEvent event) {
    _lastMobileVoiceUpdate = DateTime.now();
    _liveApi.sendText(
      'Coordinator-verified workflow event: ${event.spokenText}\n'
      'As Beatrice, acknowledge this in one short, natural first-person '
      'sentence. Preserve the verified meaning exactly. Do not add actions, '
      'timing, success, or background progress that is not stated. Speak in '
      'the selected language: $_language.',
    );
  }

  void _finalizeLiveTurn() {
    final userText = _liveUserText.trim().isNotEmpty
        ? _liveUserText.trim()
        : '(voice input)';
    final modelText = _liveModelText.trim().isNotEmpty
        ? _liveModelText.trim()
        : '(voice response)';
    setState(() {
      _messages.add(Message(role: 'user', text: userText));
      _messages.add(Message(role: 'model', text: modelText));
    });
    _saveMessageToDb(Message(role: 'user', text: userText));
    _saveMessageToDb(Message(role: 'model', text: modelText));
    _scrollToBottom();
    _liveModelText = '';
    _liveUserText = '';
  }

  void _stopLiveSession() async {
    if (_liveDisconnecting) return;
    _liveDisconnecting = true;
    _liveOpeningTimer?.cancel();
    _liveOpeningTimer = null;

    setState(() {
      _voiceStatus = 'Finishing...';
      _isSpeaking = false;
      _micInputLevel = 0;
      _lastMicVisualizerUpdateMicros = 0;
    });

    await _pcmSub?.cancel();
    _pcmSub = null;
    await _audioService.stopStream();
    await _audioService.stopPlayback();

    await Future.delayed(const Duration(milliseconds: 300));

    if (_liveApi.isConnected) {
      _liveApi.sendAudioChunk(Uint8List(0), turnComplete: true);
      await Future.delayed(const Duration(seconds: 2));
    }

    _liveApi.disconnect();
    _liveDisconnecting = false;

    if (_liveModelText.trim().isNotEmpty || _liveUserText.trim().isNotEmpty) {
      _finalizeLiveTurn();
    }

    _cleanupLive();
  }

  void _cleanupLive() {
    unawaited(_stopLiveCamera());
    _liveOpeningTimer?.cancel();
    _liveOpeningTimer = null;
    _liveOpeningGate.reset();
    _pcmSub?.cancel();
    _pcmSub = null;
    _liveApi.disconnect();
    _pendingMobileVoiceEvents.clear();
    _mobileVoiceFlushTimer?.cancel();
    _mobileVoiceFlushTimer = null;
    _liveUserTurnActive = false;
    _lastMobileVoiceUpdate = null;
    _liveDisconnecting = false;
    setState(() {
      _isVoiceOpen = false;
      _isLiveActive = false;
      _isSpeaking = false;
      _micInputLevel = 0;
      _lastMicVisualizerUpdateMicros = 0;
      _liveTranscription = '';
      _liveModelText = '';
      _liveUserText = '';
      _voiceStatus = null;
    });
  }

  Future<void> _suspendLiveCaptureForBackground() async {
    if (_backgroundLiveShutdown || (!_isVoiceOpen && !_isLiveActive)) return;
    _backgroundLiveShutdown = true;
    _liveDisconnecting = true;
    try {
      // A task already handed to MobileUseAgent continues through the visible
      // foreground service. Gemini microphone/camera capture does not.
      _liveOpeningTimer?.cancel();
      _liveOpeningTimer = null;
      _liveCameraTimer?.cancel();
      _liveCameraTimer = null;
      await _stopLiveCamera();
      await _pcmSub?.cancel();
      _pcmSub = null;
      await _audioService.stopStream();
      await _audioService.stopPlayback();
      _liveApi.disconnect();
      if (mounted) {
        _cleanupLive();
      } else {
        _liveDisconnecting = false;
      }
      debugPrint(
        'Beatrice Live capture stopped because the app left the foreground; '
        'any accepted MobileUseAgent task remains active.',
      );
    } finally {
      _backgroundLiveShutdown = false;
    }
  }

  Future<void> _restoreRuntimeStatus() async {
    try {
      final status = await MobileUseService().getStatus();
      if (!mounted) return;
      final state = status.runtimeTaskState;
      if (state == 'active' || state == 'starting' || state == 'planning') {
        setState(() => _voiceStatus = status.runtimeTaskDetail);
        return;
      }
      if (!const {
        'completed',
        'failed',
        'interrupted',
        'waiting_confirmation',
      }.contains(state)) {
        return;
      }
      final marker = '$state|${status.runtimeTaskDetail}';
      if (_lastRestoredRuntimeStatus == marker) return;
      _lastRestoredRuntimeStatus = marker;
      final message = Message(
        role: 'model',
        text: 'Mobile task status: ${status.runtimeTaskDetail}',
      );
      setState(() => _messages.add(message));
      if (_isInitialized) unawaited(_saveMessageToDb(message));
      _scrollToBottom();
    } catch (error) {
      debugPrint('Unable to restore MobileUseAgent status: $error');
    }
  }

  Future<void> _toggleLiveCamera() async {
    if (_isLiveCameraActive) {
      await _stopLiveCamera();
      return;
    }
    if (!_isLiveActive || !_liveApi.isConnected) {
      setState(() => _voiceStatus = 'Start Live Voice before sharing camera.');
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera is available.');
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      _liveCamera = controller;
      setState(() {
        _isLiveCameraActive = true;
        _voiceStatus =
            'Camera active. Low-rate frames are sent online to Gemini only '
            'during this visible Live session.';
      });
      _liveCameraTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_sendLiveCameraFrame());
      });
      await _sendLiveCameraFrame();
    } on CameraException catch (error) {
      await _stopLiveCamera();
      if (mounted) {
        setState(
          () => _voiceStatus = error.code == 'CameraAccessDenied'
              ? 'Camera permission was denied. Camera sharing remains off.'
              : 'Camera could not start: ${error.description ?? error.code}',
        );
      }
    } catch (error) {
      await _stopLiveCamera();
      if (mounted) {
        setState(() => _voiceStatus = 'Camera could not start: $error');
      }
    }
  }

  Future<void> _switchLiveCamera() async {
    final current = _liveCamera;
    if (!_isLiveCameraActive || current == null || _liveCameraCapturing) {
      return;
    }
    try {
      final cameras = await availableCameras();
      final desired =
          current.description.lensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      CameraDescription? replacement;
      for (final camera in cameras) {
        if (camera.lensDirection == desired) {
          replacement = camera;
          break;
        }
      }
      if (replacement == null) {
        setState(() => _voiceStatus = 'No alternate camera is available.');
        return;
      }
      _liveCameraTimer?.cancel();
      _liveCameraTimer = null;
      await current.dispose();
      final controller = CameraController(
        replacement,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!_isLiveActive || !_liveApi.isConnected) {
        await controller.dispose();
        return;
      }
      _liveCamera = controller;
      _liveCameraTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_sendLiveCameraFrame());
      });
      if (mounted) {
        setState(
          () => _voiceStatus =
              '${desired == CameraLensDirection.front ? 'Front' : 'Back'} '
              'camera active and shared with Gemini Live.',
        );
      }
      await _sendLiveCameraFrame();
    } catch (error) {
      if (mounted) {
        setState(() => _voiceStatus = 'Could not switch camera: $error');
      }
    }
  }

  Future<void> _sendLiveCameraFrame() async {
    final controller = _liveCamera;
    if (!_isLiveCameraActive ||
        _liveCameraCapturing ||
        controller == null ||
        !controller.value.isInitialized ||
        !_isLiveActive ||
        !_liveApi.isConnected) {
      return;
    }
    _liveCameraCapturing = true;
    try {
      final frame = await controller.takePicture();
      if (_isLiveCameraActive && _liveApi.isConnected) {
        _liveApi.sendVideoFrame(await frame.readAsBytes());
      }
      try {
        await File(frame.path).delete();
      } catch (_) {}
    } catch (error) {
      debugPrint('Live camera frame failed: $error');
    } finally {
      _liveCameraCapturing = false;
    }
  }

  Future<void> _stopLiveCamera() async {
    _liveCameraTimer?.cancel();
    _liveCameraTimer = null;
    final controller = _liveCamera;
    _liveCamera = null;
    if (controller != null) await controller.dispose();
    if (mounted) setState(() => _isLiveCameraActive = false);
  }

  void _openSidebar() => setState(() => _isSidebarOpen = true);
  void _closeSidebar() => setState(() => _isSidebarOpen = false);
  void _openAttachmentSheet() => setState(() => _isAttachmentSheetOpen = true);
  void _closeAttachmentSheet() =>
      setState(() => _isAttachmentSheetOpen = false);

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1920);
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _taskMode = false;
        _pendingVisionImage = bytes;
        _pendingVisionImageName = file.name;
        _voiceStatus =
            'Image selected for Chat. Add a question and send. The image '
            'stays local and requires an Ollama vision model such as Gemma 3.';
      });
      _closeAttachmentSheet();
    } else {
      _closeAttachmentSheet();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _inputController.dispose();
    _audioService.dispose();
    _liveCameraTimer?.cancel();
    _liveCamera?.dispose();
    _mobileUseEventSub?.cancel();
    _mobileVoiceFlushTimer?.cancel();
    super.dispose();
  }

  ThemeData get _resolvedTheme => AppTheme.resolve(
    _theme,
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeatriceVoice',
      debugShowCheckedModeBanner: false,
      theme: _resolvedTheme,
      home: Scaffold(backgroundColor: AppColors.zinc900, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // Centered phone-frame surface, mirroring the root app's max-w-md shell.
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 448),
        decoration: const BoxDecoration(
          color: AppColors.black,
          boxShadow: [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 40,
              spreadRadius: 0,
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.only(top: 4, bottom: 24),
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _messages.isEmpty
                        ? const HomeScreen()
                        : _buildChatMessages(),
                  ),
                  _buildInput(),
                ],
              ),
              if (_isVoiceOpen)
                VoiceScreen(
                  isLiveActive: _isLiveActive,
                  isSpeaking: _isSpeaking,
                  liveTranscription: _liveTranscription,
                  micInputLevel: _micInputLevel,
                  onStop: _stopLiveSession,
                  isCameraActive: _isLiveCameraActive,
                  onToggleCamera: _toggleLiveCamera,
                  onSwitchCamera: _switchLiveCamera,
                  cameraController: _liveCamera,
                ),
              if (_isSidebarOpen) _buildSidebarOverlay(),
              if (_isAttachmentSheetOpen) _buildAttachmentOverlay(),
              if (_activeModal != null) _buildModalOverlay(),
              if (_showHeaderMenu) _buildHeaderMenu(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatMessages() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 96, 16, 96),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Beatrice is thinking...',
                  style: TextStyle(color: AppColors.neutral400, fontSize: 14),
                ),
              ],
            ),
          );
        }
        final msg = _messages[index];
        return MessageBubble(message: msg, isUser: msg.role == 'user');
      },
    );
  }

  // ---- Header ----
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _openSidebar,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.chip2121,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.menu, color: AppColors.white, size: 22),
            ),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: AppColors.chip2121,
              shape: BoxShape.circle,
            ),
            child: Row(
              children: [
                _modeButton(
                  icon: Icons.bolt,
                  isActive: _isFastMode,
                  activeColor: AppColors.emerald,
                  onTap: () => setState(() => _isFastMode = !_isFastMode),
                ),
                const SizedBox(width: 4),
                _modeButton(
                  icon: Icons.psychology,
                  isActive: _isThinking,
                  activeColor: AppColors.blue,
                  onTap: () => setState(() => _isThinking = !_isThinking),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showHeaderMenu = !_showHeaderMenu),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: Icon(
                        Icons.more_horiz,
                        color: AppColors.neutral300,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? activeColor : AppColors.neutral300,
        ),
      ),
    );
  }

  // ---- Input bar ----
  Widget _buildInput() {
    final hasText = _inputController.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, AppColors.black],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_voiceStatus != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.neutral600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _voiceStatus!,
                style: const TextStyle(color: AppColors.white, fontSize: 12),
              ),
            ),
          if (_showImageSettings) _buildImageGenPopover(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _openAttachmentSheet,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.chip2121,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    color: AppColors.neutral300,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: BoxDecoration(
                    color: AppColors.chip2121,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      PopupMenuButton<bool>(
                        tooltip: 'Choose Chat or Task mode',
                        initialValue: _taskMode,
                        onSelected: (task) async {
                          setState(() {
                            _taskMode = task;
                            if (task) {
                              _webToolEnabled = false;
                              _pendingVisionImage = null;
                              _pendingVisionImageName = null;
                              _ocrToolEnabled = false;
                            }
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('eburon_chatTaskMode', task);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: false,
                            child: Text('Chat · local conversation'),
                          ),
                          PopupMenuItem(
                            value: true,
                            child: Text('Task · phone automation'),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _taskMode ? 'Task' : 'Chat',
                                style: const TextStyle(
                                  color: AppColors.neutral300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: AppColors.neutral400,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(
                          () => _showImageSettings = !_showImageSettings,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 4,
                            right: 4,
                            top: 6,
                            bottom: 6,
                          ),
                          child: Icon(
                            Icons.brush,
                            size: 18,
                            color: _showImageSettings
                                ? AppColors.purple
                                : AppColors.neutral500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          onChanged: (_) => setState(() {}),
                          maxLines: 4,
                          minLines: 1,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: _showImageSettings
                                ? 'Describe the image you want to create...'
                                : 'Ask Beatrice AI',
                            hintStyle: const TextStyle(
                              color: AppColors.neutral400,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.only(
                              left: 8,
                              top: 4,
                              bottom: 4,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (v) {
                            if (v.trim().isNotEmpty) _sendMessage(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (_isLoading) ...[
                Container(
                  width: 28,
                  height: 28,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [AppColors.blue, AppColors.purple],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.blue.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              hasText
                  ? GestureDetector(
                      onTap: () => _sendMessage(_inputController.text),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: AppColors.black,
                          size: 18,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTapDown: (_) => _startRecording(),
                          onTapUp: (_) => _stopRecording(),
                          onTapCancel: () => _stopRecording(),
                          child: Icon(
                            _isRecording ? Icons.stop : Icons.mic,
                            size: 20,
                            color: _isRecording
                                ? AppColors.red
                                : AppColors.neutral400,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _toggleVoiceMode,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.graphic_eq,
                              color: AppColors.black,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickChatVisionImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 90,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pendingVisionImage = bytes;
      _pendingVisionImageName = file.name;
      _voiceStatus =
          'Image selected. It stays local and is sent only to the selected '
          'Ollama model when you send this Chat message.';
    });
  }

  Future<void> _configureOrSelectOcrDocument() async {
    if (!_ocrEnglishReady) {
      final install = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set up local English OCR'),
          content: const Text(
            'Select the official Tesseract file named eng.traineddata. It is '
            'copied into Beatrice private storage and never uploaded.\n\n'
            'Initial support is image documents (PNG, JPEG, WebP, BMP). PDF, '
            'DOCX, and other document formats are not read in this version.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Select eng.traineddata'),
            ),
          ],
        ),
      );
      if (install != true) return;
      try {
        final installed = await _localOcr.importEnglishData();
        if (!installed || !mounted) return;
        setState(() => _ocrEnglishReady = true);
      } catch (error) {
        if (mounted) setState(() => _voiceStatus = 'OCR setup failed: $error');
        return;
      }
    }
    try {
      final selected = await _localOcr.pickImageDocument();
      if (selected == null || !mounted) return;
      setState(() {
        _pendingVisionImage = selected.bytes;
        _pendingVisionImageName = selected.name;
        _ocrToolEnabled = true;
        _voiceStatus =
            'Local OCR document selected. Add a question and send. Tesseract '
            'runs only if Ollama requests extract_text; nothing is uploaded.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _voiceStatus = 'OCR selection failed: $error');
      }
    }
  }

  Future<void> _selectTaskStarter(String prompt) async {
    _closeAttachmentSheet();
    setState(() {
      _taskMode = true;
      _webToolEnabled = false;
      _pendingVisionImage = null;
      _pendingVisionImageName = null;
      _ocrToolEnabled = false;
      _showImageSettings = false;
      _inputController
        ..text = prompt
        ..selection = TextSelection.collapsed(offset: prompt.length);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eburon_chatTaskMode', true);
  }

  Widget _buildImageGenPopover() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(Icons.image, size: 14, color: AppColors.purple),
                const SizedBox(width: 4),
                const Text(
                  'Image Gen',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutral400,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(height: 16, width: 1, color: AppColors.divider),
                const SizedBox(width: 8),
                _popoverSelect(
                  ['1K', '2K', '4K'],
                  _imageSize,
                  (v) => setState(() => _imageSize = v),
                ),
                const SizedBox(width: 4),
                _popoverSelect(
                  ['1:1', '16:9', '9:16', '4:3', '3:4'],
                  _imageAspect,
                  (v) => setState(() => _imageAspect = v),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _showImageSettings = false),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.neutral500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _popoverSelect(
    List<String> options,
    String value,
    ValueChanged<String> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(9999)),
      child: DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 11, color: AppColors.white),
        dropdownColor: AppColors.card1a,
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  // ---- Overlays ----
  Widget _buildHeaderMenu() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _showHeaderMenu = false),
          child: const SizedBox.expand(),
        ),
        Positioned(
          top: 92,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 192,
              decoration: BoxDecoration(
                color: AppColors.card1a,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.red400,
                    ),
                    title: const Text(
                      'Clear Chat',
                      style: TextStyle(color: AppColors.red400, fontSize: 14),
                    ),
                    onTap: _clearChat,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _closeSidebar,
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Sidebar(
            chatHistory: _chatHistory,
            currentChatId: _currentChatId,
            onNewChat: () async => _createNewChat(),
            onLoadChat: _loadChat,
            onDeleteChat: _deleteChat,
            onClose: _closeSidebar,
            onAccount: () {
              _closeSidebar();
              setState(() => _activeModal = 'account');
            },
            onSettings: () {
              _closeSidebar();
              setState(() => _activeModal = 'settings');
            },
            onMobileUseAgent: () {
              _closeSidebar();
              setState(() => _activeModal = 'mobileUseAgent');
            },
            onSignOut: _handleSignOut,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: _closeAttachmentSheet,
          child: Container(color: Colors.black.withValues(alpha: 0.6)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AttachmentSheet(
            onCamera: () => _pickImage(ImageSource.camera),
            onPhotos: () => _pickImage(ImageSource.gallery),
            onFiles: () {
              _closeAttachmentSheet();
              _configureOrSelectOcrDocument();
            },
            onCreateImage: () {
              _closeAttachmentSheet();
              setState(() => _showImageSettings = true);
            },
            webLookupEnabled: _webToolEnabled,
            onToggleWebLookup: () {
              setState(() => _webToolEnabled = !_webToolEnabled);
            },
            visionImageReady: _pendingVisionImageName != null,
            onVisionImage: () {
              _closeAttachmentSheet();
              _pickChatVisionImage();
            },
            ocrReady: _ocrEnglishReady,
            ocrSelected: _ocrToolEnabled,
            onOcrDocument: () {
              _closeAttachmentSheet();
              _configureOrSelectOcrDocument();
            },
            onStudy: () {
              _closeAttachmentSheet();
              _sendMessage('Teach me a new concept about...');
            },
            onAgentMode: () {
              _closeAttachmentSheet();
              _sendMessage('Activate agent mode to help me format...');
            },
            onTaskStarter: (prompt) => unawaited(_selectTaskStarter(prompt)),
            onClose: _closeAttachmentSheet,
          ),
        ),
      ],
    );
  }

  Widget _buildModalOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => setState(() => _activeModal = null),
          child: Container(color: AppColors.surface0a),
        ),
        Positioned.fill(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _activeModal == 'account'
                          ? 'Account Settings'
                          : _activeModal == 'mobileUseAgent'
                          ? 'Beatrice mobile setup'
                          : 'Settings',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _activeModal = null),
                      child: const Icon(
                        Icons.close,
                        color: AppColors.neutral400,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _activeModal == 'account'
                    ? _buildAccountScreen()
                    : _activeModal == 'mobileUseAgent'
                    ? MobileUseSetupScreen(
                        ollamaService: _ollama,
                        selectedModel: _ollamaModel,
                        ollamaProvider: _ollamaProvider,
                        plannerProvider: _mobilePlannerProvider,
                        geminiApiKey: _geminiPlannerApiKey,
                        groqApiKey: _groqPlannerApiKey,
                        geminiModel: _geminiPlannerModel,
                        groqModel: _groqPlannerModel,
                        onModelChanged: (model) =>
                            unawaited(_changeSelectedOllamaModel(model)),
                        onPlannerProviderChanged: (provider) =>
                            unawaited(_changeMobilePlannerProvider(provider)),
                        onHostedPlannerSettingsSaved:
                            _saveHostedPlannerSettings,
                      )
                    : SettingsScreen(
                        key: ValueKey(_ollamaProvider),
                        userContext: _userContext,
                        responseStyle: _responseStyle,
                        language: _language,
                        theme: _theme,
                        voiceName: _voiceName,
                        ollamaModel: _ollamaModel,
                        ollamaBaseUrl: _ollamaBaseUrl,
                        ollamaProvider: _ollamaProvider,
                        ollamaCloudApiKey: _ollamaCloudApiKey,
                        ollamaService: _ollama,
                        openCodeService: _openCode,
                        openCodeUrl: _openCodeUrl,
                        onOpenCodeUrlChanged: (v) {
                          setState(() => _openCodeUrl = v);
                          _openCode.baseUrl = v;
                        },
                        onUserContextChanged: (v) =>
                            setState(() => _userContext = v),
                        onResponseStyleChanged: (v) =>
                            setState(() => _responseStyle = v),
                        onLanguageChanged: (v) => setState(
                          () => _language = LanguagePreferences.normalize(v),
                        ),
                        onVoiceChanged: (v) => _changeVoice(v),
                        onOllamaModelChanged: (v) =>
                            unawaited(_changeSelectedOllamaModel(v)),
                        onOllamaBaseUrlChanged: (v) {
                          setState(() => _ollamaBaseUrl = v);
                          if (_ollamaProvider == 'local') {
                            _configureSelectedOllama();
                          }
                        },
                        onOllamaProviderChanged: (v) =>
                            unawaited(_changeOllamaProvider(v)),
                        onOllamaCloudApiKeyChanged: (v) =>
                            unawaited(_changeOllamaCloudKey(v)),
                        onThemeChanged: (v) => setState(() => _theme = v),
                        onSave: () async {
                          await _profileService.saveLocalSettings(
                            userContext: _userContext,
                            responseStyle: _responseStyle,
                            language: _language,
                            theme: _theme,
                            ollamaModel: _localOllamaModel,
                            ollamaBaseUrl: _ollamaBaseUrl,
                          );
                          await _autoSaveProfile();
                          setState(() => _activeModal = null);
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountScreen() {
    if (_user != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.blueBg,
              child: Text(
                (_user!.email ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'User Account',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _user!.email ?? '',
              style: const TextStyle(color: AppColors.neutral400, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Subscription',
                style: TextStyle(color: AppColors.neutral400, fontSize: 13),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Beatrice Plus (Active)',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSignOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red.withValues(alpha: 0.1),
                  foregroundColor: AppColors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AuthScreen(
      onSignIn: _handleSignIn,
      onSignUp: _handleSignUp,
      error: _authError,
    );
  }
}
