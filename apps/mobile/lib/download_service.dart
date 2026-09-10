import 'dart:async';
import 'dart:io';

class DownloadProgress {
  const DownloadProgress({required this.receivedBytes, this.totalBytes});

  final int receivedBytes;
  final int? totalBytes;

  double? get fraction => totalBytes == null || totalBytes == 0
      ? null
      : receivedBytes / totalBytes!;
}

class DownloadException implements Exception {
  const DownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class DownloadClient {
  DownloadOperation start(
    String url, {
    required void Function(DownloadProgress progress) onProgress,
  });
}

class DownloadOperation {
  DownloadOperation(this.future, this._cancel);

  final Future<File> future;
  final void Function() _cancel;

  void cancel() => _cancel();
}

class HttpDownloadClient implements DownloadClient {
  @override
  DownloadOperation start(
    String url, {
    required void Function(DownloadProgress progress) onProgress,
  }) {
    final client = HttpClient();
    var cancelled = false;
    final completer = Completer<File>();
    _download(client, url, onProgress, completer, () => cancelled).whenComplete(
      client.close,
    );
    return DownloadOperation(completer.future, () {
      cancelled = true;
      client.close(force: true);
      if (!completer.isCompleted) {
        completer.completeError(const DownloadException('Download cancelled.'));
      }
    });
  }

  Future<void> _download(
    HttpClient client,
    String url,
    void Function(DownloadProgress progress) onProgress,
    Completer<File> completer,
    bool Function() isCancelled,
  ) async {
    File? output;
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const DownloadException('The media download failed.');
      }
      final directory = await Directory.systemTemp.createTemp('media_share_');
      output = File('${directory.path}${Platform.pathSeparator}media');
      final sink = output.openWrite();
      var received = 0;
      await for (final chunk in response) {
        if (isCancelled()) throw const DownloadException('Download cancelled.');
        sink.add(chunk);
        received += chunk.length;
        onProgress(
          DownloadProgress(
            receivedBytes: received,
            totalBytes: response.contentLength >= 0
                ? response.contentLength
                : null,
          ),
        );
      }
      await sink.close();
      if (!completer.isCompleted) completer.complete(output);
    } on DownloadException catch (error) {
      await output?.delete().catchError((_) => output!);
      if (!completer.isCompleted) completer.completeError(error);
    } on SocketException {
      await output?.delete().catchError((_) => output!);
      if (!completer.isCompleted) {
        completer.completeError(
          const DownloadException('Could not connect to the media URL.'),
        );
      }
    } on TimeoutException {
      await output?.delete().catchError((_) => output!);
      if (!completer.isCompleted) {
        completer.completeError(
          const DownloadException('The media download timed out.'),
        );
      }
    } catch (_) {
      await output?.delete().catchError((_) => output!);
      if (!completer.isCompleted) {
        completer.completeError(
          const DownloadException('The media download failed.'),
        );
      }
    }
  }
}
