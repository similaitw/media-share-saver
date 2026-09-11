import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'download_service.dart';
import 'download_history.dart';
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
    this.historyStore,
  });

  final String? initialSharedText;
  final ResolverClient? resolver;
  final DownloadClient? downloader;
  final DownloadHistoryStore? historyStore;

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
        historyStore: historyStore ?? DownloadHistoryStore(),
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
    required this.historyStore,
  });

  final String? initialSharedText;
  final ResolverClient resolver;
  final DownloadClient downloader;
  final DownloadHistoryStore historyStore;

  @override
  State<SharedUrlScreen> createState() => _SharedUrlScreenState();
}

class _SharedUrlScreenState extends State<SharedUrlScreen>
  with WidgetsBindingObserver {
  static const _channel = MethodChannel('com.similaitw/media_share');
  String? _sharedUrl;
  String _status = 'idle';
  ResolveResult? _result;
  String? _errorMessage;
  MediaFormat? _selectedFormat;
  DownloadOperation? _downloadOperation;
  double? _downloadFraction;
  bool _isInBackground = false;
  List<DownloadHistoryEntry> _historyEntries = [];
  String? _deviceWarning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadHistory());
    unawaited(_validateDevice());
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

  Future<void> _loadHistory() async {
    try {
      await widget.historyStore.load();
      if (mounted) {
        setState(() => _historyEntries = widget.historyStore.entries);
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _validateDevice() async {
    try {
      final supported = await _channel.invokeMethod<bool>(
        'isMediaStoreSupported',
      );
      if (mounted && supported == false) {
        setState(() => _deviceWarning = 'This Android version cannot save media.');
      }
    } on MissingPluginException {
      return;
    } on PlatformException {
      if (mounted) setState(() => _deviceWarning = 'Android storage is unavailable.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _isInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
      if (mounted && _status == 'downloading') setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel.setMethodCallHandler(null);
    super.dispose();
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

  Future<void> _downloadSelected() async {
    final format = _selectedFormat;
    final result = _result;
    if (format == null || result == null) return;
    if (_deviceWarning != null) {
      _setDownloadError(_deviceWarning!);
      return;
    }
    setState(() {
      _downloadFraction = null;
      _errorMessage = null;
      _status = 'downloading';
    });
    await widget.historyStore.setPending(
      DownloadHistoryEntry(
        title: result.title,
        url: _sharedUrl ?? '',
        format: format.ext ?? 'file',
        status: 'downloading',
        createdAt: DateTime.now(),
      ),
    );
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
        await widget.historyStore.completePending(status: 'saved');
        _historyEntries = widget.historyStore.entries;
        if (!mounted) return;
        setState(() => _status = 'saved');
      } on PlatformException catch (error) {
        await file.parent.delete(recursive: true);
        await widget.historyStore.completePending(status: 'failed');
        _historyEntries = widget.historyStore.entries;
        _setDownloadError(error.message ?? 'Could not save the media.');
      } catch (_) {
        await file.parent.delete(recursive: true);
        await widget.historyStore.completePending(status: 'failed');
        _historyEntries = widget.historyStore.entries;
        _setDownloadError('Could not save the media.');
      }
    }).catchError((Object error) {
      if (error is DownloadException && error.message == 'Download cancelled.') {
        unawaited(widget.historyStore.completePending(status: 'cancelled'));
        if (mounted) setState(() => _status = 'resolved');
      } else {
        unawaited(widget.historyStore.completePending(status: 'failed'));
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
      appBar: AppBar(
        title: const Text('Media Share Saver'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DownloadHistoryPage(entries: _historyEntries),
              ),
            ),
            icon: const Icon(Icons.history),
            tooltip: 'Download history',
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_deviceWarning != null) ...[
                Text(
                  _deviceWarning!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
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
                if (_isInBackground)
                  const Text('Download continues while the app is in the background.'),
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

class DownloadHistoryPage extends StatelessWidget {
  const DownloadHistoryPage({super.key, required this.entries});

  final List<DownloadHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Download history')),
      body: entries.isEmpty
          ? const Center(child: Text('No downloads yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return ListTile(
                  leading: Icon(
                    entry.status == 'saved'
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                  ),
                  title: Text(entry.title),
                  subtitle: Text(
                    '${entry.format} · ${entry.statusLabel} · ${entry.createdAt.toLocal()}',
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(entry.title),
                      content: SelectableText(entry.url),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
