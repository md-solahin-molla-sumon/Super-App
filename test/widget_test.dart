
import 'package:flutter_test/flutter_test.dart';
import 'package:nexaura/main.dart';

void main() {
  testWidgets('NEXAURA app loads successfully',
      (WidgetTester tester) async {

    await tester.pumpWidget(const NexauraApp());

    expect(find.text('NEXAURA'), findsOneWidget);
  });
}
