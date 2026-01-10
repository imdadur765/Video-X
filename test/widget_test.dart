import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_x/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VideoXApp());

    // Verify that our app title is present
    expect(find.text('Video X'), findsOneWidget);
  });
}
