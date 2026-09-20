import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/data/services/camera_pad_mode.dart';
import 'package:wheeldeck/data/services/dashboard_input.dart';
import 'package:wheeldeck/ui/features/driving/views/camera_pad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DashboardInput input;
  late List<(ControlId, ActionType)> events;
  late int modeSwitches;
  final haptics = <String>[];

  setUp(() {
    input = DashboardInput();
    events = [];
    input.onControlActivated(
      (control, action) => events.add((control, action)),
    );
    modeSwitches = 0;
    haptics.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          haptics.add(call.method);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  Widget pad(CameraPadMode mode) => CameraPad(
    mode: mode,
    input: input,
    bindingFor: (control) => 'K',
    onModeSwitch: () => modeSwitches++,
  );

  Future<void> pumpPad(WidgetTester tester, CameraPadMode mode) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: pad(mode),
        ),
      ),
    );
    await tester.pump();
  }

  Finder cell(ControlId control) =>
      find.byKey(ValueKey('camera-pad-${control.name}'));

  testWidgets('numpad mode taps emit the numpad-set controls', (tester) async {
    await pumpPad(tester, CameraPadMode.numpad);

    await tester.tap(cell(ControlId.cameraPadUp));
    await tester.pump();
    expect(events, [
      (ControlId.cameraPadUp, ActionType.press),
      (ControlId.cameraPadUp, ActionType.release),
    ]);

    events.clear();
    await tester.tap(cell(ControlId.cameraPadUpLeft));
    await tester.pump();
    expect(events.first.$1, ControlId.cameraPadUpLeft);
  });

  testWidgets('arrow mode taps emit the arrow-set controls', (tester) async {
    await pumpPad(tester, CameraPadMode.arrow);

    await tester.tap(cell(ControlId.cameraPadArrowDown));
    await tester.pump();
    expect(events, [
      (ControlId.cameraPadArrowDown, ActionType.press),
      (ControlId.cameraPadArrowDown, ActionType.release),
    ]);
  });

  testWidgets('arrow mode disables the four diagonals and they emit nothing', (
    tester,
  ) async {
    await pumpPad(tester, CameraPadMode.arrow);

    // Arrow mode has no wire identifiers for the diagonals: the cells
    // render as inert disabled keys.
    expect(find.byKey(const ValueKey('camera-pad-diagonal')), findsNWidgets(4));
    expect(cell(ControlId.cameraPadUpLeft), findsNothing);
    expect(cell(ControlId.cameraPadDownRight), findsNothing);

    await tester.tap(find.byKey(const ValueKey('camera-pad-diagonal')).first);
    await tester.pump();
    expect(events, isEmpty);
  });

  testWidgets('a hold dragged off the cell cancels without emitting', (
    tester,
  ) async {
    await pumpPad(tester, CameraPadMode.numpad);
    final center = find.byKey(const ValueKey('camera-pad-center'));

    final gesture = await tester.startGesture(tester.getCenter(center));
    await tester.pump();
    await gesture.moveBy(const Offset(500, 500));
    await gesture.up();
    await tester.pump(const Duration(seconds: 3));

    expect(events, isEmpty);
    expect(modeSwitches, 0);
  });

  testWidgets('center tap emits recenter in numpad mode', (tester) async {
    await pumpPad(tester, CameraPadMode.numpad);

    await tester.tap(find.byKey(const ValueKey('camera-pad-center')));
    await tester.pump();
    expect(events, [
      (ControlId.cameraPadRecenter, ActionType.press),
      (ControlId.cameraPadRecenter, ActionType.release),
    ]);
    expect(modeSwitches, 0);
  });

  testWidgets('center tap in arrow mode emits nothing', (tester) async {
    await pumpPad(tester, CameraPadMode.arrow);

    await tester.tap(find.byKey(const ValueKey('camera-pad-center')));
    await tester.pump();
    expect(events, isEmpty);
    expect(modeSwitches, 0);
  });

  testWidgets('a three-second hold switches mode without a press and fires '
      'the haptic', (tester) async {
    await pumpPad(tester, CameraPadMode.numpad);
    final center = find.byKey(const ValueKey('camera-pad-center'));

    final gesture = await tester.startGesture(tester.getCenter(center));
    await tester.pump();
    // Progress indication shows during the hold.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Pump just past the three-second hold so the controller completes
    // within the frame and fires the hold.
    await tester.pump(const Duration(seconds: 3, milliseconds: 100));
    await gesture.up();
    await tester.pump();

    expect(modeSwitches, 1);
    expect(events, isEmpty);
    expect(haptics, contains('HapticFeedback.vibrate'));
    // Progress is gone after the hold completes.
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a hold released early emits the press action and does not '
      'switch mode; the timer is cancelled', (tester) async {
    await pumpPad(tester, CameraPadMode.numpad);
    final center = find.byKey(const ValueKey('camera-pad-center'));

    final gesture = await tester.startGesture(tester.getCenter(center));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump();

    expect(events, [
      (ControlId.cameraPadRecenter, ActionType.press),
      (ControlId.cameraPadRecenter, ActionType.release),
    ]);
    expect(modeSwitches, 0);

    // The hold timer must not fire after the early release.
    events.clear();
    await tester.pump(const Duration(seconds: 3));
    expect(modeSwitches, 0);
    expect(events, isEmpty);
  });

  testWidgets('the hold timer does not outlive the widget', (tester) async {
    await pumpPad(tester, CameraPadMode.numpad);
    final center = find.byKey(const ValueKey('camera-pad-center'));

    final gesture = await tester.startGesture(tester.getCenter(center));
    await tester.pump();

    // Tear the widget down mid-hold, then let the hold window elapse.
    await tester.pumpWidget(const SizedBox.shrink());
    await gesture.up();
    await tester.pump(const Duration(seconds: 3));

    expect(modeSwitches, 0);
    expect(events, isEmpty);
  });

  testWidgets('the center cell labels the active key set', (tester) async {
    await pumpPad(tester, CameraPadMode.numpad);
    expect(find.text('NUM'), findsOneWidget);

    await pumpPad(tester, CameraPadMode.arrow);
    expect(find.text('ARR'), findsOneWidget);
  });
}
