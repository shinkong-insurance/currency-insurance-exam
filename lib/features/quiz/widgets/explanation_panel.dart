import 'package:flutter/material.dart';
import '../../../models/question.dart';

/// 顯示作答後的解析區塊：
/// - 🎯 關鍵字破題（`keywordHint`，若有）
/// - 💬 白話告訴你為什麼（`plainExplanation`，若有；Task 17 尚未產製前為 null，不顯示）
/// - 📖 法規解析（原本的 `explanation`，一律顯示）
class ExplanationPanel extends StatelessWidget {
  final Question question;
  const ExplanationPanel({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 16, height: 1.6);
    // Material 包一層：ExpansionTile 內部的 ListTile 需要 Material 祖先才能畫
    // ink/splash 效果；quiz_page.dart 的 Scaffold 本身就會提供，但這裡額外包一層
    // (color: transparent) 讓這個元件本身可以獨立被任意地方（含測試中裸的
    // MaterialApp(home: ...)，沒有 Scaffold）安全地拿去用，不必依賴呼叫端環境。
    return Material(
      type: MaterialType.transparency,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (question.keywordHint != null && question.keywordHint!.isNotEmpty)
          ExpansionTile(
            title: const Text('🎯 關鍵字破題', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            initiallyExpanded: true,
            children: [Padding(padding: const EdgeInsets.all(12),
                child: Text(question.keywordHint!, style: textStyle))],
          ),
        if (question.plainExplanation != null && question.plainExplanation!.isNotEmpty)
          ExpansionTile(
            title: const Text('💬 白話告訴你為什麼', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            children: [Padding(padding: const EdgeInsets.all(12),
                child: Text(question.plainExplanation!, style: textStyle))],
          ),
        Padding(padding: const EdgeInsets.all(12),
            child: Text('📖 法規解析:${question.explanation}', style: textStyle)),
      ]),
    );
  }
}
