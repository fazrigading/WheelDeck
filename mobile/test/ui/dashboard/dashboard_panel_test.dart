import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wheeldeck/input/dashboard_input.dart';
import 'package:wheeldeck/ui/dashboard/dashboard_panel.dart';

void main() {
  late DashboardInput input;
  late List<(ControlId, ActionType)> events;

  setUp(() {
    input = DashboardInput();
    events = [];
    input.onControlActivated((control, action) => events.add((control, action)));
  });

  Future<void> pumpPanel(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardPanel(input: input),
          ),
        ),
      );

  testWidgets('renders every dashboard control', (tester) async {
    await pumpPanel(tester);

    expect(find.byType(DashboardControl), findsNWidgets(9));
  });

  testWidgets('tapping a toggle control emits a toggle action', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.byKey(const ValueKey('dashboard-turnSignalLeft')));
    await tester.pump();

    expect(events, [(ControlId.turnSignalLeft, ActionType.toggle)]);
  });

  testWidgets('holding a momentary control emits press then release', (tester) async {
    await pumpPanel(tester);

    final control = find.byKey(const ValueKey('dashboard-wipers'));
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump();

    expect(events.first, (ControlId.wipers, ActionType.press));
    expect(events.last, (ControlId.wipers, ActionType.release));
  });

  testWidgets('holding an engine start emits hold_confirm', (tester) async {
    await pumpPanel(tester);

    final control = find.byKey(const ValueKey('dashboard-engineStart'));
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    expect(events, contains((ControlId.engineStart, ActionType.holdConfirm)));
  });

  testWidgets('engine start does not emit on a short tap', (tester) async {
    await pumpPanel(tester);

    final control = find.byKey(const ValueKey('dashboard-engineStart'));
    final gesture = await tester.startGesture(tester.getCenter(control));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(
      events.where((e) => e.$1 == ControlId.engineStart),
      isEmpty,
    );
  });
}
