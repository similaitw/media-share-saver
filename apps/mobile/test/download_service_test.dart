import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_share_saver/download_service.dart';

void main() {
  late HttpServer server;

  tearDown(() async {
    await server.close(force: true);
  });

  test('streams a media response and reports progress', () async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response
        ..headers.contentLength = 5
        ..add([1, 2, 3, 4, 5]);
      request.response.close();
    });
    final progress = <DownloadProgress>[];
    final operation = HttpDownloadClient().start(
      'http://${server.address.host}:${server.port}/media',
      onProgress: progress.add,
    );

    final file = await operation.future;
    expect(await file.readAsBytes(), [1, 2, 3, 4, 5]);
    expect(progress.last.receivedBytes, 5);
    expect(progress.last.fraction, 1);
    await file.parent.delete(recursive: true);
  });

  test('reports non-success responses as download errors', () async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
    });
    final operation = HttpDownloadClient().start(
      'http://${server.address.host}:${server.port}/missing',
      onProgress: (_) {},
    );

    await expectLater(
      operation.future,
      throwsA(
        isA<DownloadException>().having(
          (error) => error.message,
          'message',
          'The media download failed.',
        ),
      ),
    );
  });
}
