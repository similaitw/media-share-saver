import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_share_saver/main.dart';
import 'package:media_share_saver/resolver_client.dart';

class FakeResolver implements ResolverClient {
  FakeResolver({this.result, this.error});

  final ResolveResult? result;
  final ResolveException? error;
  int calls = 0;
  final urls = <String>[];

  @override
  Future<ResolveResult> resolve(String url) async {
    calls++;
    urls.add(url);
    if (error != null) throw error!;
    return result!;
  }
}

class DeferredResolver implements ResolverClient {
  final requests = <String, Completer<ResolveResult>>{};
  final urls = <String>[];

  @override
  Future<ResolveResult> resolve(String url) {
    urls.add(url);
    return (requests[url] = Completer<ResolveResult>()).future;
  }
}

const resolvedMedia = ResolveResult(
  title: 'Example video',
  source: 'example',
  formats: [MediaFormat(formatId: 'best', url: 'https://cdn.example/video.mp4')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const field = Key('manual-url-field');
  const resolveButton = Key('resolve-url-button');
  const pasteButton = Key('paste-url-button');
  const shareChannel = MethodChannel('com.similaitw/media_share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(shareChannel, null);
  });

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

  testWidgets('manual HTTPS URL uses the resolver flow', (tester) async {
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(MyApp(resolver: resolver));

    await tester.enterText(
      find.byKey(const Key('manual-url-field')),
      'https://example.com/manual',
    );
    await tester.tap(find.byKey(const Key('resolve-url-button')));
    await tester.pump();
    expect(find.text('Example video'), findsOneWidget);
    expect(resolver.calls, 1);
    expect(resolver.urls, ['https://example.com/manual']);
  });

  testWidgets('Clipboard URL uses the same resolver flow', (tester) async {
    final resolver = FakeResolver(result: resolvedMedia);
    final messenger = TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': 'https://example.com/clipboard'};
      }
      return null;
    });

    try {
      await tester.pumpWidget(MyApp(resolver: resolver));
      await tester.tap(find.byKey(const Key('paste-url-button')));
      await tester.pump();
      expect(find.text('Example video'), findsOneWidget);
      expect(resolver.calls, 1);
      expect(resolver.urls, ['https://example.com/clipboard']);
      expect(
        tester.widget<TextField>(find.byKey(field)).controller!.text,
        'https://example.com/clipboard',
      );
    } finally {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    }
  });

  testWidgets('keyboard submit resolves an edited HTTP URL', (tester) async {
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(MyApp(resolver: resolver));
    await tester.enterText(find.byKey(field), 'unfinished');
    await tester.enterText(find.byKey(field), '  http://example.com/edited  ');
    expect(resolver.calls, 0);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(resolver.urls, ['http://example.com/edited']);
    expect(find.text('Example video'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  for (final text in [
    'not a URL',
    'file:///video.mp4',
    'https://',
    'https://example.com/video extra text',
    '',
  ]) {
    testWidgets('manual Resolve rejects "$text"', (tester) async {
      final resolver = FakeResolver(result: resolvedMedia);
      await tester.pumpWidget(MyApp(resolver: resolver));
      await tester.enterText(find.byKey(field), text);
      await tester.tap(find.byKey(resolveButton));
      await tester.pump();

      expect(find.text('Invalid URL'), findsOneWidget);
      expect(resolver.calls, 0);
    });
  }

  for (final text in ['not a URL', 'file:///video.mp4', '', null]) {
    testWidgets('Paste rejects clipboard text "$text"', (tester) async {
      final resolver = FakeResolver(result: resolvedMedia);
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData' && text != null) {
          return <String, dynamic>{'text': text};
        }
        return null;
      });
      await tester.pumpWidget(MyApp(resolver: resolver));
      await tester.tap(find.byKey(pasteButton));
      await tester.pump();

      expect(find.text('Invalid URL'), findsOneWidget);
      expect(find.text('Only HTTP and HTTPS URLs are supported.'), findsOneWidget);
      expect(resolver.calls, 0);
    });
  }

  testWidgets('duplicate submissions reuse the pending resolve', (tester) async {
    final resolver = DeferredResolver();
    const url = 'https://example.com/video';
    await tester.pumpWidget(MyApp(resolver: resolver));
    await tester.enterText(find.byKey(field), url);
    await tester.tap(find.byKey(resolveButton));
    await tester.tap(find.byKey(resolveButton));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(resolver.urls, [url]);
    resolver.requests[url]!.complete(resolvedMedia);
    await tester.pump();
    expect(find.text('Example video'), findsOneWidget);
  });

  testWidgets('editing away and back reuses only the current URL result', (
    tester,
  ) async {
    final resolver = DeferredResolver();
    const first = 'https://example.com/first';
    const second = 'https://example.com/second';
    await tester.pumpWidget(MyApp(resolver: resolver));
    for (final url in [first, second, first]) {
      await tester.enterText(find.byKey(field), url);
      await tester.tap(find.byKey(resolveButton));
      await tester.pump();
    }
    expect(resolver.urls, [first, second]);

    resolver.requests[first]!.complete(resolvedMedia);
    await tester.pump();
    resolver.requests[second]!.completeError(const ResolveException('Stale error'));
    await tester.pump();

    expect(find.text('Example video'), findsOneWidget);
    expect(find.text('Stale error'), findsNothing);
  });

  testWidgets('editing invalidates an outstanding resolver response', (
    tester,
  ) async {
    final resolver = DeferredResolver();
    const url = 'https://example.com/video';
    await tester.pumpWidget(MyApp(initialSharedText: url, resolver: resolver));
    await tester.enterText(find.byKey(field), 'unfinished edit');
    resolver.requests[url]!.complete(resolvedMedia);
    await tester.pump();

    expect(find.text('Example video'), findsNothing);
    expect(find.text('Download'), findsNothing);
    await tester.tap(find.byKey(resolveButton));
    await tester.pump();
    expect(find.text('Invalid URL'), findsOneWidget);
  });

  testWidgets('delayed clipboard cannot overwrite a newer manual submission', (
    tester,
  ) async {
    final clipboard = Completer<Object?>();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return clipboard.future;
      return null;
    });
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(MyApp(resolver: resolver));
    await tester.tap(find.byKey(pasteButton));
    await tester.enterText(find.byKey(field), 'https://example.com/manual');
    await tester.tap(find.byKey(resolveButton));
    clipboard.complete({'text': 'https://example.com/old-clipboard'});
    await tester.pump();

    expect(resolver.urls, ['https://example.com/manual']);
    expect(
      tester.widget<TextField>(find.byKey(field)).controller!.text,
      'https://example.com/manual',
    );
  });

  testWidgets('late initial share cannot overwrite manual input', (tester) async {
    final initialShare = Completer<String?>();
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      if (call.method == 'getSharedText') return initialShare.future;
      return null;
    });
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(MyApp(resolver: resolver));
    await tester.enterText(find.byKey(field), 'https://example.com/manual');
    initialShare.complete('https://example.com/old-share');
    await tester.pump();

    expect(resolver.calls, 0);
    expect(
      tester.widget<TextField>(find.byKey(field)).controller!.text,
      'https://example.com/manual',
    );
  });

  testWidgets('Share Sheet channel still resolves while the app is open', (
    tester,
  ) async {
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(MyApp(resolver: resolver));
    await tester.enterText(find.byKey(field), 'unfinished edit');
    tester.binding.channelBuffers.push(
      shareChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('sharedText', 'https://example.com/shared'),
      ),
      (_) {},
    );
    await tester.pump();

    expect(resolver.urls, ['https://example.com/shared']);
    expect(find.text('Example video'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(field)).controller!.text,
      'https://example.com/shared',
    );
  });

  testWidgets('URL controls remain usable with the keyboard open', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    final resolver = FakeResolver(result: resolvedMedia);
    await tester.pumpWidget(MyApp(resolver: resolver));
    await tester.enterText(find.byKey(field), 'https://example.com/video');
    await tester.ensureVisible(find.byKey(resolveButton));
    await tester.tap(find.byKey(resolveButton));
    await tester.pump();

    expect(tester.takeException(), isNull);
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
