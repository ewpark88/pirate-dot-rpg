import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 보스 체력 여러 줄 (사용자 '보스전 밋밋' — S2 BattleView.bossBarsLeft · BossBarBroken, S3 연출): 큰 보스는 체력이 여러 줄이고
// 한 줄을 깎을 때마다 색이 바뀌며 다음 줄이 드러난다. 막대 오른쪽에 '×남은 줄'. 계약 전엔 임시 어댑터(운영자 '여러 줄(가짜)').

/// 남은 줄(이번 줄 포함) · 전체 줄 · 이번 줄 남은 비율.
typedef BossBars = ({int left, int total, double ratio});

/// 줄 색(위에서부터) — 남은 줄 수로 고른다(마지막 줄은 늘 빨강).
const bossBarColors = [Color(0xFFE8443A), Color(0xFFFF8A2B), Color(0xFFB45CFF), Color(0xFF3FA2FF), Color(0xFF3DD68C)];

Color bossBarColor(int left) => bossBarColors[(left - 1) % bossBarColors.length];

/// 운영자 '보스 여러 줄(가짜)' — 전체 체력을 3줄로 나눠 보여 준다.
final bossBarsFakeProvider = NotifierProvider<BossBarsFake, bool>(BossBarsFake.new);

class BossBarsFake extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// 지금 보스의 줄(없으면 한 줄짜리 — 기존 막대). S2 계약이 오면 BattleView.bossBarsLeft로 바꾼다.
final bossBarsProvider = Provider<BossBars?>((ref) {
  if (!ref.watch(bossBarsFakeProvider)) return null;
  final r = ref.watch(
    gameStateProvider.select(
      (s) => s.battle?.enemies.where((e) => e.boss).map((e) => (e.hpRatio * 100).round() / 100).firstOrNull,
    ),
  );
  if (r == null) return null;
  const total = 3;
  final left = (r * total).ceil().clamp(1, total);
  return (left: left, total: total, ratio: r * total - (left - 1));
});
