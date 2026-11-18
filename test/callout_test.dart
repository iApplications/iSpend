import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ispend/core/widgets/callout.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Callout shows its words and icon in $mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: mode,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: const Scaffold(
            body: Callout(
              icon: Icons.warning_amber_rounded,
              child: Text('Read this first'),
            ),
          ),
        ),
      );
      expect(find.text('Read this first'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  }
}
