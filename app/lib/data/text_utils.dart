final _cjk = RegExp(r'[\u3400-\u9fff\uf900-\ufaff\u{20000}-\u{2ffff}]',
    unicode: true);

bool hasCjk(String s) => _cjk.hasMatch(s);

/// Single CJK characters in [s] (in order, de-duplicated).
List<String> cjkChars(String s) {
  final seen = <String>{};
  return s.runes
      .map(String.fromCharCode)
      .where((c) => _cjk.hasMatch(c) && seen.add(c))
      .toList();
}

const _from =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
    'āǎēěīǐōǒūǔǖǘǚǜü';
const _to =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
    'aaeeiioouuvvvvv';

/// Strips Vietnamese and pinyin diacritics (input should be lower-case).
String removeDiacritics(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = _from.indexOf(c);
    b.write(i >= 0 ? _to[i] : c);
  }
  return b.toString();
}
