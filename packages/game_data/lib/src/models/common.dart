/// 테이블 JSON 형식이 틀렸을 때. [path]는 `ship_parts.parts[2].growth` 꼴.
class TableFormatException implements Exception {
  const TableFormatException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => 'TableFormatException($path): $message';
}

/// 테이블 값 검증 실패 모음.
class TableValidationException implements Exception {
  const TableValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'TableValidationException:\n  ${errors.join('\n  ')}';
}

/// 경로를 기억하며 JSON 객체를 읽는 도우미. 틀린 타입은 어디가 틀렸는지 말해 준다.
class JsonReader {
  JsonReader(this.raw, this.path);

  final Map<String, dynamic> raw;
  final String path;

  T _get<T>(String key) {
    final v = raw[key];
    if (v is T) return v;
    throw TableFormatException('$path.$key', '$T 이어야 하는데 ${v.runtimeType}');
  }

  bool has(String key) => raw[key] != null;

  String str(String key) => _get<String>(key);
  String? strOrNull(String key) => raw[key] == null ? null : str(key);
  int integer(String key) => _get<num>(key).toInt();
  int? intOrNull(String key) => raw[key] == null ? null : integer(key);
  double number(String key) => _get<num>(key).toDouble();
  double numberOr(String key, double fallback) => raw[key] == null ? fallback : number(key);
  bool boolean(String key) => _get<bool>(key);

  JsonReader obj(String key) => JsonReader(_get<Map<String, dynamic>>(key), '$path.$key');

  List<JsonReader> objs(String key) {
    final list = _get<List<dynamic>>(key);
    return [
      for (var i = 0; i < list.length; i++) JsonReader(list[i] as Map<String, dynamic>, '$path.$key[$i]'),
    ];
  }

  List<String> strs(String key) => _get<List<dynamic>>(key).cast<String>();

  Map<String, double> numberMap(String key) => {
    for (final e in _get<Map<String, dynamic>>(key).entries) e.key: (e.value as num).toDouble(),
  };
}

/// 검증 도우미: 조건이 거짓이면 [errors]에 메시지를 더한다.
void expect(List<String> errors, {required bool that, required String message}) {
  if (!that) errors.add(message);
}

/// 부동소수 합 비교 허용 오차.
const probabilityEpsilon = 1e-9;
