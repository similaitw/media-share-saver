import 'dart:async';
import 'dart:convert';
import 'dart:io';

class MediaFormat {
  const MediaFormat({
    required this.formatId,
    required this.url,
    this.ext,
    this.width,
    this.height,
    this.filesize,
  });

  final String formatId;
  final String url;
  final String? ext;
  final int? width;
  final int? height;
  final int? filesize;
}

class ResolveResult {
  const ResolveResult({
    required this.title,
    required this.source,
    required this.formats,
    this.thumbnail,
    this.duration,
  });

  final String title;
  final String source;
  final String? thumbnail;
  final double? duration;
  final List<MediaFormat> formats;

  factory ResolveResult.fromJson(Map<String, dynamic> json) {
    final rawFormats = json['formats'];
    final formats = rawFormats is List
        ? rawFormats
              .whereType<Map<String, dynamic>>()
              .map(
                (format) => MediaFormat(
                  formatId: format['format_id'] as String? ?? 'unknown',
                  url: format['url'] as String? ?? '',
                  ext: format['ext'] as String?,
                  width: format['width'] as int?,
                  height: format['height'] as int?,
                  filesize: format['filesize'] as int?,
                ),
              )
              .toList()
        : <MediaFormat>[];
    return ResolveResult(
      title: json['title'] as String? ?? 'Untitled media',
      source: json['source'] as String? ?? 'unknown',
      thumbnail: json['thumbnail'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      formats: formats,
    );
  }
}

class ResolveException implements Exception {
  const ResolveException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

abstract interface class ResolverClient {
  Future<ResolveResult> resolve(String url);
}

class HttpResolverClient implements ResolverClient {
  HttpResolverClient({String? baseUrl})
    : baseUrl = baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:8000',
          );

  final String baseUrl;

  @override
  Future<ResolveResult> resolve(String url) async {
    final client = HttpClient();
    try {
      final endpoint = Uri.parse('$baseUrl/api/v1/resolve');
      final request = await client.postUrl(endpoint).timeout(
        const Duration(seconds: 15),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'url': url}));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded is Map<String, dynamic>
            ? decoded['error'] as Map<String, dynamic>?
            : null;
        throw ResolveException(
          error?['message'] as String? ?? 'Unable to resolve this URL.',
          code: error?['code'] as String?,
        );
      }
      if (decoded is! Map<String, dynamic>) {
        throw const ResolveException('The resolver returned an invalid response.');
      }
      return ResolveResult.fromJson(decoded);
    } on ResolveException {
      rethrow;
    } on SocketException {
      throw const ResolveException('Could not connect to the resolver.');
    } on TimeoutException {
      throw const ResolveException('The resolver took too long to respond.');
    } on FormatException {
      throw const ResolveException('The resolver returned an invalid response.');
    } finally {
      client.close(force: true);
    }
  }
}
