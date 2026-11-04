import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../data/models.dart';
import '../screens/word_screen.dart';
import '../services/speaker.dart';
import '../theme.dart';

/// Creates an iOS-native page route with [allowSnapshotting] explicitly set to false.
/// On Flutter with Impeller (iOS), route snapshotting during interactive edge-swipe
/// causes a fence timeout / dropped surface buffer, exposing the native window as a white flash.
/// Disabling snapshotting keeps both routes live on GPU at 60/120fps with zero white screen or delay.
PageRoute<T> appRoute<T>(WidgetBuilder builder, {RouteSettings? settings}) {
  return CupertinoPageRoute<T>(
    builder: builder,
    settings: settings,
    allowSnapshotting: false,
  );
}

class SpeakButton extends StatelessWidget {
  final String text;
  final double size;
  final bool slow;
  const SpeakButton(this.text, {super.key, this.size = 22, this.slow = false});

  @override
  Widget build(BuildContext context) => IconButton(
        visualDensity: VisualDensity.compact,
        iconSize: size,
        color: AppColors.gold,
        tooltip: slow ? 'Đọc chậm' : 'Phát âm',
        icon: Icon(slow ? Icons.slow_motion_video_rounded : Icons.volume_up_rounded),
        onPressed: () => Speaker.instance.speak(text, slow: slow),
      );
}

class WordTile extends StatelessWidget {
  final int id;
  final String simp;
  final String pinyin;
  final String mean;
  final int? hsk;
  final String? hanviet;

  const WordTile({
    super.key,
    required this.id,
    required this.simp,
    required this.pinyin,
    required this.mean,
    this.hsk,
    this.hanviet,
  });

  factory WordTile.fromWord(Word w) => WordTile(
      id: w.id,
      simp: w.simp,
      pinyin: w.pinyin,
      mean: w.shortMean,
      hsk: w.hsk,
      hanviet: w.hanviet);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        // Drop keyboard focus first: otherwise Flutter restores focus to the
        // search field when this route is popped, re-opening the keyboard and
        // relayouting the whole home screen during the back transition.
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.push(context, appRoute((_) => WordScreen(wordId: id)));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 56),
              child: Text(simp,
                  style: const TextStyle(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(pinyin,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      if (hanviet != null && hanviet!.isNotEmpty)
                        Text(hanviet!.toUpperCase(),
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                letterSpacing: 0.6)),
                      if (hsk != null) HskBadge(hsk!),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(mean,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(
      child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primary)));
}
