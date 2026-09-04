import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 'fx_' 前綴：見 shared_preferences_store.dart 的說明——同網域下的
// insurance-exam-app 共用 localStorage，沒有前綴的話兩個 app 的內容快取
// 會互相污染。
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
    final raw = prefs.getString('fx_content_cache_$key');
    if (raw == null) return null;
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    if (_prefsFuture == null) {
      _memory[key] = rows;
      return;
    }
    final prefs = await _prefsFuture;
    await prefs.setString('fx_content_cache_$key', jsonEncode(rows));
  }
}
