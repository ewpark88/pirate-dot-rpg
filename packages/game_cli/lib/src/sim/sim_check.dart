/// 지표 하나의 판정. [value]가 null이면 시뮬 시간 안에 도달하지 못함.
class SimCheck {
  SimCheck(
    this.key,
    this.label,
    this.value,
    this.min,
    this.max, {
    required this.unit,
    this.requiredWithin,
    this.applies = true,
    this.onlyIfReached = false,
  });

  final String key;
  final String label;
  final double? value;
  final double min;
  final double max;
  final String unit;

  /// 이 지표를 판정하려면 시뮬이 이만큼은 돌아야 한다. 더 짧으면 미도달을 ‘판정 안 함’으로 본다.
  final Duration? requiredWithin;

  /// 목표가 이 접속 일정용인가 (`schedule` 키, 없으면 모든 일정).
  final bool applies;

  /// 값이 없으면(그 일이 일어나지 않았으면) 판정하지 않는다.
  final bool onlyIfReached;

  bool judged(Duration played) =>
      applies && (value != null || (!onlyIfReached && (requiredWithin == null || played >= requiredWithin!)));
  bool ok(Duration played) => !judged(played) || (value != null && value! >= min && value! <= max);

  Map<String, Object?> toJson(Duration played) => {
    'key': key,
    'value': value,
    'min': min,
    'max': max,
    'unit': unit,
    'applies': applies,
    'judged': judged(played),
    'ok': ok(played),
  };
}
