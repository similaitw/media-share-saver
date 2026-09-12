import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_share_saver/download_history.dart';
import 'package:media_share_saver/download_service.dart';
import 'package:media_share_saver/main.dart';
import 'package:media_share_saver/resolver_client.dart';

class DeviceResolver implements ResolverClient {
  @override
  Future<ResolveResult> resolve(String url) async {
    return const ResolveResult(
      title: 'Device test video',
      source: 'device-test',
      formats: [
        MediaFormat(
          formatId: 'best',
          url: 'https://cdn.example/device-test.mp4',
          ext: 'mp4',
          width: 1280,
          height: 720,
        ),
      ],
    );
  }
}

class DeviceDownloader implements DownloadClient {
  @override
  DownloadOperation start(
    String url, {
    required void Function(DownloadProgress progress) onProgress,
  }) {
    final future = () async {
      final directory = await Directory.systemTemp.createTemp('device_test_');
      final file = File('${directory.path}${Platform.pathSeparator}media');
      await file.writeAsBytes([1, 2, 3]);
      onProgress(const DownloadProgress(receivedBytes: 3, totalBytes: 3));
      return file;
    }();
    return DownloadOperation(future, () {});
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.similaitw/media_share');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getSharedText':
          return null;
        case 'isMediaStoreSupported':
          return true;
        case 'saveMediaStore':
          return 'content://media/external/downloads/device-test';
        default:
          return null;
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('share to resolve, download, save, and history flow', (
    tester,
  ) async {
    final historyStore = DownloadHistoryStore();
    await tester.pumpWidget(
      MyApp(
        initialSharedText: 'https://example.com/device-test',
        resolver: DeviceResolver(),
        downloader: DeviceDownloader(),
        historyStore: historyStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Device test video'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(find.text('Saved to device'), findsOneWidget);
    expect(historyStore.entries, hasLength(1));
    expect(historyStore.entries.single.status, 'saved');

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    expect(find.text('Device test video'), findsOneWidget);
    expect(find.textContaining('Saved'), findsOneWidget);

    await tester.tap(find.text('Device test video'));
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/device-test'), findsOneWidget);
  });

  testWidgets('rejects unsupported shared text on device', (tester) async {
    await tester.pumpWidget(
      MyApp(
        initialSharedText: 'file:///sdcard/video.mp4',
        resolver: DeviceResolver(),
        downloader: DeviceDownloader(),
        historyStore: DownloadHistoryStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invalid URL'), findsOneWidget);
    expect(find.text('Only HTTP and HTTPS URLs are supported.'), findsOneWidget);
  });
}
