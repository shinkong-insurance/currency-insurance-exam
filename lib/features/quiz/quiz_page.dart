import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/chapter.dart';
import '../../models/level.dart';
import '../../models/question.dart';
import '../../providers/question_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../providers/level_provider.dart';
import '../../repositories/user_data_repository.dart';
import 'widgets/explanation_panel.dart';

class QuizPage extends ConsumerStatefulWidget {
  final int chapterId;
  final bool isWrongBook;
  final bool isFavorite;
  final bool isReviewMode;
  final int? levelId;

  const QuizPage({
    super.key,
    required this.chapterId,
    this.isWrongBook = false,
    this.isFavorite = false,
    this.isReviewMode = false,
    this.levelId,
  });

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  List<Question> _questions = [];
  int _currentIndex = 0;
  bool _isFav = false;
  bool _loading = true;
  int _correctCount = 0;

  /// 關卡模式下的關卡本身（用於 AppBar 標題與及格門檻）。
  Level? _level;

  /// 已作答題目：題目索引 -> 該題選擇的答案（顯示答案為 0）。
  ///
  /// 這裡刻意用「每題索引各自記錄」而不是單一的 `_showAnswer` bool（對照
  /// ExamPage 的 `_answers` 也是同樣形狀）：舊版按「上一題」會把 `_showAnswer`
  /// 重設成 false，於是回到已答過的題目再答一次，所有副作用會重跑一遍——
  /// 複習模式會重複呼叫 markReviewedCorrect/markReviewedWrong（streak 連跳，
  /// 錯題可能提前畢業）、關卡模式的 _correctCount 會超過題數（存進去的
  /// correct 大於 attempted）、一般模式則會灌水 wrong_count。
  final Map<int, int> _answeredSelections = {};

  bool get _showAnswer => _answeredSelections.containsKey(_currentIndex);
  int? get _selectedAnswer => _answeredSelections[_currentIndex];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final repo = ref.read(questionRepositoryProvider);
    final userRepo = ref.read(userDataRepositoryProvider);
    List<Question> qs;

    if (widget.levelId != null) {
      final level = await ref.read(levelByIdProvider(widget.levelId!).future);
      _level = level;
      qs = level == null ? [] : await repo.getQuestionsByIds(level.questionIds);
    } else if (widget.isReviewMode) {
      final dueIds = await userRepo.getDueWrongQuestionIds();
      qs = dueIds.isEmpty ? [] : await repo.getQuestionsByIds(dueIds);
    } else if (widget.isWrongBook) {
      final wrongIds = await userRepo.getWrongQuestionIds();
      qs = wrongIds.isEmpty ? [] : await repo.getQuestionsByIds(wrongIds);
    } else if (widget.isFavorite) {
      final favIds = await userRepo.getFavoriteIds();
      qs = favIds.isEmpty ? [] : await repo.getQuestionsByIds(favIds);
    } else {
      qs = await repo.getQuestionsByChapter(widget.chapterId);
    }

    if (mounted) {
      setState(() {
        _questions = qs;
        _loading = false;
      });
      if (qs.isNotEmpty) _checkFav();
    }
  }

  Future<void> _checkFav() async {
    if (_questions.isEmpty) return;
    final fav = await ref
        .read(userDataRepositoryProvider)
        .isFavorite(_questions[_currentIndex].id);
    if (mounted) setState(() => _isFav = fav);
  }

  Future<void> _submitAnswer(int answer) async {
    // 這題已經答過就完全不動作：畫面本來就已經在顯示上次的作答結果，
    // 任何計分/複習排程的副作用都不該再跑第二次。
    if (_answeredSelections.containsKey(_currentIndex)) return;
    final answeredIndex = _currentIndex;
    final q = _questions[answeredIndex];
    final isCorrect = answer == q.answer;
    final userRepo = ref.read(userDataRepositoryProvider);

    // 先同步記錄「這題已作答」再跑任何 await，否則在下面的 await 之間連點兩下
    // 會有兩次呼叫同時通過上面那道檢查，副作用還是會跑兩遍。
    setState(() => _answeredSelections[answeredIndex] = answer);

    if (isCorrect) {
      _correctCount++;
    } else if (!widget.isReviewMode) {
      await userRepo.addWrong(q.id);
      ref.invalidate(wrongIdsProvider); // 通知首頁更新錯題計數
    }

    if (widget.isReviewMode) {
      if (isCorrect) {
        await userRepo.markReviewedCorrect(q.id);
      } else {
        await userRepo.markReviewedWrong(q.id);
      }
      ref.invalidate(dueReviewCountProvider);
      ref.invalidate(wrongIdsProvider); // 複習模式答對可能畢業移出錯題本，答錯則不影響歸屬，
      // 兩種情況都一起 invalidate 較簡單；讀取到未變的 provider 只是一次低成本重抓。
    }
  }

  Future<void> _toggleFav() async {
    final q = _questions[_currentIndex];
    await ref.read(userDataRepositoryProvider).toggleFavorite(q.id);
    ref.invalidate(favoriteIdsProvider);
    final fav = await ref.read(userDataRepositoryProvider).isFavorite(q.id);
    if (mounted) setState(() => _isFav = fav);
  }

  // 前後移動只改變 index：該題是否已作答、選了什麼，都由
  // _answeredSelections 查表決定，不再靠一個共用的可變旗標。
  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
      _checkFav();
    } else {
      _saveProgressAndFinish();
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _checkFav();
    }
  }

  Future<void> _saveProgressAndFinish() async {
    if (widget.levelId != null) {
      // 用該關卡自己的門檻，不要寫死 0.7。目前每一關都是 0.7，所以這行今天沒有
      // 行為差異，但之後新增門檻不同的關卡就不會踩到。
      final threshold = _level?.passThreshold ?? 0.7;
      final passed =
          _questions.isNotEmpty && (_correctCount / _questions.length) >= threshold;
      await ref.read(levelRepositoryProvider).saveLevelProgress(
            widget.levelId!,
            attempted: _questions.length,
            correct: _correctCount,
            passed: passed,
          );
      ref.invalidate(levelPassedProvider(widget.levelId!));
    } else if (!widget.isWrongBook && !widget.isFavorite && !widget.isReviewMode) {
      await ref.read(userDataRepositoryProvider).updateProgress(
            widget.chapterId,
            _questions.length,
            _correctCount,
          );
      ref.invalidate(progressProvider);
    }
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('章節完成！'),
          content: Text('答題完成\n正確：$_correctCount / ${_questions.length}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              child: const Text('返回'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isReviewMode ? '今日複習' : '題庫練習'),
        ),
        body: const Center(child: Text('目前沒有題目')),
      );
    }

    final q = _questions[_currentIndex];
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isReviewMode
                  ? '今日複習'
                  : widget.isWrongBook
                      ? '錯題本'
                      : widget.isFavorite
                          ? '收藏題目'
                          // 關卡模式顯示關卡自己的名稱（共 18 關，考生需要知道
                          // 自己在第幾關），而不是退回通用的「章節練習」。
                          : widget.levelId != null
                              ? (_level?.label ?? '第 ${widget.levelId} 關')
                              : ref
                                  .watch(chaptersProvider)
                                  .valueOrNull
                                  ?.firstWhere(
                                    (c) => c.id == widget.chapterId,
                                    orElse: () => Chapter(
                                        id: 0,
                                        courseId: 1,
                                        unitNo: 1,
                                        title: '章節練習',
                                        weight: ''),
                                  )
                                  .title ??
                              '章節練習',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '第 ${_currentIndex + 1} 題 / 共 ${_questions.length} 題',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isFav ? Icons.bookmark : Icons.bookmark_border,
                color: _isFav ? Colors.amber : null),
            onPressed: _toggleFav,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: progress, minHeight: 4),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question number chip
                  Chip(
                    label: Text('第 ${q.questionNo} 題'),
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                  ),
                  const SizedBox(height: 12),
                  // Question text
                  Text(q.question,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          height: 1.6)),
                  const SizedBox(height: 20),
                  // Options
                  ...List.generate(
                      4,
                      (i) => _OptionTile(
                            index: i,
                            text: q.options[i],
                            selected: _selectedAnswer == i + 1,
                            isCorrect: q.answer == i + 1,
                            showResult: _showAnswer,
                            onTap: () => _submitAnswer(i + 1),
                          )),
                  // Explanation
                  if (_showAnswer) ExplanationPanel(question: q),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          // Bottom nav
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _currentIndex > 0 ? _prevQuestion : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('上一題'),
                  ),
                  const Spacer(),
                  if (!_showAnswer)
                    ElevatedButton.icon(
                      onPressed: () => _submitAnswer(0),
                      icon: const Icon(Icons.visibility),
                      label: const Text('顯示答案'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey),
                    ),
                  if (_showAnswer)
                    ElevatedButton.icon(
                      onPressed: _nextQuestion,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                          _currentIndex < _questions.length - 1 ? '下一題' : '完成'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool selected;
  final bool isCorrect;
  final bool showResult;
  final VoidCallback onTap;

  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.isCorrect,
    required this.showResult,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color? borderColor;

    if (showResult) {
      if (isCorrect) {
        bgColor = Colors.green.withOpacity(0.15);
        borderColor = Colors.green;
      } else if (selected && !isCorrect) {
        bgColor = Colors.red.withOpacity(0.15);
        borderColor = Colors.red;
      }
    } else if (selected) {
      bgColor = Theme.of(context).colorScheme.primaryContainer;
      borderColor = Theme.of(context).colorScheme.primary;
    }

    final labels = ['(1)', '(2)', '(3)', '(4)'];

    return GestureDetector(
      onTap: showResult ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: borderColor ?? Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Text(labels[index],
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        borderColor ?? Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
            if (showResult && isCorrect)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
            if (showResult && selected && !isCorrect)
              const Icon(Icons.cancel, color: Colors.red, size: 20),
          ],
        ),
      ),
    );
  }
}
