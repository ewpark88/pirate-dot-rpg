import 'package:pirate_dot/adapters/analytics/analytics_sdk.dart';

/// 첫 프레임 뒤에 붙는 분석(docs/store/cold-start.md — Firebase 초기화를 runApp 앞에서 기다리지 않는다).
/// [attach] 전 호출은 순서대로 쌓아 뒀다가 붙는 순간 보낸다(최대 [maxPending]개 — 넘치면 오래된 것부터 버림).
class DeferredAnalytics implements AppAnalytics {
  DeferredAnalytics({this.maxPending = 200});

  final int maxPending;
  final _pending = <void Function(AppAnalytics a)>[];
  AppAnalytics? _inner;

  bool get attached => _inner != null;

  /// 진짜 분석(실패면 NoopAnalytics)을 붙이고 쌓인 호출을 흘린다.
  void attach(AppAnalytics inner) {
    _inner = inner;
    for (final call in _pending) {
      call(inner);
    }
    _pending.clear();
  }

  void _do(void Function(AppAnalytics a) call) {
    final inner = _inner;
    if (inner != null) return call(inner);
    if (_pending.length >= maxPending) _pending.removeAt(0);
    _pending.add(call);
  }

  @override
  void log(String event, [Map<String, Object> params = const {}]) => _do((a) => a.log(event, params));

  @override
  void setLastSeen({required String screen, required int stage}) =>
      _do((a) => a.setLastSeen(screen: screen, stage: stage));

  @override
  void setCollection({required bool enabled}) => _do((a) => a.setCollection(enabled: enabled));

  @override
  void setCrashKey(String key, Object value) => _do((a) => a.setCrashKey(key, value));
}
