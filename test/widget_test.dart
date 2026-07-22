import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iv_sentinel/main.dart';

void main() {
  testWidgets('app renders without crashing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: IvSentinelApp()),
    );
    // First frame: app shell loads (may show loading or empty state)
    expect(find.byType(MaterialApp), findsOneWidget);

    // Let the splash screen's minimum-display Future.delayed(1200ms) finish,
    // AND let AlertService.init()'s 3s .timeout() elapse — under test,
    // flutter_local_notifications' initialize() never resolves (no real
    // platform channel), so the timeout is what actually completes _boot().
    // This navigates to HomeScreen, which starts BedReadingsNotifier's
    // polling Timer.periodic — an intentionally never-ending timer for as
    // long as the app runs, so it must be explicitly torn down (via
    // disposing the widget tree below) rather than waited out.
    await tester.pump(const Duration(seconds: 3, milliseconds: 200));

    // Unmount everything so Riverpod disposes bedReadingsProvider and its
    // periodic poll Timer, otherwise the test framework's "no pending
    // timers" invariant check fails on a timer that's supposed to keep
    // running for the app's entire lifetime.
    await tester.pumpWidget(const SizedBox());
  });
}
