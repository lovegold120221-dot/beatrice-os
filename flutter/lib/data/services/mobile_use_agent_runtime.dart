import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'mobile_planner_provider.dart';
import 'mobile_task_coordinator.dart';
import 'mobile_use_service.dart';
import 'ollama_service.dart';

enum MobileUseWorkflowEventType {
  accepted,
  clarificationNeeded,
  planning,
  actionVerified,
  approvalRequired,
  completed,
  cancelled,
  failed,
}

/// A user-facing event backed by coordinator/tool state. Beatrice may narrate
/// this text, but must never invent additional progress.
class MobileUseWorkflowEvent {
  final MobileUseWorkflowEventType type;
  final String spokenText;

  const MobileUseWorkflowEvent(this.type, this.spokenText);
}

enum PlannerCommandKind {
  action,
  askForClarification,
  requestConfirmation,
  complete,
}

class PlannerCommand {
  final PlannerCommandKind kind;
  final String? action;
  final Map<String, dynamic> arguments;
  final String message;

  const PlannerCommand({
    required this.kind,
    this.action,
    this.arguments = const {},
    this.message = '',
  });

  static PlannerCommand parse(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('Expected one JSON object and no prose.');
    }
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map) {
      throw const FormatException('Command is not an object.');
    }
    final kindValue = decoded['kind']?.toString();
    final kind = switch (kindValue) {
      'action' => PlannerCommandKind.action,
      'ask_for_clarification' => PlannerCommandKind.askForClarification,
      'request_confirmation' => PlannerCommandKind.requestConfirmation,
      'complete' => PlannerCommandKind.complete,
      _ => throw FormatException('Unknown command kind: $kindValue'),
    };
    final arguments = decoded['arguments'];
    if (arguments != null && arguments is! Map) {
      throw const FormatException('arguments must be a JSON object.');
    }
    return PlannerCommand(
      kind: kind,
      action: decoded['action']?.toString(),
      arguments: arguments == null
          ? const {}
          : Map<String, dynamic>.from(arguments),
      message: (decoded['message']?.toString() ?? '').trim(),
    );
  }
}

class PendingTaskRetry {
  final String task;
  final MobileTaskSource source;

  const PendingTaskRetry(this.task, this.source);
}

class PendingTaskRetryGate {
  PendingTaskRetry? _pending;
  DateTime? _expiresAt;

  void offer(String task, MobileTaskSource source, {DateTime? now}) {
    _pending = PendingTaskRetry(task, source);
    _expiresAt = (now ?? DateTime.now()).add(const Duration(minutes: 2));
  }

  PendingTaskRetry? consumeAffirmative(String reply, {DateTime? now}) {
    const affirmatives = {
      'yes',
      'yes please',
      'please do',
      'try again',
      'retry',
      'go ahead and retry',
    };
    if (!affirmatives.contains(reply.trim().toLowerCase()) ||
        _pending == null ||
        _expiresAt == null ||
        !(now ?? DateTime.now()).isBefore(_expiresAt!)) {
      return null;
    }
    final value = _pending;
    clear();
    return value;
  }

  bool isAffirmative(String reply) => const {
    'yes',
    'yes please',
    'please do',
    'try again',
    'retry',
    'go ahead and retry',
  }.contains(reply.trim().toLowerCase());

  void clear() {
    _pending = null;
    _expiresAt = null;
  }
}

class MobileActionPolicy {
  static bool requiresConfirmation(
    String action,
    Map<String, dynamic> arguments,
  ) {
    final value = '$action ${jsonEncode(arguments)}'.toLowerCase();
    const consequentialTerms = [
      'send',
      'submit',
      'purchase',
      'buy',
      'pay',
      'delete',
      'call',
      'post',
      'publish',
      'password',
      'security',
      'account setting',
    ];
    return consequentialTerms.any(value.contains);
  }
}

class MobileUseAgentRuntime {
  MobileUseAgentRuntime._() {
    _native.runtimeStopEvents.listen((reason) {
      if (!_taskRunning) return;
      final cancelledGeneration = _taskGeneration;
      _cancelRequested = true;
      _taskGeneration++;
      _retryGate.clear();
      _cancelEventGeneration = cancelledGeneration;
      _events.add(
        MobileUseWorkflowEvent(
          MobileUseWorkflowEventType.cancelled,
          'I stopped the mobile task because you cancelled it.',
        ),
      );
      debugPrint('MobileUseAgent: native runtime stopped: $reason');
    });
  }

  static final MobileUseAgentRuntime instance = MobileUseAgentRuntime._();
  static const allowedActions = {
    'launch_app',
    'click_text',
    'set_text',
    'tap',
    'swipe',
    'back',
    'home',
    'wait',
  };
  static const allowedAppPackages = {
    'com.google.android.youtube',
    'com.google.android.gm',
    'com.android.chrome',
    'com.android.settings',
    'com.google.android.apps.messaging',
    'com.whatsapp',
    'com.whatsapp.w4b',
  };

  static bool shouldAbortBeforeAction({
    required bool cancelRequested,
    required bool runtimeRunning,
    required int taskGeneration,
    required int currentGeneration,
  }) =>
      cancelRequested || !runtimeRunning || taskGeneration != currentGeneration;

  final MobileUseService _native = MobileUseService();
  final MobileTaskCoordinator _coordinator = MobileTaskCoordinator();
  final StreamController<MobileUseWorkflowEvent> _events =
      StreamController<MobileUseWorkflowEvent>.broadcast();
  OllamaService? _ollama;
  String _ollamaModel = '';
  String _plannerProviderId = MobilePlannerProviders.ollamaLocal;
  bool _cancelRequested = false;
  bool _taskRunning = false;
  int _taskGeneration = 0;
  int? _cancelEventGeneration;
  final PendingTaskRetryGate _retryGate = PendingTaskRetryGate();

  Stream<MobileUseWorkflowEvent> get verifiedEvents => _events.stream;
  bool get isTaskRunning => _taskRunning;

  void configureOllama(OllamaService service, String model) {
    _ollama = service;
    _ollamaModel = model.trim();
  }

  void configurePlannerProvider(String providerId) {
    _plannerProviderId = MobilePlannerProviders.byId(providerId).id;
  }

  void cancelCurrentTask() {
    _cancelRequested = true;
    _taskGeneration++;
    _retryGate.clear();
  }

  /// Starts the user-visible foreground runtime while Beatrice is still
  /// visible, before Gemini is told that a Live task was delivered. Android
  /// may reject a new foreground-service start after the app is backgrounded.
  Future<void> prepareLiveTaskForBackground(String task) async {
    if (_taskRunning) {
      throw StateError(
        'Another MobileUseAgent task is already running. Stop it or wait for '
        'it to finish before starting a new task.',
      );
    }
    await _ensureNativeRuntime(task, state: 'starting');
  }

  Future<String> planTypedTask(String text) =>
      _dispatchWithRetryGate(text, MobileTaskSource.chat);

  Future<String> planLiveStructuredTask(String compactStructuredTask) =>
      _dispatchWithRetryGate(
        compactStructuredTask,
        MobileTaskSource.liveVoiceTranslation,
      );

  Future<String> _dispatchWithRetryGate(
    String input,
    MobileTaskSource source,
  ) async {
    final retry = _retryGate.consumeAffirmative(input);
    if (retry != null) return _runTask(retry.task, retry.source);
    if (_retryGate.isAffirmative(input)) {
      return 'What task would you like me to do? There is no failed task '
          'currently waiting for retry approval.';
    }
    try {
      return await _runTask(input, source);
    } catch (error) {
      return _recordFailure(input, source, error.toString());
    }
  }

  Future<String> _runTask(String input, MobileTaskSource source) async {
    if (_taskRunning) {
      return 'Another MobileUseAgent task is already running. Stop it or wait '
          'for it to finish before starting a new task.';
    }
    _taskRunning = true;
    _cancelRequested = false;
    final generation = ++_taskGeneration;
    try {
      return await _runTaskSession(input, source, generation);
    } finally {
      _taskRunning = false;
    }
  }

  Future<String> _runTaskSession(
    String input,
    MobileTaskSource source,
    int generation,
  ) async {
    final review = source == MobileTaskSource.chat
        ? _coordinator.submitTypedTask(input)
        : _coordinator.submitLiveStructuredTask(input);
    if (review.decision == MobileTaskDecision.refused) {
      return 'I did not start this task: ${review.explanation}';
    }
    if (review.decision == MobileTaskDecision.clarificationRequired) {
      final question = review.clarificationQuestion!;
      _events.add(
        MobileUseWorkflowEvent(
          MobileUseWorkflowEventType.clarificationNeeded,
          question,
        ),
      );
      return question;
    }
    if (review.decision == MobileTaskDecision.confirmationRequired) {
      final exactAction = review.confirmation!.exactAction;
      _events.add(
        MobileUseWorkflowEvent(
          MobileUseWorkflowEventType.approvalRequired,
          'I need your approval before I $exactAction.',
        ),
      );
      return 'Fresh confirmation required before: $exactAction\n'
          'Nothing has been executed.';
    }

    await _ensureNativeRuntime(review.proposal.objective);
    _events.add(
      const MobileUseWorkflowEvent(
        MobileUseWorkflowEventType.planning,
        'I am connecting to the selected MobileUseAgent planner for this task.',
      ),
    );
    await _ensureOllamaPlanner();
    await _native.updateRuntimeTaskState(
      'active',
      'Working on: ${_boundedStatus(review.proposal.objective)}',
    );
    _events.add(
      const MobileUseWorkflowEvent(
        MobileUseWorkflowEventType.accepted,
        'I understood the task and am starting the approved workflow.',
      ),
    );

    Map<String, dynamic> previousResult = const {};
    for (var step = 0; step < MobileTaskCoordinator.maxPlanningSteps; step++) {
      if (await _shouldCancel(generation)) {
        return _cancelledResult(generation);
      }
      final observation = _sanitizeObservation(await _native.readScreen());
      final command = await _nextCommand(
        task: review.proposal.objective,
        observation: observation,
        previousResult: previousResult,
        step: step,
      );
      // Stop may arrive while Ollama is generating for up to 90 seconds.
      // Re-check before interpreting or executing the returned command so a
      // cancelled task can never perform one final native action.
      if (await _shouldCancel(generation)) {
        return _cancelledResult(generation);
      }
      switch (command.kind) {
        case PlannerCommandKind.askForClarification:
          final question = command.message.isEmpty
              ? 'What detail should I use to continue?'
              : command.message;
          _events.add(
            MobileUseWorkflowEvent(
              MobileUseWorkflowEventType.clarificationNeeded,
              question,
            ),
          );
          await _native.updateRuntimeTaskState(
            'waiting_confirmation',
            _boundedStatus(question),
          );
          return question;
        case PlannerCommandKind.requestConfirmation:
          final detail = command.message.isEmpty
              ? 'the proposed consequential action'
              : command.message;
          _events.add(
            MobileUseWorkflowEvent(
              MobileUseWorkflowEventType.approvalRequired,
              'I need your approval before $detail.',
            ),
          );
          await _native.updateRuntimeTaskState(
            'waiting_confirmation',
            _boundedStatus(detail),
          );
          return 'Fresh confirmation required before $detail. '
              'The action has not run.';
        case PlannerCommandKind.complete:
          final outcome = command.message.isEmpty
              ? 'The verified workflow is complete.'
              : command.message;
          _events.add(
            MobileUseWorkflowEvent(
              MobileUseWorkflowEventType.completed,
              outcome,
            ),
          );
          await _native.updateRuntimeTaskState(
            'completed',
            _boundedStatus(outcome),
          );
          return outcome;
        case PlannerCommandKind.action:
          _validateAction(command);
          if (MobileActionPolicy.requiresConfirmation(
            command.action!,
            command.arguments,
          )) {
            final detail = '${command.action} ${jsonEncode(command.arguments)}';
            _events.add(
              MobileUseWorkflowEvent(
                MobileUseWorkflowEventType.approvalRequired,
                'I need your approval before the final action.',
              ),
            );
            await _native.updateRuntimeTaskState(
              'waiting_confirmation',
              'Approval required for the final action',
            );
            return 'Fresh confirmation required before $detail. '
                'The action has not run.';
          }
          if (await _shouldCancel(generation)) {
            return _cancelledResult(generation);
          }
          final succeeded = await _native.executeAction(
            command.action!,
            command.arguments,
          );
          if (await _shouldCancel(generation)) {
            return _cancelledResult(generation);
          }
          final verifiedObservation = _sanitizeObservation(
            await _native.readScreen(),
          );
          previousResult = {
            'action': command.action,
            'succeeded': succeeded,
            'verifiedObservation': verifiedObservation,
          };
          if (!succeeded) {
            return _recordFailure(
              review.proposal.objective,
              source,
              'The allowlisted action at step ${step + 1} failed or could '
              'not be verified.',
            );
          }
          _events.add(
            MobileUseWorkflowEvent(
              MobileUseWorkflowEventType.actionVerified,
              'I verified workflow step ${step + 1}.',
            ),
          );
          await _native.updateRuntimeTaskState(
            'active',
            'Verified step ${step + 1} of at most 50',
          );
      }
    }
    await _native.updateRuntimeTaskState(
      'failed',
      'Stopped at the 50-step safety limit',
    );
    return 'The workflow reached the hard 50-step limit and stopped safely.';
  }

  Future<void> _ensureNativeRuntime(
    String task, {
    String state = 'active',
  }) async {
    final osStatus = await _native.getStatus();
    if (!osStatus.accessibilityEnabled || !osStatus.accessibilityConnected) {
      throw StateError(
        'Android Accessibility is not enabled. Open the left menu → '
        'Beatrice setup → Set up Accessibility in Android Settings, enable '
        '“Beatrice mobile control,” then return and retry.',
      );
    }
    if (!osStatus.runtimeRunning) {
      // This call must happen while the task dispatch is still user-visible.
      // Accessibility itself is never enabled here.
      await _native.startRuntime();
      var running = false;
      for (var attempt = 0; attempt < 10; attempt++) {
        final refreshed = await _native.getStatus();
        if (refreshed.runtimeRunning) {
          running = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!running) {
        throw StateError(
          'Android did not start the visible Beatrice task service. '
          'Allow notifications if prompted, keep Beatrice visible, and retry.',
        );
      }
    }
    await _native.updateRuntimeTaskState(
      state,
      '${state == 'starting' ? 'Starting' : 'Working on'}: '
      '${_boundedStatus(task)}',
    );
  }

  Future<bool> _shouldCancel(int generation) async {
    if (shouldAbortBeforeAction(
      cancelRequested: _cancelRequested,
      runtimeRunning: true,
      taskGeneration: generation,
      currentGeneration: _taskGeneration,
    )) {
      return true;
    }
    final status = await _native.getStatus();
    if (shouldAbortBeforeAction(
      cancelRequested: _cancelRequested,
      runtimeRunning: status.runtimeRunning,
      taskGeneration: generation,
      currentGeneration: _taskGeneration,
    )) {
      _cancelRequested = true;
      return true;
    }
    return false;
  }

  String _cancelledResult(int generation) {
    if (_cancelEventGeneration != generation) {
      _cancelEventGeneration = generation;
      _events.add(
        const MobileUseWorkflowEvent(
          MobileUseWorkflowEventType.cancelled,
          'I stopped the mobile task because you cancelled it.',
        ),
      );
    }
    return 'The mobile task was cancelled. No further phone actions ran.';
  }

  String _recordFailure(String task, MobileTaskSource source, String reason) {
    final conciseReason = reason.replaceAll(RegExp(r'\s+'), ' ').trim();
    _retryGate.offer(task, source);
    unawaited(
      _native.updateRuntimeTaskState('failed', _boundedStatus(conciseReason)),
    );
    _events.add(
      MobileUseWorkflowEvent(
        MobileUseWorkflowEventType.failed,
        'I stopped because $conciseReason Would you like me to try again?',
      ),
    );
    return 'I stopped because $conciseReason Would you like me to try again?';
  }

  String _boundedStatus(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.substring(0, compact.length.clamp(0, 140));
  }

  Future<PlannerCommand> _nextCommand({
    required String task,
    required Map<String, dynamic> observation,
    required Map<String, dynamic> previousResult,
    required int step,
  }) async {
    Object? lastError;
    String? malformed;
    for (var attempt = 0; attempt < 2; attempt++) {
      final prompt = _plannerPrompt(
        task: task,
        observation: observation,
        previousResult: previousResult,
        step: step,
        malformed: malformed,
      );
      final output = await _ollama!.generatePlannerCommand(
        prompt: prompt,
        model: _ollamaModel,
      );
      if (output.length > 6000) {
        throw StateError('Local planner output exceeded its hard size limit.');
      }
      try {
        final command = PlannerCommand.parse(output);
        debugPrint(
          'MobileUseAgent: step $step command=${command.kind.name} '
          'action=${command.action ?? '-'}',
        );
        return command;
      } catch (error) {
        lastError = error;
        malformed = output.substring(0, output.length.clamp(0, 1000));
      }
    }
    throw FormatException(
      'The local planner returned malformed structured output twice: $lastError',
    );
  }

  Future<void> _ensureOllamaPlanner() async {
    final provider = MobilePlannerProviders.byId(_plannerProviderId);
    if (!provider.isIntegrated) {
      throw StateError(
        '${provider.label} is listed as a future MobileUseAgent provider, '
        'but its authenticated planner adapter is not configured yet. '
        'Choose Ollama Local or Ollama Cloud in Beatrice setup.',
      );
    }
    final ollama = _ollama;
    if (ollama == null || _ollamaModel.isEmpty) {
      throw StateError(
        'No Ollama MobileUseAgent model is selected. Open Beatrice setup, '
        'start Ollama in Termux, refresh models, and select one.',
      );
    }
    final discovery = await ollama.discoverModels(candidates: [ollama.baseUrl]);
    if (!discovery.isConnected) {
      throw StateError(
        ollama.isCloud
            ? 'Ollama Cloud is unavailable. Check internet access and the '
                  'Cloud API key in Settings. ${discovery.error ?? ''}'
            : 'Local Ollama is unavailable. Start `ollama serve` in Termux, '
                  'then retry. ${discovery.error ?? ''}',
      );
    }
    ollama.configure(baseUrl: discovery.endpoint);
    if (!discovery.models.contains(_ollamaModel)) {
      throw StateError(
        'The selected Ollama model "$_ollamaModel" is not installed. '
        'Refresh Beatrice setup and choose an exact discovered model. '
        'Recommended: qwen2.5:0.5b or qwen2.5:1.5b.',
      );
    }
    debugPrint(
      'MobileUseAgent: Ollama connected at ${discovery.endpoint}; '
      'using exact model $_ollamaModel',
    );
  }

  String _plannerPrompt({
    required String task,
    required Map<String, dynamic> observation,
    required Map<String, dynamic> previousResult,
    required int step,
    String? malformed,
  }) {
    return '''
You are an offline Android next-action planner, not a chat assistant.
Return exactly one compact JSON object and no prose or code.
TASK: $task
CURRENT_STEP: $step of ${MobileTaskCoordinator.maxPlanningSteps}
SANITIZED_OBSERVATION: ${jsonEncode(observation)}
PREVIOUS_VERIFIED_RESULT: ${jsonEncode(previousResult)}
ALLOWED_ACTIONS: ${allowedActions.join(',')}
ALLOWED_APP_PACKAGES: YouTube=com.google.android.youtube; Gmail=com.google.android.gm; Browser=com.android.chrome; Android Settings=com.android.settings; Messages=com.google.android.apps.messaging; WhatsApp=com.whatsapp; WhatsApp Business=com.whatsapp.w4b
POLICY: consequential send/call/purchase/delete/post/submit/account/security actions require fresh confirmation; never emit shell, ADB, network, or arbitrary code.
OUTPUT one of:
{"kind":"action","action":"allowed_action","arguments":{},"message":"short expected result"}
{"kind":"ask_for_clarification","message":"one concise question"}
{"kind":"request_confirmation","message":"exact consequential action"}
{"kind":"complete","message":"verified outcome only"}
Choose one next action only. Base it only on the observation. After an action,
the coordinator will execute, re-observe, and call you again.
${malformed == null ? '' : 'Your prior output was invalid. Correct it: $malformed'}
''';
  }

  void _validateAction(PlannerCommand command) {
    final action = command.action;
    if (action == null || !allowedActions.contains(action)) {
      throw FormatException('Planner action is not allowlisted: $action');
    }
    final args = command.arguments;
    switch (action) {
      case 'launch_app':
        _requireString(args, 'packageName');
        if (!allowedAppPackages.contains(args['packageName'])) {
          throw FormatException(
            'launch_app package is not explicitly allowlisted: '
            '${args['packageName']}',
          );
        }
      case 'click_text':
        _requireString(args, 'text');
      case 'set_text':
        _requireString(args, 'text');
      case 'tap':
        _requireNumber(args, 'x');
        _requireNumber(args, 'y');
      case 'swipe':
        for (final key in ['startX', 'startY', 'endX', 'endY']) {
          _requireNumber(args, key);
        }
      case 'wait':
        final milliseconds = (args['milliseconds'] as num?)?.toInt() ?? 500;
        if (milliseconds < 100 || milliseconds > 3000) {
          throw const FormatException('wait must be between 100 and 3000 ms.');
        }
      case 'back':
      case 'home':
        if (args.isNotEmpty) {
          throw FormatException('$action does not accept arguments.');
        }
    }
  }

  Map<String, dynamic> _sanitizeObservation(Map<String, dynamic> raw) {
    final controls = (raw['controls'] as List? ?? const []).take(60).map((
      item,
    ) {
      if (item is! Map) return const <String, dynamic>{};
      String? bounded(dynamic value) {
        if (value == null) return null;
        final text = value.toString().replaceAll(RegExp(r'\s+'), ' ');
        return text.substring(0, text.length.clamp(0, 160));
      }

      return {
        'text': bounded(item['text']),
        'description': bounded(item['description']),
        'viewId': bounded(item['viewId']),
        'clickable': item['clickable'] == true,
        'editable': item['editable'] == true,
        'bounds': item['bounds'],
      };
    }).toList();
    return {
      'packageName': raw['packageName']?.toString(),
      'controls': controls,
    };
  }

  void _requireString(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is! String || value.trim().isEmpty || value.length > 500) {
      throw FormatException('$key must be a bounded non-empty string.');
    }
  }

  void _requireNumber(Map<String, dynamic> args, String key) {
    if (args[key] is! num) throw FormatException('$key must be numeric.');
  }
}
