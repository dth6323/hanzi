import 'package:flutter/material.dart';

import '../data/dict_db.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GrammarListScreen extends StatefulWidget {
  final String level;
  const GrammarListScreen({super.key, required this.level});
  @override
  State<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends State<GrammarListScreen> {
  late final Future<List<Grammar>> _future =
      DictDb.instance.grammarByLevel(widget.level);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ngữ pháp ${widget.level}')),
      body: FutureBuilder<List<Grammar>>(
        future: _future,
        builder: (_, s) {
          if (!s.hasData) return const Loading();
          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: s.data!.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final g = s.data![i];
              return ListTile(
                title: Text(g.title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: g.keywords.isEmpty
                    ? null
                    : Text(g.keywords,
                        style: const TextStyle(color: AppColors.gold)),
                onTap: () => Navigator.push(
                    context, appRoute((_) => GrammarDetailScreen(g))),
              );
            },
          );
        },
      ),
    );
  }
}

class GrammarDetailScreen extends StatelessWidget {
  final Grammar g;
  const GrammarDetailScreen(this.g, {super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(g.level)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(g.title,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          if (g.useFor.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(g.useFor,
                  style: const TextStyle(color: AppColors.muted)),
            ),
          const SizedBox(height: 16),
          for (final p in g.body)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(p,
                  style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: p.startsWith('Cấu trúc')
                          ? AppColors.gold
                          : AppColors.text,
                      fontWeight: p.startsWith('Cấu trúc') ||
                              p.endsWith(':')
                          ? FontWeight.w700
                          : FontWeight.normal)),
            ),
        ],
      ),
    );
  }
}
