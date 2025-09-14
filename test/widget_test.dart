// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:phantom_flutter_app/main.dart';

void main() {
  testWidgets('Phantom app loads test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app title is present.
    expect(find.text('Phantom 지갑 테스트 앱'), findsWidgets);
    expect(find.text('지갑을 연결하여 시작하세요'), findsOneWidget);
  });
}
