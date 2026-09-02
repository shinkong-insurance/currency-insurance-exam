import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/mnemonic_provider.dart';

class MnemonicCardListPage extends ConsumerWidget {
  const MnemonicCardListPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(mnemonicCardsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('口訣卡')),
      body: cardsAsync.when(
        data: (cards) => cards.isEmpty
            ? const Center(child: Text('尚未有口訣卡,持續新增中'))
            : ListView(children: cards.map((c) => Card(
                child: ListTile(
                  title: Text(c.phrase,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text(c.meaning.join('\n'),
                      style: const TextStyle(fontSize: 16, height: 1.6)),
                ),
              )).toList()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('讀取失敗:$e')),
      ),
    );
  }
}
