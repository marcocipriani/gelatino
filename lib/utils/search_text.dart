const _folds = {
  'a': 'àáâãäåª',
  'c': 'ç',
  'e': 'èéêë',
  'i': 'ìíîï',
  'n': 'ñ',
  'o': 'òóôõöøº',
  'u': 'ùúûü',
};

final Map<String, String> _foldByChar = {
  for (final MapEntry(key: plain, value: marked) in _folds.entries)
    for (final char in marked.split('')) char: plain,
};

final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
final RegExp _foldable = RegExp('[${_folds.values.join()}]');

/// Lower case, no accents, punctuation as spaces: "Caffè dell'Orso" and
/// "caffe dell orso" are the same search.
String normalizeSearchText(String raw) => raw
    .toLowerCase()
    .replaceAllMapped(_foldable, (match) => _foldByChar[match[0]]!)
    .replaceAll(_separators, ' ')
    .trim();

// ponytail: linear scan, no typo tolerance. Fine for a few thousand places;
// index server-side when the catalog outgrows that.
/// How well [query] matches, lower is better, null when it doesn't. Every word
/// must appear in the name or in [detail], in any order. All three arguments
/// are already normalised.
int? searchRank(String query, {required String name, String detail = ''}) {
  if (query.isEmpty) return 0;
  if (name == query) return 0;
  if (name.startsWith(query)) return 1;
  final words = query.split(' ');
  final paddedName = ' $name';
  if (words.every((word) => paddedName.contains(' $word'))) return 2;
  if (words.every(name.contains)) return 3;
  if (words.every((word) => name.contains(word) || detail.contains(word))) {
    return 4;
  }
  return null;
}
