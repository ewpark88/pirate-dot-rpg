import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/power_policy.dart' show thermalLevelProvider;
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/settings/about_section.dart' show appVersion;

// 비치명·치명 보고서 맥락 키(docs/store/crash-anr.md 3, S1 2026-10-18): scene · fever · enemies · build · thermal.
// 매 틱이 아니라 값이 바뀔 때만 보낸다(같은 값이면 건너뜀). 보내는 곳은 앱이 덮는다(main — 분석 어댑터 setCrashKey).

/// 보고서 키 하나를 보낸다. null이면 보내지 않는다(테스트·분석 꺼짐).
final crashKeyProvider = Provider<void Function(String key, Object value)?>((_) => null);

/// 지금 장면: 탑·러시·던전·현상금·빠른 항해, 아니면 'sea'.
String crashScene(BattleView f) => switch (f) {
  BattleView(tower: _?) => 'tower',
  BattleView(rush: _?) => 'rush',
  BattleView(dungeon: _?) => 'dungeon',
  BattleView(bounty: _?) => 'bounty',
  BattleView(fastSail: _?) => 'fastSail',
  _ => 'sea',
};

/// 동시 적 수 묶음(잦은 갱신 막기).
String enemyBucket(int n) => switch (n) {
  0 => '0',
  < 10 => '1-9',
  < 50 => '10-49',
  < 100 => '50-99',
  _ => '100+',
};

class CrashContextGate extends ConsumerStatefulWidget {
  const CrashContextGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CrashContextGate> createState() => _CrashContextGateState();
}

class _CrashContextGateState extends ConsumerState<CrashContextGate> {
  StreamSubscription<RecordedTick>? _sub;
  final _sent = <String, Object>{};

  void _set(String key, Object value) {
    if (_sent[key] == value) return;
    _sent[key] = value;
    ref.read(crashKeyProvider)?.call(key, value);
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(crashKeyProvider) == null) return;
    _set('build', appVersion);
    _set('thermal', ref.read(thermalLevelProvider).name);
    ref.listenManual(thermalLevelProvider, (_, t) => _set('thermal', t.name));
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      final f = tick.frame;
      _set('scene', crashScene(f));
      _set('fever', f.feverTicksLeft > 0 ? 1 : 0);
      _set('enemies', enemyBucket(f.enemies.length));
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
