import 'package:flutter/foundation.dart';

/// What a search item is.
enum SearchKind {
  /// A song: the subtitle is the artist.
  song,

  /// A place: the subtitle is the city or province.
  place,
}

/// One searchable item of the example (titles only, no lyrics).
@immutable
class SearchItem {
  /// Creates an item.
  const SearchItem(this.title, this.subtitle, this.kind, this.category);

  /// Song or place name.
  final String title;

  /// Artist or location.
  final String subtitle;

  /// Song or place.
  final SearchKind kind;

  /// One of [kSearchCategories].
  final String category;
}

/// The search scopes, in `LiquidSearchScopeBar` order.
const kSearchScopes = ['All', 'Songs', 'Places'];

/// The category tiles of the idle search page.
const kSearchCategories = [
  'Nhạc Trịnh',
  'Bolero',
  'Hà Nội',
  'Sài Gòn',
  'Miền Trung',
  'Miền Tây',
  'Cà phê',
  'Thiên nhiên',
];

/// The local dataset (Vietnamese titles exercise the diacritics).
const kSearchItems = [
  SearchItem('Diễm xưa', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Hạ trắng', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Biển nhớ', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Cát bụi', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem(
    'Nối vòng tay lớn',
    'Trịnh Công Sơn',
    SearchKind.song,
    'Nhạc Trịnh',
  ),
  SearchItem(
    'Ru ta ngậm ngùi',
    'Trịnh Công Sơn',
    SearchKind.song,
    'Nhạc Trịnh',
  ),
  SearchItem('Thành phố buồn', 'Lam Phương', SearchKind.song, 'Bolero'),
  SearchItem('Đắp mộ cuộc tình', 'Vinh Sử', SearchKind.song, 'Bolero'),
  SearchItem('Duyên phận', 'Thái Thịnh', SearchKind.song, 'Bolero'),
  SearchItem(
    'Còn thương rau đắng mọc sau hè',
    'Bắc Sơn',
    SearchKind.song,
    'Miền Tây',
  ),
  SearchItem(
    'Hà Nội mùa vắng những cơn mưa',
    'Trương Quý Hải',
    SearchKind.song,
    'Hà Nội',
  ),
  SearchItem('Em ơi Hà Nội phố', 'Phú Quang', SearchKind.song, 'Hà Nội'),
  SearchItem('Nồng nàn Hà Nội', 'Nguyễn Đức Cường', SearchKind.song, 'Hà Nội'),
  SearchItem('Sài Gòn đẹp lắm', 'Y Vân', SearchKind.song, 'Sài Gòn'),
  SearchItem(
    'Mùa xuân trên thành phố Hồ Chí Minh',
    'Xuân Hồng',
    SearchKind.song,
    'Sài Gòn',
  ),
  SearchItem('Hồ Hoàn Kiếm', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Văn Miếu – Quốc Tử Giám', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Phố cổ Hà Nội', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Hồ Tây', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Cà phê Giảng', 'Hà Nội', SearchKind.place, 'Cà phê'),
  SearchItem('Chợ Bến Thành', 'TP. Hồ Chí Minh', SearchKind.place, 'Sài Gòn'),
  SearchItem('Nhà thờ Đức Bà', 'TP. Hồ Chí Minh', SearchKind.place, 'Sài Gòn'),
  SearchItem(
    'Bưu điện Thành phố',
    'TP. Hồ Chí Minh',
    SearchKind.place,
    'Sài Gòn',
  ),
  SearchItem(
    'Phố đi bộ Nguyễn Huệ',
    'TP. Hồ Chí Minh',
    SearchKind.place,
    'Sài Gòn',
  ),
  SearchItem(
    'Cà phê vợt Cheo Leo',
    'TP. Hồ Chí Minh',
    SearchKind.place,
    'Cà phê',
  ),
  SearchItem('Phố cổ Hội An', 'Quảng Nam', SearchKind.place, 'Miền Trung'),
  SearchItem(
    'Kinh thành Huế',
    'Thừa Thiên Huế',
    SearchKind.place,
    'Miền Trung',
  ),
  SearchItem('Cầu Rồng', 'Đà Nẵng', SearchKind.place, 'Miền Trung'),
  SearchItem('Bà Nà', 'Đà Nẵng', SearchKind.place, 'Miền Trung'),
  SearchItem('Chợ nổi Cái Răng', 'Cần Thơ', SearchKind.place, 'Miền Tây'),
  SearchItem('Cù lao Thới Sơn', 'Tiền Giang', SearchKind.place, 'Miền Tây'),
  SearchItem('Rừng tràm Trà Sư', 'An Giang', SearchKind.place, 'Miền Tây'),
  SearchItem('Vịnh Hạ Long', 'Quảng Ninh', SearchKind.place, 'Thiên nhiên'),
  SearchItem('Sa Pa', 'Lào Cai', SearchKind.place, 'Thiên nhiên'),
  SearchItem('Đà Lạt', 'Lâm Đồng', SearchKind.place, 'Thiên nhiên'),
  SearchItem('Phú Quốc', 'Kiên Giang', SearchKind.place, 'Thiên nhiên'),
];

const _foldGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _fold = {
  for (final MapEntry(:key, :value) in _foldGroups.entries)
    for (final rune in value.runes) rune: key,
};

/// Lower case without Vietnamese marks: "Hồ Hoàn Kiếm" → "ho hoan kiem".
/// Combining marks (decomposed input) are dropped too.
String foldVietnamese(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    out.write(_fold[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}

final _wordBreak = RegExp('[^a-z0-9]+');

List<String> _words(String text) => [
  for (final word in foldVietnamese(text).split(_wordBreak))
    if (word.isNotEmpty) word,
];

/// Whether every word of [query] starts a word of the item's title or
/// subtitle, ignoring case and marks.
bool searchMatches(SearchItem item, String query) {
  final wanted = _words(query);
  if (wanted.isEmpty) return false;
  final words = _words('${item.title} ${item.subtitle}');
  return wanted.every((w) => words.any((word) => word.startsWith(w)));
}

/// The items matching [query] in [scope] (0 all, 1 songs, 2 places).
List<SearchItem> searchResults(String query, {required int scope}) => [
  for (final item in kSearchItems)
    if ((scope == 0 ||
            (scope == 1 && item.kind == SearchKind.song) ||
            (scope == 2 && item.kind == SearchKind.place)) &&
        searchMatches(item, query))
      item,
];

/// [recents] with [query] first: a folded duplicate goes, six at most.
List<String> rememberQuery(List<String> recents, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return recents;
  final key = foldVietnamese(trimmed);
  return [
    trimmed,
    for (final q in recents)
      if (foldVietnamese(q) != key) q,
  ].take(6).toList();
}
