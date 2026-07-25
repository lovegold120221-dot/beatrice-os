import 'package:beatrice/app.dart';
import 'package:beatrice/data/services/mobile_task_coordinator.dart';
import 'package:beatrice/data/services/mobile_use_agent_runtime.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Live accepts a focused WhatsApp check as a phone task', () {
    final review = MobileTaskCoordinator().submitLiveStructuredTask(
      'Check my WhatsApp',
    );

    expect(review.decision, MobileTaskDecision.readyForLocalPlanning);
  });

  test('WhatsApp variants are exact allowlisted app packages', () {
    expect(
      MobileUseAgentRuntime.allowedAppPackages,
      containsAll({'com.whatsapp', 'com.whatsapp.w4b'}),
    );
  });

  test('checking WhatsApp is low risk but sending still needs approval', () {
    expect(
      MobileActionPolicy.requiresConfirmation('launch_app', {
        'packageName': 'com.whatsapp',
      }),
      isFalse,
    );
    expect(
      MobileActionPolicy.requiresConfirmation('click_text', {'text': 'Send'}),
      isTrue,
    );
  });

  test('cancel or stopped runtime aborts before another native action', () {
    expect(
      MobileUseAgentRuntime.shouldAbortBeforeAction(
        cancelRequested: true,
        runtimeRunning: true,
        taskGeneration: 4,
        currentGeneration: 4,
      ),
      isTrue,
    );
    expect(
      MobileUseAgentRuntime.shouldAbortBeforeAction(
        cancelRequested: false,
        runtimeRunning: false,
        taskGeneration: 4,
        currentGeneration: 4,
      ),
      isTrue,
    );
    expect(
      MobileUseAgentRuntime.shouldAbortBeforeAction(
        cancelRequested: false,
        runtimeRunning: true,
        taskGeneration: 4,
        currentGeneration: 5,
      ),
      isTrue,
    );
  });

  test(
    'background lifecycle stops Live capture without treating focus loss as background',
    () {
      expect(shouldSuspendLiveCapture(AppLifecycleState.inactive), isFalse);
      expect(shouldSuspendLiveCapture(AppLifecycleState.paused), isTrue);
      expect(shouldSuspendLiveCapture(AppLifecycleState.hidden), isTrue);
      expect(shouldSuspendLiveCapture(AppLifecycleState.detached), isTrue);
    },
  );
}
