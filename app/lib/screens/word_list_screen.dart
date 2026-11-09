import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/user_db.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'flashcard_screen.dart';

class WordListScreen extends StatelessWidget {
  final String title;
  final Future<List<Word>> future;
  const WordListScreen({super.key, required this.title, required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Word>>(
      future: future,
      builder: (context, s) {
        final words = s.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              if (words != null && words.isNotEmpty)
                TextButton.icon(
                  onPressed: () async {
                    final subset = words.take(30).toList();
                    await UserDb.instance.importWordsToSrs(subset.map((w) => (
                          id: w.id,
                          simp: w.simp,
                          pinyin: w.pinyin,
                          mean: w.shortMean,
                        )));
                    final cards = subset
                        .map((w) => SrsCard(
                              wordId: w.id,
                              simp: w.simp,
                              pinyin: w.pinyin,
                              mean: w.shortMean,
                              reps: 0,
                              intervalDays: 0,
                              ease: 2.5,
                              dueMs: 0,
                              lastReviewMs: 0,
                            ))
                        .toList();
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        appRoute((_) =>
                            FlashcardScreen(cards: cards, title: title)),
                      );
                    }
                  },
                  icon: const Icon(Icons.style_rounded,
                      color: AppColors.gold, size: 18),
                  label: const Text('Flashcard',
                      style: TextStyle(color: AppColors.gold)),
                ),
            ],
          ),
          body: words == null
              ? const Loading()
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: words.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (_, i) => WordTile.fromWord(words[i]),
                ),
        );
      },
    );
  }
}
