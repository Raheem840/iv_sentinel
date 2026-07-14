import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iv_sentinel/main.dart';

void main() {
  testWidgets('app renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: IvSentinelApp()),
    );
    // First frame: app shell loads (may show loading or empty state)
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
