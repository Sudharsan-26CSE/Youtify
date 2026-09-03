import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yt_clone/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const YoutifyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
