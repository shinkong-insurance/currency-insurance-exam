import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ContentCacheStore {
  final Future<SharedPreferences>? _prefsFuture;
  final Map<String, dynamic> _memory = {};

  ContentCacheStore(this._prefsFuture);
  ContentCacheStore.inMemory() : _prefsFuture = null;

  Future<List<Map<String, dynamic>>?> read(String key) async {
    if (_prefsFuture == null) {
      final v = _memory[key];
      return v == null ? null : List<Map<String, dynamic>>.from(v);
    }
    final prefs = await _prefsFuture;
    final raw = prefs.getString('content_cache_$key');
    if (raw == null) return null;
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    if (_prefsFuture == null) {
      _memory[key] = rows;
      return;
    }
    final prefs = await _prefsFuture;
    await prefs.setString('content_cache_$key', jsonEncode(rows));
  }
}
