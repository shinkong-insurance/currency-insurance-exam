import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/level.dart';
import '../core/services/lk_auth_service.dart';

class LevelRepository {
  // lazy getter（而非在建構子就存取 Supabase.instance.client）：
  // 這樣即使在測試環境尚未呼叫 Supabase.initialize() 時，仍可安全建立
  // LevelRepository 實例（例如子類別覆寫方法、不觸碰真正的 Supabase 呼叫），
  // 只有在真的呼叫到 _sb 的方法（getLevels/isLevelPassed/saveLevelProgress
  // 未被覆寫的預設實作）時才會需要 Supabase 已初始化。
  SupabaseClient get _sb => Supabase.instance.client;
  List<Level>? _levels;

  Future<List<Level>> getLevels() async {
    if (_levels != null) return _levels!;
    final rows = await _sb.from('levels').select().order('order');
    _levels = List<Map<String, dynamic>>.from(rows).map(Level.fromMap).toList();
    return _levels!;
  }

  Future<bool> isLevelPassed(int levelId) async {
    final session = await LkAuthService.getSession();
    if (session == null) return false;
    final rows = await _sb
        .from('level_progress')
        .select('passed')
        .eq('key_id', session.keyId)
        .eq('device_id', session.deviceId)
        .eq('level_id', levelId)
        .limit(1);
    final list = List<Map<String, dynamic>>.from(rows);
    return list.isNotEmpty && list.first['passed'] == true;
  }

  Future<void> saveLevelProgress(int levelId,
      {required int attempted, required int correct, required bool passed}) async {
    final session = await LkAuthService.getSession();
    if (session == null) return; // 未登入不寫入，不影響作答流程
    await _sb.from('level_progress').upsert({
      'key_id': session.keyId,
      'device_id': session.deviceId,
      'level_id': levelId,
      'attempted': attempted,
      'correct': correct,
      'passed': passed,
      'last_attempt_at': DateTime.now().toIso8601String(),
    }, onConflict: 'key_id,device_id,level_id');
  }
}
