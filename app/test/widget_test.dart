import 'package:flutter_test/flutter_test.dart';

import 'package:smartai_dashboard/main.dart';

void main() {
  testWidgets('App boots with header', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartAIApp());
    await tester.pump();

    expect(find.text('AI 스마트 교통 신호 제어 시스템'), findsOneWidget);
  });
}
