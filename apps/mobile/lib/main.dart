import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialSharedText});

  final String? initialSharedText;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Share Saver',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: SharedUrlScreen(initialSharedText: initialSharedText),
    );
  }
}

class SharedUrlScreen extends StatefulWidget {
  const SharedUrlScreen({super.key, this.initialSharedText});

  final String? initialSharedText;

  @override
  State<SharedUrlScreen> createState() => _SharedUrlScreenState();
}

class _SharedUrlScreenState extends State<SharedUrlScreen> {
  static const _channel = MethodChannel('com.similaitw/media_share');
  String? _sharedUrl;
  String _status = 'idle';

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
    setState(() {
      _sharedUrl = isHttpUrl ? uri.toString() : null;
      _status = isHttpUrl ? 'received' : 'invalid';
    });
  }

  @override
  Widget build(BuildContext context) {
    final message = switch (_status) {
      'received' => 'URL received',
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
              Icon(
                _status == 'invalid' ? Icons.error_outline : Icons.link,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(message, style: Theme.of(context).textTheme.headlineSmall),
              if (_sharedUrl != null) ...[
                const SizedBox(height: 16),
                SelectableText(_sharedUrl!, textAlign: TextAlign.center),
              ],
              if (_status == 'invalid') ...[
                const SizedBox(height: 12),
                const Text('Only HTTP and HTTPS URLs are supported.'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
