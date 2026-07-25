import 'dart:math';

import 'package:beatrice/data/services/mobile_task_coordinator.dart';
import 'package:beatrice/data/services/mobile_use_agent_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coordinator = MobileTaskCoordinator(secureRandom: Random(7));

  test('chat and Live translation share the same consent policy', () {
    final chat = coordinator.submitTypedTask('Open YouTube');
    final voice = coordinator.submitLiveStructuredTask('Open YouTube');

    expect(chat.decision, MobileTaskDecision.readyForLocalPlanning);
    expect(voice.decision, MobileTaskDecision.readyForLocalPlanning);
    expect(chat.proposal.source, MobileTaskSource.chat);
    expect(voice.proposal.source, MobileTaskSource.liveVoiceTranslation);
  });

  test('destructive task requires a fresh detailed confirmation', () {
    final review = coordinator.submitTypedTask(
      'Delete the saved email from Alex',
    );

    expect(review.decision, MobileTaskDecision.confirmationRequired);
    expect(review.confirmation, isNotNull);
    expect(review.confirmation!.taskId, review.proposal.id);
    expect(review.confirmation!.exactAction, contains('Alex'));
    expect(review.confirmation!.isExpired, isFalse);
  });

  test('low-risk open search and play actions do not require confirmation', () {
    expect(
      MobileActionPolicy.requiresConfirmation('launch_app', {
        'packageName': 'com.google.android.youtube',
      }),
      isFalse,
    );
    expect(
      MobileActionPolicy.requiresConfirmation('click_text', {
        'text': 'Play requested song',
      }),
      isFalse,
    );
    expect(
      MobileActionPolicy.requiresConfirmation('set_text', {
        'text': 'requested song',
      }),
      isFalse,
    );
  });

  test('consequential final action remains confirmation-gated', () {
    expect(
      MobileActionPolicy.requiresConfirmation('click_text', {'text': 'Send'}),
      isTrue,
    );
    expect(
      MobileActionPolicy.requiresConfirmation('click_text', {
        'text': 'Confirm purchase',
      }),
      isTrue,
    );
  });

  test('oversized typed tasks are refused before local planning', () {
    final review = coordinator.submitTypedTask(
      List.filled(MobileTaskCoordinator.maxTaskCharacters + 1, 'x').join(),
    );

    expect(review.decision, MobileTaskDecision.refused);
    expect(review.explanation, contains('one focused task'));
  });

  test('Live email task is gated until recipient is known', () {
    final review = coordinator.submitLiveStructuredTask(
      'Compose an email with the quarterly report attached',
    );

    expect(review.decision, MobileTaskDecision.clarificationRequired);
    expect(review.clarificationQuestion, contains('receive'));
  });

  test('complete Live email draft passes clarification gate', () {
    final review = coordinator.submitLiveStructuredTask(
      'Compose an email to alex@example.com and attach report.pdf from Downloads',
    );

    expect(review.decision, MobileTaskDecision.readyForLocalPlanning);
  });

  test('Live conversation is not misidentified as a phone task', () {
    final review = coordinator.submitLiveStructuredTask(
      'What do you think about this idea?',
    );

    expect(review.decision, MobileTaskDecision.clarificationRequired);
    expect(review.clarificationQuestion, contains('exact action'));
  });

  test('complete low-risk Live phone action passes dispatch preflight', () {
    final review = coordinator.submitLiveStructuredTask(
      'Open YouTube and search for J-Learnout',
    );

    expect(review.decision, MobileTaskDecision.readyForLocalPlanning);
  });

  test('typed Task mode asks instead of guessing a recipient', () {
    final review = coordinator.submitTypedTask(
      'Draft an email to my colleague about the project',
    );

    expect(review.decision, MobileTaskDecision.clarificationRequired);
    expect(review.clarificationQuestion, contains('receive'));
  });

  test('an incomplete search asks for the exact query', () {
    final review = coordinator.submitLiveStructuredTask(
      'Open the browser and search',
    );

    expect(review.decision, MobileTaskDecision.clarificationRequired);
    expect(review.clarificationQuestion, contains('search for'));
  });

  test('a complete email brief preserves exact supplied details', () {
    final review = coordinator.submitLiveStructuredTask(
      'Draft an email to alex@example.com saying the review is at 3 PM '
      'using Gmail',
    );

    expect(review.decision, MobileTaskDecision.readyForLocalPlanning);
    expect(review.proposal.objective, contains('alex@example.com'));
    expect(review.proposal.objective, contains('3 PM'));
  });

  test('planner accepts exactly one structured allowlisted action', () {
    final command = PlannerCommand.parse(
      '{"kind":"action","action":"click_text",'
      '"arguments":{"text":"Compose"},"message":"open composer"}',
    );

    expect(command.kind, PlannerCommandKind.action);
    expect(command.action, 'click_text');
    expect(command.arguments['text'], 'Compose');
  });

  test('planner rejects arbitrary prose and unknown command kinds', () {
    expect(
      () => PlannerCommand.parse('I will open the app now'),
      throwsFormatException,
    );
    expect(
      () => PlannerCommand.parse('{"kind":"shell","command":"ls"}'),
      throwsFormatException,
    );
  });

  test('compose and send can prepare before final action confirmation', () {
    final review = coordinator.submitTypedTask(
      'Compose an email to alex@example.com saying the report is ready and '
      'send it',
    );

    expect(review.decision, MobileTaskDecision.readyForLocalPlanning);
  });

  test('retry requires a pending offer and unambiguous affirmative reply', () {
    final gate = PendingTaskRetryGate();
    expect(gate.consumeAffirmative('yes'), isNull);

    gate.offer(
      'Open Gmail',
      MobileTaskSource.liveVoiceTranslation,
      now: DateTime(2026),
    );
    expect(gate.consumeAffirmative('maybe', now: DateTime(2026)), isNull);
    final retry = gate.consumeAffirmative('yes please', now: DateTime(2026));
    expect(retry?.task, 'Open Gmail');
    expect(retry?.source, MobileTaskSource.liveVoiceTranslation);
    expect(gate.consumeAffirmative('yes', now: DateTime(2026)), isNull);
  });
}
