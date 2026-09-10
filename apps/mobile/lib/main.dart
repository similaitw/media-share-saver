import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'resolver_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialSharedText, this.resolver});

  final String? initialSharedText;
  final ResolverClient? resolver;

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
      ),
    );
  }
}

class SharedUrlScreen extends StatefulWidget {
  const SharedUrlScreen({
    super.key,
    this.initialSharedText,
    required this.resolver,
  });

  final String? initialSharedText;
  final ResolverClient resolver;

  @override
  State<SharedUrlScreen> createState() => _SharedUrlScreenState();
}

class _SharedUrlScreenState extends State<SharedUrlScreen> {
  static const _channel = MethodChannel('com.similaitw/media_share');
  String? _sharedUrl;
  String _status = 'idle';
  ResolveResult? _result;
  String? _errorMessage;

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

  @override
  Widget build(BuildContext context) {
    final title = switch (_status) {
      'loading' => 'Resolving URL',
      'resolved' => _result?.title ?? 'URL resolved',
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
              if (_status == 'loading')
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
                const Text('Ready for the next step. Media is not downloaded.'),
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
