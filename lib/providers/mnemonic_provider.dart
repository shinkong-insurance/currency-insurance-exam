import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mnemonic_card.dart';
import '../repositories/mnemonic_repository.dart';

final mnemonicRepositoryProvider = Provider((ref) => MnemonicRepository());

final mnemonicCardsProvider = FutureProvider<List<MnemonicCard>>((ref) {
  return ref.read(mnemonicRepositoryProvider).getApprovedCards();
});
