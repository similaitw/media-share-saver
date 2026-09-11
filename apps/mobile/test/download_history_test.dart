import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_share_saver/download_history.dart';
import 'package:media_share_saver/main.dart';

void main() {
  test('round trips a local history entry', () {
    final entry = DownloadHistoryEntry(
      title: 'Example video',
      url: 'https://example.com/video',
      format: 'mp4',
      status: 'saved',
      createdAt: DateTime.utc(2026, 9, 11),
    );

    final restored = DownloadHistoryEntry.fromJson(entry.toJson());

    expect(restored.title, entry.title);
    expect(restored.url, entry.url);
    expect(restored.format, entry.format);
    expect(restored.status, entry.status);
    expect(restored.createdAt, entry.createdAt);
  });

  testWidgets('history page shows its empty state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DownloadHistoryPage(entries: [])),
    );

    expect(find.text('No downloads yet.'), findsOneWidget);
  });
}
