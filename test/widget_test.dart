// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:m_chess/main.dart';

void main() {
  testWidgets('Chess board renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MChessApp());

    expect(find.text('MChess'), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
  });
}
