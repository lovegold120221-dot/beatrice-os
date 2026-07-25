import 'package:beatrice/ui/features/attachment/attachment_sheet.dart';
import 'package:beatrice/ui/features/voice/voice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Live Voice uses mic stop without MIC INPUT badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VoiceScreen(
          isLiveActive: true,
          isSpeaking: false,
          liveTranscription: '',
          micInputLevel: 0.6,
          onStop: () {},
          isCameraActive: false,
          onToggleCamera: () {},
          onSwitchCamera: () {},
          cameraController: null,
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_off), findsOneWidget);
    expect(find.text('MIC INPUT'), findsNothing);
    expect(find.byIcon(Icons.call_end), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Live Voice does not overflow a compact phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.2)),
          child: VoiceScreen(
            isLiveActive: true,
            isSpeaking: false,
            liveTranscription:
                'Please open WhatsApp and check the latest unread conversation '
                'while the verified mobile task continues.',
            micInputLevel: 0.6,
            onStop: () {},
            isCameraActive: false,
            onToggleCamera: () {},
            onSwitchCamera: () {},
            cameraController: null,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_off), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('plus sheet owns the editable task starters', (tester) async {
    String? selectedPrompt;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentSheet(
            onCamera: () {},
            onPhotos: () {},
            onFiles: () {},
            onCreateImage: () {},
            webLookupEnabled: false,
            onToggleWebLookup: () {},
            visionImageReady: false,
            onVisionImage: () {},
            ocrReady: false,
            ocrSelected: false,
            onOcrDocument: () {},
            onStudy: () {},
            onAgentMode: () {},
            onTaskStarter: (prompt) => selectedPrompt = prompt,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(AttachmentSheet.taskStarters, hasLength(5));
    expect(find.text('Task starters'), findsOneWidget);
    await tester.tap(find.text('Watch J-Learnout'));
    expect(
      selectedPrompt,
      'Go to YouTube, search for a video from J-Learnout, and watch it for 20 seconds.',
    );
  });
}
