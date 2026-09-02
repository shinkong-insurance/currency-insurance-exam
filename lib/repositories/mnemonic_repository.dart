import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mnemonic_card.dart';

class MnemonicRepository {
  final _sb = Supabase.instance.client;

  Future<List<MnemonicCard>> getApprovedCards() async {
    // approved=true 已經由 Task 2 的 RLS policy 在資料庫層強制，這裡不用再過濾一次
    final rows = await _sb.from('mnemonic_cards').select();
    return List<Map<String, dynamic>>.from(rows).map(MnemonicCard.fromMap).toList();
  }
}
