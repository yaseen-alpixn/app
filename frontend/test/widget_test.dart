import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const VaslApp());

    // Verify that the title of the app 'VASL' is rendered.
    expect(find.text('VASL'), findsOneWidget);
  });
}
