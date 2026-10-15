import 'dart:convert';

/// `sim --set table.a.b=값` — 테이블 JSON 원문 [raw]에 값을 덮어쓴 사본 (탐색용, 다시 빌드하지 않고 변형 비교).
/// 값은 JSON으로 읽는다. 없는 키면 오타로 보고 실패한다. 검증은 GameTables.load가 그대로 한다.
Map<String, String> patchTables(Map<String, String> raw, List<String> sets) {
  final out = {...raw};
  for (final x in sets) {
    final eq = x.indexOf('=');
    if (eq < 0) throw ArgumentError('--set: table.key=값 형식이어야 함 ($x)');
    final path = x.substring(0, eq).split('.');
    final text = out[path.first];
    if (text == null || path.length < 2) throw ArgumentError('--set: 없는 테이블 ${path.first}');
    final table = jsonDecode(text) as Map<String, dynamic>;
    var node = table;
    for (final k in path.sublist(1, path.length - 1)) {
      node = node[k] as Map<String, dynamic>;
    }
    if (!node.containsKey(path.last)) throw ArgumentError('--set: 없는 키 ${path.join('.')}');
    node[path.last] = jsonDecode(x.substring(eq + 1));
    out[path.first] = jsonEncode(table);
  }
  return out;
}
