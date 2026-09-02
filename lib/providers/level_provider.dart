import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level.dart';
import '../repositories/level_repository.dart';

final levelRepositoryProvider = Provider((ref) => LevelRepository());

final levelsProvider = FutureProvider<List<Level>>((ref) {
  return ref.read(levelRepositoryProvider).getLevels();
});

final levelPassedProvider = FutureProvider.family<bool, int>((ref, levelId) {
  return ref.read(levelRepositoryProvider).isLevelPassed(levelId);
});

final levelByIdProvider = FutureProvider.family<Level?, int>((ref, id) async {
  final levels = await ref.watch(levelsProvider.future);
  return levels.where((l) => l.id == id).firstOrNull;
});
