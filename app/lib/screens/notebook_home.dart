import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/dict_db.dart';
import '../data/user_db.dart';
import '../theme.dart';
import '../version.dart';
import '../widgets/common.dart';
import 'flashcard_screen.dart';

class NotebookHome extends StatefulWidget {
  const NotebookHome({super.key});
  @override
  State<NotebookHome> createState() => NotebookHomeState();
}

class _NotebookData {
  final int streak;
  final ({int total, int due, int mastered}) srs;
  final List<Map<String, Object?>> favs;
  final List<SrsCard> dueCards;

  const _NotebookData({
    required this.streak,
    required this.srs,
    required this.favs,
    required this.dueCards,
  });
}

class NotebookHomeState extends State<NotebookHome> {
  late Future<_NotebookData> _future = _load();

  void refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<_NotebookData> _load() async {
    final db = UserDb.instance;
    final dueCards = await db.dueSrsCards();
    final streak = await db.streakDays();
    final srs = await db.srsSummary();
    final favs = await db.favorites();
    return _NotebookData(
      streak: streak,
      srs: srs,
      favs: favs,
      dueCards: dueCards,
    );
  }

  Future<void> _startSrsReview(List<SrsCard> cards) async {
    if (cards.isEmpty) {
      final all = await UserDb.instance.allSrsCards(limit: 30);
      if (all.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có thẻ nào. Hãy lưu từ hoặc thêm bộ HSK bên dưới!'),
          ),
        );
        return;
      }
      cards = all;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      appRoute((_) => FlashcardScreen(cards: cards)),
    );
    refresh();
  }

  Future<void> _addHskDeck(int level) async {
    final words = await DictDb.instance.wordsByHsk(level);
    final batch = words.take(30).map((w) => (
          id: w.id,
          simp: w.simp,
          pinyin: w.pinyin,
          mean: w.shortMean,
        ));
    await UserDb.instance.importWordsToSrs(batch);
    refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm 30 từ HSK $level vào bộ thẻ ôn tập!')),
      );
    }
  }

  Future<void> _showBackupSheet() async {
    final jsonStr = await UserDb.instance.exportBackupJson();
    File? file;
    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        file = File(p.join(dir.path, 'hanzi_backup.json'));
        await file.writeAsString(jsonStr, flush: true);
      } catch (_) {}
    }

    if (!mounted) return;
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 28 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sao lưu & Khôi phục Offline',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              file != null
                  ? 'Đã lưu bản dự phòng tại:\n${file.path}'
                  : 'Sao chép chuỗi JSON bên dưới để lưu trữ dự phòng.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã sao chép dữ liệu JSON vào bộ nhớ tạm!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy JSON sao lưu'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Khôi phục từ bản sao lưu JSON:',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Dán nội dung JSON sao lưu vào đây (hoặc để trống để đọc từ file hanzi_backup.json)…',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final raw = ctrl.text.trim().isNotEmpty
                        ? ctrl.text.trim()
                        : (file != null ? await file.readAsString() : '');
                    final count = await UserDb.instance.importBackupJson(raw);
                    if (ctx.mounted) Navigator.pop(ctx);
                    refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã khôi phục $count mục dữ liệu học!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi khôi phục: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.restore_rounded),
                label: const Text('Khôi phục dữ liệu'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<_NotebookData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Loading();
          final d = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Sổ tay & Ôn tập',
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sao lưu / Khôi phục',
                      icon: const Icon(Icons.save_alt_rounded,
                          color: AppColors.gold),
                      onPressed: _showBackupSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _srsDashboard(d),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text(
                        'Nạp nhanh thẻ:',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      for (var lv = 1; lv <= 4; lv++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text('+30 từ HSK $lv'),
                            onPressed: () => _addHskDeck(lv),
                          ),
                        ),
                    ],
                  ),
                ),
                const SectionTitle('Từ đã lưu'),
                if (d.favs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Chưa có từ yêu thích nào.\nBấm biểu tượng 🔖 ở trang chi tiết từ để lưu vào Sổ tay & Flashcard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  for (final f in d.favs) ...[
                    WordTile(
                      id: f['word_id'] as int,
                      simp: f['simp'] as String,
                      pinyin: (f['pinyin'] as String?) ?? '',
                      mean: (f['mean'] as String?) ?? '',
                    ),
                    const Divider(height: 1, indent: 16),
                  ],
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      const Text(
                        'Hán Tự · Từ điển & Luyện viết tiếng Trung',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          AppVersion.full,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _srsDashboard(_NotebookData d) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A1F1A), Color(0xFF1D1A18)],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCol('${d.streak}', 'Ngày liên tiếp 🔥', AppColors.gold),
              _statCol('${d.srs.due}', 'Cần ôn hôm nay', AppColors.primary),
              _statCol('${d.srs.mastered}/${d.srs.total}', 'Đã thuộc lòng',
                  AppColors.hint),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startSrsReview(d.dueCards),
              icon: const Icon(Icons.style_rounded),
              label: Text(
                d.srs.due > 0
                    ? 'Ôn tập ngay (${d.srs.due} thẻ đến hạn)'
                    : 'Ôn tập bộ thẻ Flashcard',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label, Color color) => Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      );
}
