import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/text_utils.dart';
import '../services/speaker.dart';
import '../theme.dart';
import 'common.dart';
import 'pronunciation_sheet.dart';
import '../screens/practice_screen.dart';

class ExampleView extends StatelessWidget {
  final Example e;
  const ExampleView(this.e, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Speaker.instance.speak(e.zh),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 34, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.zh, style: const TextStyle(fontSize: 17)),
                    if (e.pinyin.isNotEmpty)
                      Text(e.pinyin,
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 13)),
                    if (e.mean.isNotEmpty)
                      Text(e.mean,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              SpeakButton(e.zh, size: 20),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 19,
                color: AppColors.primary,
                tooltip: 'Luyện nói câu này',
                icon: const Icon(Icons.mic_none_rounded),
                onPressed: () => showPronunciationSheet(
                  context,
                  zh: e.zh,
                  pinyin: e.pinyin,
                  mean: e.mean,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 19,
                color: AppColors.gold,
                tooltip: 'Luyện viết câu này',
                icon: const Icon(Icons.draw_rounded),
                onPressed: () {
                  final chars = cjkCharsOrdered(e.zh);
                  if (chars.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Không có chữ Hán trong câu này')),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    appRoute((_) => PracticeScreen(
                          chars: chars,
                          title: 'Luyện viết câu ví dụ',
                          example: e,
                        )),
                  );
                },
              ),
            ],
          ),
        ),
      );
}
