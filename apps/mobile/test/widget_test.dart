import 'package:flutter_test/flutter_test.dart';
import 'package:media_share_saver/main.dart';
import 'package:media_share_saver/resolver_client.dart';

class FakeResolver implements ResolverClient {
  FakeResolver({this.result, this.error});

  final ResolveResult? result;
  final ResolveException? error;
  int calls = 0;

  @override
  Future<ResolveResult> resolve(String url) async {
    calls++;
    if (error != null) throw error!;
    return result!;
  }
}

const resolvedMedia = ResolveResult(
  title: 'Example video',
  source: 'example',
  formats: [MediaFormat(formatId: 'best', url: 'https://cdn.example/video.mp4')],
);

void main() {
  testWidgets('shows idle state without shared text', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Ready to receive a shared URL'), findsOneWidget);
  });

  testWidgets('shows loading then resolve result', (tester) async {
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(
      MyApp(
        initialSharedText: 'https://example.com/video',
        resolver: resolver,
      ),
    );

    expect(find.text('Resolving URL'), findsOneWidget);
    await tester.pump();
    expect(find.text('Example video'), findsOneWidget);
    expect(find.textContaining('1 formats'), findsOneWidget);
    expect(resolver.calls, 1);
  });

  testWidgets('shows resolver error and retries', (tester) async {
    final resolver = FakeResolver(
      error: const ResolveException('Media resolution timed out.'),
    );
    await tester.pumpWidget(
      MyApp(
        initialSharedText: 'https://example.com/video',
        resolver: resolver,
      ),
    );
    await tester.pump();

    expect(find.text('Could not resolve URL'), findsOneWidget);
    expect(find.text('Media resolution timed out.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(resolver.calls, 1);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(resolver.calls, 2);
  });

  testWidgets('rejects non HTTP URL shared text', (tester) async {
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(
      MyApp(initialSharedText: 'file:///video.mp4', resolver: resolver),
    );

    expect(find.text('Invalid URL'), findsOneWidget);
    expect(find.text('Only HTTP and HTTPS URLs are supported.'), findsOneWidget);
    expect(resolver.calls, 0);
  });
}
