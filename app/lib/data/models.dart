import 'dart:convert';

class Word {
  final int id;
  final String simp;
  final String trad;
  final String pinyin;
  final String hanviet;
  final int? hsk;
  final int? rank;
  final String shortMean;

  Word({
    required this.id,
    required this.simp,
    required this.trad,
    required this.pinyin,
    required this.hanviet,
    this.hsk,
    this.rank,
    required this.shortMean,
  });

  factory Word.fromRow(Map<String, Object?> r) => Word(
        id: r['id'] as int,
        simp: r['simp'] as String,
        trad: (r['trad'] as String?) ?? '',
        pinyin: (r['pinyin'] as String?) ?? '',
        hanviet: (r['hanviet'] as String?) ?? '',
        hsk: r['hsk'] as int?,
        rank: r['rank'] as int?,
        shortMean: (r['short_mean'] as String?) ?? '',
      );

  /// Traditional form, only when it differs from simplified.
  String? get tradIfDifferent => trad.isNotEmpty && trad != simp ? trad : null;
}

class Example {
  final int id;
  final String zh;
  final String pinyin;
  final String mean;
  Example(this.id, this.zh, this.pinyin, this.mean);

  factory Example.fromRow(Map<String, Object?> r) => Example(
        r['id'] as int,
        r['zh'] as String,
        // Source data contains zero-width spaces inside pinyin.
        ((r['pinyin'] as String?) ?? '').replaceAll('\u200b', ''),
        (r['mean'] as String?) ?? '',
      );
}

class Sense {
  final String? kind;
  final String gloss;
  final String? explain;
  final List<Example> examples;
  Sense({this.kind, required this.gloss, this.explain, required this.examples});
}

class Note {
  final String kind; // struct | compare
  final String title;
  final String body;
  final List<Example> examples;
  Note(
      {required this.kind,
      required this.title,
      required this.body,
      required this.examples});
}

class CharMeaning {
  final String reading;
  final List<String> items;
  CharMeaning(this.reading, this.items);
}

class HanChar {
  final String char;
  final String pinyin;
  final String hanviet;
  final int? strokeCount;
  final String? radical;
  final String? liushu;
  final String? ids;
  final List<String> components;
  final String strokeNames;
  final List<String> strokes; // SVG paths, 1024 box, y up
  final List<List<List<double>>> medians;
  final List<CharMeaning> meanings;
  final String? popular;

  HanChar({
    required this.char,
    required this.pinyin,
    required this.hanviet,
    this.strokeCount,
    this.radical,
    this.liushu,
    this.ids,
    required this.components,
    required this.strokeNames,
    required this.strokes,
    required this.medians,
    required this.meanings,
    this.popular,
  });

  bool get canWrite => strokes.isNotEmpty && strokes.length == medians.length;

  static List<dynamic> _json(Object? v) {
    final s = v as String?;
    if (s == null || s.isEmpty) return const [];
    try {
      return jsonDecode(s) as List<dynamic>;
    } catch (_) {
      return const [];
    }
  }

  factory HanChar.fromRow(Map<String, Object?> r) => HanChar(
        char: r['char'] as String,
        pinyin: (r['pinyin'] as String?) ?? '',
        hanviet: (r['hanviet'] as String?) ?? '',
        strokeCount: r['stroke_count'] as int?,
        radical: r['radical'] as String?,
        liushu: r['liushu'] as String?,
        ids: r['ids'] as String?,
        components: _json(r['components']).cast<String>(),
        strokeNames: (r['stroke_names'] as String?) ?? '',
        strokes: _json(r['strokes']).cast<String>(),
        medians: _json(r['medians'])
            .map((s) => (s as List)
                .map((pt) => (pt as List)
                    .map((n) => (n as num).toDouble())
                    .toList())
                .toList())
            .toList(),
        meanings: _json(r['meanings'])
            .map((m) => CharMeaning(
                  (m['reading'] as String?) ?? '',
                  ((m['items'] as List?) ?? const []).cast<String>(),
                ))
            .toList(),
        popular: r['popular'] as String?,
      );
}

class Topic {
  final int id;
  final String name;
  final int count;
  Topic(this.id, this.name, this.count);
}

class Grammar {
  final int id;
  final String level;
  final String title;
  final String useFor;
  final String keywords;
  final List<String> body;
  Grammar(this.id, this.level, this.title, this.useFor, this.keywords,
      this.body);

  factory Grammar.fromRow(Map<String, Object?> r) {
    List<String> body;
    try {
      body = (jsonDecode((r['body'] as String?) ?? '[]') as List)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      body = [(r['body'] as String?) ?? ''];
    }
    return Grammar(
      r['id'] as int,
      (r['level'] as String?) ?? '',
      r['title'] as String,
      (r['use_for'] as String?) ?? '',
      (r['keywords'] as String?) ?? '',
      body,
    );
  }
}

const posLabels = {
  'n': 'Danh từ',
  'v': 'Động từ',
  'adj': 'Tính từ',
  'adv': 'Phó từ',
  'pro': 'Đại từ',
  'num': 'Số từ',
  'm': 'Lượng từ',
  'prep': 'Giới từ',
  'conj': 'Liên từ',
  'part': 'Trợ từ',
  'int': 'Thán từ',
  'onom': 'Tượng thanh',
  'idiom': 'Thành ngữ',
};

const relLabels = {
  'compound': 'Từ ghép',
  'syno': 'Đồng nghĩa',
  'anto': 'Trái nghĩa',
  'measure': 'Lượng từ',
};
