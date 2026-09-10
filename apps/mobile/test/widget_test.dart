import 'package:flutter_test/flutter_test.dart';
import 'package:media_share_saver/main.dart';

void main() {
  testWidgets('shows idle state without shared text', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Ready to receive a shared URL'), findsOneWidget);
  });

  testWidgets('shows a received HTTP URL', (tester) async {
    await tester.pumpWidget(
      const MyApp(initialSharedText: 'https://example.com/video'),
    );

    expect(find.text('URL received'), findsOneWidget);
    expect(find.text('https://example.com/video'), findsOneWidget);
  });

  testWidgets('rejects non HTTP URL shared text', (tester) async {
    await tester.pumpWidget(const MyApp(initialSharedText: 'file:///video.mp4'));

    expect(find.text('Invalid URL'), findsOneWidget);
    expect(find.text('Only HTTP and HTTPS URLs are supported.'), findsOneWidget);
  });
}
