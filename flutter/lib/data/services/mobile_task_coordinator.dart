import 'dart:math';

enum MobileTaskSource { chat, liveVoiceTranslation }

enum MobileTaskDecision {
  readyForLocalPlanning,
  clarificationRequired,
  confirmationRequired,
  refused,
}

abstract interface class LocalMobilePlanner {
  String get runtimeName;
  bool get isReady;

  Future<List<Map<String, dynamic>>> proposeSteps(
    MobileTaskProposal proposal,
    Map<String, dynamic> boundedObservation,
  );
}

/// Transparent placeholder for a selected GGUF without an inference runtime.
/// A future llama.cpp-compatible adapter implements [LocalMobilePlanner] here.
class UnconfiguredGgufPlanner implements LocalMobilePlanner {
  final String modelName;

  const UnconfiguredGgufPlanner(this.modelName);

  @override
  String get runtimeName => 'GGUF runtime setup required';

  @override
  bool get isReady => false;

  @override
  Future<List<Map<String, dynamic>>> proposeSteps(
    MobileTaskProposal proposal,
    Map<String, dynamic> boundedObservation,
  ) {
    throw StateError(
      '$modelName is selected, but no local GGUF inference runtime is installed.',
    );
  }
}

class MobileTaskProposal {
  final String id;
  final MobileTaskSource source;
  final String objective;
  final DateTime createdAt;

  const MobileTaskProposal({
    required this.id,
    required this.source,
    required this.objective,
    required this.createdAt,
  });
}

class MobileTaskReview {
  final MobileTaskProposal proposal;
  final MobileTaskDecision decision;
  final String explanation;
  final MobileConfirmationRequest? confirmation;
  final String? clarificationQuestion;

  const MobileTaskReview({
    required this.proposal,
    required this.decision,
    required this.explanation,
    this.confirmation,
    this.clarificationQuestion,
  });
}

class MobileConfirmationRequest {
  final String token;
  final String taskId;
  final String summary;
  final String exactAction;
  final DateTime expiresAt;

  const MobileConfirmationRequest({
    required this.token,
    required this.taskId,
    required this.summary,
    required this.exactAction,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Shared ingress for chat and Gemini Live.
///
/// Gemini Live may translate speech into a structured objective, but it never
/// plans or executes Android actions. A separately configured planner
/// (for example a small Ollama/SmolLM model or OpenCode Zen) consumes only
/// proposals that pass this policy review. Native effects remain behind a
/// later, allowlisted executor.
class MobileTaskCoordinator {
  static const int maxTaskCharacters = 800;
  static const int maxPlanningSteps = 50;
  final Random _secureRandom;

  MobileTaskCoordinator({Random? secureRandom})
    : _secureRandom = secureRandom ?? Random.secure();

  /// Typed chat bypasses Gemini and goes straight to consent review before the
  /// selected MobileUseAgent planner.
  MobileTaskReview submitTypedTask(String objective) {
    return _reviewWithClarification(MobileTaskSource.chat, objective);
  }

  /// Gemini Live is an online speech interpreter only. Its structured task is
  /// reviewed identically before the selected MobileUseAgent planner sees it.
  MobileTaskReview submitLiveStructuredTask(String structuredObjective) {
    return _reviewWithClarification(
      MobileTaskSource.liveVoiceTranslation,
      structuredObjective,
    );
  }

  MobileTaskReview _reviewWithClarification(
    MobileTaskSource source,
    String rawObjective,
  ) {
    final objective = rawObjective.trim();
    if (objective.isEmpty || objective.length > maxTaskCharacters) {
      return _review(source, rawObjective);
    }
    final clarification = MobileTaskClarificationGate.questionFor(rawObjective);
    if (clarification != null) {
      final proposal = MobileTaskProposal(
        id: _token(),
        source: source,
        objective: rawObjective.trim(),
        createdAt: DateTime.now(),
      );
      return MobileTaskReview(
        proposal: proposal,
        decision: MobileTaskDecision.clarificationRequired,
        explanation:
            'The task is not specific enough to dispatch without guessing.',
        clarificationQuestion: clarification,
      );
    }
    return _review(source, rawObjective);
  }

  MobileTaskReview proposeFromChat(String objective) =>
      submitTypedTask(objective);

  MobileTaskReview proposeFromLiveTranslation(String structuredObjective) =>
      submitLiveStructuredTask(structuredObjective);

  MobileTaskReview _review(MobileTaskSource source, String rawObjective) {
    final objective = rawObjective.trim();
    final proposal = MobileTaskProposal(
      id: _token(),
      source: source,
      objective: objective,
      createdAt: DateTime.now(),
    );
    if (objective.isEmpty) {
      return MobileTaskReview(
        proposal: proposal,
        decision: MobileTaskDecision.refused,
        explanation: 'A mobile task needs a clear objective.',
      );
    }
    if (objective.length > maxTaskCharacters) {
      return MobileTaskReview(
        proposal: proposal,
        decision: MobileTaskDecision.refused,
        explanation:
            'Keep one focused task under $maxTaskCharacters characters. '
            'Long transcripts are not sent to MobileUseAgent.',
      );
    }

    if (_requiresConfirmation(objective)) {
      return MobileTaskReview(
        proposal: proposal,
        decision: MobileTaskDecision.confirmationRequired,
        explanation:
            'This task may cause an external or irreversible consequence.',
        confirmation: MobileConfirmationRequest(
          token: _token(),
          taskId: proposal.id,
          summary: 'Confirm this mobile action',
          exactAction: objective,
          expiresAt: DateTime.now().add(const Duration(minutes: 2)),
        ),
      );
    }

    return MobileTaskReview(
      proposal: proposal,
      decision: MobileTaskDecision.readyForLocalPlanning,
      explanation:
          'Ready for the configured planner. No Android action has run.',
    );
  }

  bool _requiresConfirmation(String objective) {
    final normalized = objective.toLowerCase();
    if (normalized.contains('compose') ||
        normalized.contains('draft') ||
        normalized.contains('prepare')) {
      // Preparing content is reversible. The executor still gates the final
      // Send/Submit interaction with a fresh action-specific confirmation.
      return false;
    }
    const consequentialTerms = [
      'send ',
      'submit',
      'post ',
      'publish',
      'call ',
      'purchase',
      'buy ',
      'pay ',
      'delete',
      'remove account',
      'change password',
      'security setting',
      'account setting',
      'factory reset',
    ];
    return consequentialTerms.any(normalized.contains);
  }

  String _token() {
    final values = List<int>.generate(24, (_) => _secureRandom.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

/// Dispatch gate for Gemini Live's compact speech-to-task handoff.
///
/// Gemini may converse naturally to obtain missing details, but only a single,
/// bounded objective that passes this deterministic gate reaches the local
/// planner.
class MobileTaskClarificationGate {
  static String? questionFor(String rawTask) {
    final task = rawTask.trim().toLowerCase();
    if (task.isEmpty) return 'What would you like me to do?';
    if (!_looksLikePhoneAction(task)) {
      return 'What exact action would you like me to perform on your phone?';
    }
    final isEmail = task.contains('email') || task.contains('mail ');
    final isEmailComposition =
        isEmail &&
        (RegExp(
              r'\b(draft|compose|prepare|send|reply|write)\b',
            ).hasMatch(task) ||
            RegExp(r'^(?:please\s+)?email\s+\S+').hasMatch(task)) &&
        !RegExp(
          r'\b(delete|remove|archive|read|check|review)\b',
        ).hasMatch(task);
    if (isEmailComposition && !_hasSpecificRecipient(task)) {
      return 'Who should receive the email?';
    }
    if (isEmailComposition &&
        RegExp(r'\b(send|reply)\b').hasMatch(task) &&
        !_hasMessageContent(task)) {
      return 'What should the email say?';
    }
    final isDirectMessage =
        task.contains('message') ||
        task.contains('text ') ||
        task.contains('sms');
    if (isDirectMessage &&
        RegExp(
          r'\b(draft|compose|prepare|send|reply|message|text)\b',
        ).hasMatch(task) &&
        !_hasSpecificMessageRecipient(task)) {
      return 'Who should receive the message?';
    }
    if (task.contains('attach') &&
        !RegExp(r'\b(attach|attachment)\s+[\w./-]+').hasMatch(task) &&
        !task.contains('from ')) {
      return 'Which file should I attach, and where is it located?';
    }
    if ((task.contains('message') || task.contains('post ')) &&
        !task.contains(' in ') &&
        !task.contains(' using ') &&
        !task.contains(' on ')) {
      return 'Which app or account should I use?';
    }
    if (_needsSearchTarget(task)) {
      return 'What exactly should I search for?';
    }
    if (RegExp(
      r'^(open|launch)\s+(the\s+)?(app|application)$',
    ).hasMatch(task)) {
      return 'Which app should I open?';
    }
    if (RegExp(r'^(open|find|change|delete|remove)\s*$').hasMatch(task)) {
      return 'What exact target should I use?';
    }
    return null;
  }

  static bool _hasSpecificRecipient(String task) {
    if (RegExp(r'\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b').hasMatch(task)) {
      return true;
    }
    final match = RegExp(r'\b(?:to|recipient)\s+([^,.;]+)').firstMatch(task);
    if (match == null) return false;
    var recipient = match.group(1)?.trim() ?? '';
    recipient = recipient
        .replaceFirst(RegExp(r'\b(?:and|with|about|regarding)\b.*$'), '')
        .trim();
    const ambiguousRecipients = {
      '',
      'someone',
      'somebody',
      'them',
      'him',
      'her',
      'my colleague',
      'a colleague',
      'my friend',
      'a friend',
      'my boss',
      'the client',
      'my client',
      'the team',
      'my contact',
      'a contact',
    };
    return !ambiguousRecipients.contains(recipient);
  }

  static bool _hasMessageContent(String task) {
    return RegExp(
      r'\b(?:saying|say|message|body|subject|about|regarding|tell(?:ing)?)\b',
    ).hasMatch(task);
  }

  static bool _hasSpecificMessageRecipient(String task) {
    if (_hasSpecificRecipient(task)) return true;
    final match = RegExp(
      r'\b(?:message|text)\s+([a-z][\w.-]*(?:\s+[a-z][\w.-]*)?)\b',
    ).firstMatch(task);
    if (match == null) return false;
    final recipient = match.group(1)?.trim() ?? '';
    const nonRecipients = {
      '',
      'someone',
      'somebody',
      'them',
      'him',
      'her',
      'in whatsapp',
      'on whatsapp',
      'using whatsapp',
      'in messages',
      'on messages',
      'the team',
      'my colleague',
      'my friend',
    };
    return !nonRecipients.contains(recipient);
  }

  static bool _needsSearchTarget(String task) {
    if (!RegExp(r'\b(search|find)\b').hasMatch(task)) return false;
    if (RegExp(r'\b(search|find)\s+for\s+\S+').hasMatch(task)) return false;
    if (RegExp(r'\b(search|find)\s+[\w-]+\s+(?:on|in)\s+\S+').hasMatch(task)) {
      return false;
    }
    return RegExp(r'\b(search|find)(?:\s+(?:on|in)\s+\S+)?\s*$').hasMatch(task);
  }

  static bool _looksLikePhoneAction(String task) {
    const actionTerms = [
      'open',
      'launch',
      'check',
      'review',
      'read',
      'search',
      'find',
      'play',
      'watch',
      'draft',
      'compose',
      'prepare',
      'email',
      'message',
      'attach',
      'upload',
      'download',
      'navigate',
      'go to',
      'tap',
      'click',
      'type',
      'enter',
      'set ',
      'turn on',
      'turn off',
      'change',
      'create',
      'call',
      'send',
      'post',
      'delete',
      'remove',
      'reply',
      'share',
      'install',
      'uninstall',
    ];
    return actionTerms.any(task.contains);
  }
}
