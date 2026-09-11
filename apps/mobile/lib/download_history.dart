import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DownloadHistoryEntry {
  const DownloadHistoryEntry({
    required this.title,
    required this.url,
    required this.format,
    required this.status,
    required this.createdAt,
  });

  final String title;
  final String url;
  final String format;
  final String status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'format': format,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DownloadHistoryEntry.fromJson(Map<String, dynamic> json) {
    return DownloadHistoryEntry(
      title: json['title'] as String? ?? 'Untitled media',
      url: json['url'] as String? ?? '',
      format: json['format'] as String? ?? 'file',
      status: json['status'] as String? ?? 'saved',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class DownloadHistoryStore {
  static const _fileName = 'download_history.json';
  static const _maxEntries = 25;
  List<DownloadHistoryEntry> _entries = [];
  DownloadHistoryEntry? _pending;

  List<DownloadHistoryEntry> get entries => List.unmodifiable(_entries);
  DownloadHistoryEntry? get pending => _pending;

  Future<void> load() async {
    final file = await _file();
    if (!await file.exists()) return;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      final rawEntries = decoded['entries'];
      _entries = rawEntries is List
          ? rawEntries
                .whereType<Map<String, dynamic>>()
                .map(DownloadHistoryEntry.fromJson)
                .toList()
          : [];
      final rawPending = decoded['pending'];
      _pending = rawPending is Map<String, dynamic>
          ? DownloadHistoryEntry.fromJson(rawPending)
          : null;
    } on FormatException {
      _entries = [];
      _pending = null;
    }
  }

  Future<void> setPending(DownloadHistoryEntry entry) async {
    _pending = entry;
    await _save();
  }

  Future<void> completePending({required String status}) async {
    final pending = _pending;
    if (pending != null) {
      _entries.insert(
        0,
        DownloadHistoryEntry(
          title: pending.title,
          url: pending.url,
          format: pending.format,
          status: status,
          createdAt: pending.createdAt,
        ),
      );
      if (_entries.length > _maxEntries) {
        _entries = _entries.take(_maxEntries).toList();
      }
    }
    _pending = null;
    await _save();
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _save() async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'entries': _entries.map((entry) => entry.toJson()).toList(),
        'pending': _pending?.toJson(),
      }),
    );
  }
}
