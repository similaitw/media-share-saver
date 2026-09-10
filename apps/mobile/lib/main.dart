import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'download_service.dart';
import 'resolver_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    this.initialSharedText,
    this.resolver,
    this.downloader,
  });

  final String? initialSharedText;
  final ResolverClient? resolver;
  final DownloadClient? downloader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Share Saver',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: SharedUrlScreen(
        initialSharedText: initialSharedText,
        resolver: resolver ?? HttpResolverClient(),
        downloader: downloader ?? HttpDownloadClient(),
      ),
    );
  }
}

class SharedUrlScreen extends StatefulWidget {
  const SharedUrlScreen({
    super.key,
    this.initialSharedText,
    required this.resolver,
    required this.downloader,
  });

  final String? initialSharedText;
  final ResolverClient resolver;
  final DownloadClient downloader;

  @override
  State<SharedUrlScreen> createState() => _SharedUrlScreenState();
}

class _SharedUrlScreenState extends State<SharedUrlScreen> {
  static const _channel = MethodChannel('com.similaitw/media_share');
  String? _sharedUrl;
  String _status = 'idle';
  ResolveResult? _result;
  String? _errorMessage;
  MediaFormat? _selectedFormat;
  DownloadOperation? _downloadOperation;
  double? _downloadFraction;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        _handleSharedText(call.arguments as String);
      }
    });
    if (widget.initialSharedText != null) {
      _handleSharedText(widget.initialSharedText!);
    } else {
      _loadInitialSharedText();
    }
  }

  Future<void> _loadInitialSharedText() async {
    try {
      final sharedText = await _channel.invokeMethod<String>('getSharedText');
      if (sharedText != null) {
        _handleSharedText(sharedText);
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  void _handleSharedText(String text) {
    final uri = Uri.tryParse(text.trim());
    final isHttpUrl = uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme.toLowerCase() == 'http' ||
            uri.scheme.toLowerCase() == 'https');
    if (!isHttpUrl) {
      setState(() {
        _sharedUrl = null;
        _result = null;
        _errorMessage = null;
        _status = 'invalid';
      });
      return;
    }
    setState(() {
      _sharedUrl = uri.toString();
      _result = null;
      _errorMessage = null;
      _status = 'loading';
    });
    _resolve(uri.toString());
  }

  Future<void> _resolve(String url) async {
    try {
      final result = await widget.resolver.resolve(url);
      if (!mounted || _sharedUrl != url) return;
      setState(() {
        _result = result;
        _selectedFormat = result.formats.isEmpty ? null : result.formats.first;
        _status = 'resolved';
      });
    } on ResolveException catch (error) {
      if (!mounted || _sharedUrl != url) return;
      setState(() {
        _errorMessage = error.message;
        _status = 'error';
      });
    } catch (_) {
      if (!mounted || _sharedUrl != url) return;
      setState(() {
        _errorMessage = 'Unable to resolve this URL.';
        _status = 'error';
      });
    }
  }

  void _retry() {
    final url = _sharedUrl;
    if (url == null) return;
    setState(() {
      _errorMessage = null;
      _status = 'loading';
    });
    _resolve(url);
  }

  void _downloadSelected() {
    final format = _selectedFormat;
    final result = _result;
    if (format == null || result == null) return;
    setState(() {
      _downloadFraction = null;
      _errorMessage = null;
      _status = 'downloading';
    });
    final operation = widget.downloader.start(
      format.url,
      onProgress: (progress) {
        if (!mounted) return;
        setState(() => _downloadFraction = progress.fraction);
      },
    );
    _downloadOperation = operation;
    operation.future.then((file) async {
      try {
        await _saveToMediaStore(file, result.title, format.ext);
        await file.parent.delete(recursive: true);
        if (!mounted) return;
        setState(() => _status = 'saved');
      } on PlatformException catch (error) {
        await file.parent.delete(recursive: true);
        _setDownloadError(error.message ?? 'Could not save the media.');
      } catch (_) {
        await file.parent.delete(recursive: true);
        _setDownloadError('Could not save the media.');
      }
    }).catchError((Object error) {
      if (error is DownloadException && error.message == 'Download cancelled.') {
        if (mounted) setState(() => _status = 'resolved');
      } else {
        _setDownloadError(
          error is DownloadException
              ? error.message
              : 'The media download failed.',
        );
      }
    });
  }

  Future<void> _saveToMediaStore(
    File file,
    String title,
    String? extension,
  ) async {
    final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
    final suffix = extension == null || extension.isEmpty ? 'bin' : extension;
    await _channel.invokeMethod<String>('saveMediaStore', {
      'path': file.path,
      'name': '$safeTitle.$suffix',
      'mimeType': _mimeType(suffix),
    });
  }

  String _mimeType(String extension) {
    return switch (extension.toLowerCase()) {
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'mkv' => 'video/x-matroska',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }

  void _setDownloadError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _status = 'download_error';
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_status) {
      'loading' => 'Resolving URL',
      'resolved' => _result?.title ?? 'URL resolved',
      'downloading' => 'Downloading media',
      'saved' => 'Saved to device',
      'download_error' => 'Download failed',
      'error' => 'Could not resolve URL',
      'invalid' => 'Invalid URL',
      _ => 'Ready to receive a shared URL',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Media Share Saver')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_status == 'loading' || _status == 'downloading')
                const CircularProgressIndicator()
              else
                Icon(
                  _status == 'error' || _status == 'invalid'
                      ? Icons.error_outline
                      : Icons.link,
                  size: 56,
                ),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center),
              if (_sharedUrl != null) ...[
                const SizedBox(height: 12),
                SelectableText(_sharedUrl!, textAlign: TextAlign.center),
              ],
              if (_status == 'resolved' && _result != null) ...[
                const SizedBox(height: 12),
                Text('${_result!.source} · ${_result!.formats.length} formats'),
                const SizedBox(height: 4),
                if (_result!.formats.isNotEmpty)
                  DropdownButton<MediaFormat>(
                    value: _selectedFormat,
                    items: _result!.formats
                        .map(
                          (format) => DropdownMenuItem(
                            value: format,
                            child: Text(
                              '${format.ext ?? 'file'} ${format.width ?? ''}x${format.height ?? ''}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (format) =>
                        setState(() => _selectedFormat = format),
                  ),
                FilledButton.icon(
                  onPressed: _selectedFormat == null ? null : _downloadSelected,
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ],
              if (_status == 'downloading') ...[
                const SizedBox(height: 12),
                if (_downloadFraction != null)
                  Text('${(_downloadFraction! * 100).round()}%'),
                TextButton.icon(
                  onPressed: () => _downloadOperation?.cancel(),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                ),
              ],
              if (_status == 'saved') ...[
                const SizedBox(height: 12),
                const Text('The media was saved to your Downloads folder.'),
              ],
              if (_status == 'download_error') ...[
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'The media download failed.'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _downloadSelected,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry download'),
                ),
              ],
              if (_status == 'invalid') ...[
                const SizedBox(height: 12),
                const Text('Only HTTP and HTTPS URLs are supported.'),
              ],
              if (_status == 'error') ...[
                const SizedBox(height: 12),
                Text(_errorMessage ?? 'Unable to resolve this URL.'),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
