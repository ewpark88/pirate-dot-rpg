import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/number_text.dart';

// 지루함 해소 3종 UI (스펙 platform-fun-sea-events · platform-fun-fever, 계약 S2 c5193fa).
// 팝업 없음 — 전장 위 작은 띠와 전장 안 말풍선만. 실패·떠남은 조용히 접는다(벌칙 없음).

/// 성공 띠가 금색으로 머무는 시간.
const _successShow = Duration(milliseconds: 1400);

/// 띠 공통 모양: 어두운 알약 + 아이콘 + 글 + 남은 시간 막대. 누름을 막지 않는다.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.icon,
    required this.text,
    required this.left,
    this.trailing,
    this.gold = false,
    super.key,
  });

  final String icon;
  final String text;

  /// 남은 비율 0~1 (null이면 막대 없음).
  final double? left;
  final String? trailing;
  final bool gold;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    // 글 길이만큼만 (막대는 그 폭을 채운다).
    child: IntrinsicWidth(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(maxWidth: 160),
        padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
        decoration: BoxDecoration(
          color: gold ? Skin.goldBottom : Skin.ink.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SkinIcon(icon),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Skin.text(13, color: gold ? Skin.goldInk : Colors.white),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Text(trailing!, style: Skin.text(13, color: gold ? Skin.goldInk : const Color(0xFFFFE27A))),
                ],
              ],
            ),
            if (left != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: left!.clamp(0.0, 1.0),
                    minHeight: 3,
                    color: Skin.goldTop,
                    backgroundColor: Colors.white24,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// 남은 틱 → 남은 비율. 처음 본 값을 시작으로 삼는다(띠마다 하나).
class FunCountdown {
  int _start = 1;
  String? _id;

  double ratio(String id, int ticksLeft) {
    if (id != _id || ticksLeft > _start) {
      _id = id;
      _start = ticksLeft < 1 ? 1 : ticksLeft;
    }
    return ticksLeft / _start;
  }
}

int _seconds(WidgetRef ref, int ticks) =>
    (ticks * ref.read(tablesProvider).waves.tickMs / Duration.millisecondsPerSecond).ceil();

/// 돌발 이벤트 띠 (전장 위, 게이지 아래 왼쪽): 아이콘 + 이름 + 남은 막대.
class SeaEventStrip extends ConsumerStatefulWidget {
  const SeaEventStrip({super.key});

  @override
  ConsumerState<SeaEventStrip> createState() => _SeaEventStripState();
}

class _SeaEventStripState extends ConsumerState<SeaEventStrip> {
  final _countdown = FunCountdown();

  @override
  Widget build(BuildContext context) {
    final ev = ref.watch(gameStateProvider.select((s) => s.battle?.seaEvent));
    if (ev == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final (icon, text) = switch (ev.id) {
      'goldfish' => (UiSprites.coin, l10n.uiSeaGoldfish),
      'merchant' => (UiSprites.gem, l10n.uiSeaMerchant),
      'ambush' => (UiSprites.flag, l10n.uiSeaAmbush),
      'bottle' => (UiSprites.quest, l10n.uiSeaBottle),
      _ => (UiSprites.tailwind, l10n.uiSeaStorm),
    };
    return _Strip(
      key: Key('fun.sea.${ev.id}'),
      icon: icon,
      text: text,
      left: _countdown.ratio(ev.id, ev.ticksLeft),
    );
  }
}

/// 보상 요약 문자열('gold:1.2e5', 'gems:2', 'fever:0.3', 'tailwind:600') → 짧은 글.
String rewardText(AppLocalizations l, String? reward) {
  if (reward == null) return '';
  final i = reward.indexOf(':');
  if (i < 0) return '';
  final kind = reward.substring(0, i);
  final v = reward.substring(i + 1);
  return switch (kind) {
    'gold' => l.uiRewardGold(BigNum.parse(v).format()),
    'gems' => l.uiRewardGems(v),
    'fever' => l.uiRewardFever(((double.tryParse(v) ?? 0) * 100).round()),
    'tailwind' => l.uiRewardTailwind(((int.tryParse(v) ?? 0) / 60).round()),
    _ => '',
  };
}

/// 즉석 도전 띠: 'n초 · 처치 37/50' + 남은 막대. 성공하면 금색으로 바뀌고 보상이 잠깐 보인 뒤 사라진다. 실패는 그냥 접힘.
class ChallengeStrip extends ConsumerStatefulWidget {
  const ChallengeStrip({super.key});

  @override
  ConsumerState<ChallengeStrip> createState() => _ChallengeStripState();
}

class _ChallengeStripState extends ConsumerState<ChallengeStrip> {
  final _countdown = FunCountdown();
  StreamSubscription<RecordedTick>? _sub;
  Timer? _hide;
  String? _success;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(battleFeedProvider)?.listen((tick) {
      for (final e in tick.events) {
        if (e is ChallengeEnded && e.success && mounted) {
          _hide?.cancel();
          setState(() => _success = rewardText(AppLocalizations.of(context), e.reward));
          _hide = Timer(_successShow, () {
            if (mounted) setState(() => _success = null);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_success != null) {
      return _Strip(
        key: const Key('fun.challenge.done'),
        icon: UiSprites.star,
        // 작은 알약 폭(160) 안에 — 보상이 있으면 보상만(금색 띠 = 성공), 없으면 '도전 성공!'.
        text: _success!.isEmpty ? l10n.uiChallengeDone : _success!,
        left: null,
        gold: true,
      );
    }
    final c = ref.watch(gameStateProvider.select((s) => s.battle?.challenge));
    if (c == null) return const SizedBox.shrink();
    final text = switch (c.id) {
      'kills' => l10n.uiChallengeKills(c.target, c.value),
      'combo' => l10n.uiChallengeCombo(c.target),
      'noHit' => l10n.uiChallengeNoHit,
      _ => l10n.uiChallengeUltimate(c.target),
    };
    return _Strip(
      key: Key('fun.challenge.${c.id}'),
      icon: UiSprites.flag,
      text: text,
      trailing: l10n.uiSecondsLeft(_seconds(ref, c.ticksLeft)),
      left: _countdown.ratio(c.id, c.ticksLeft),
    );
  }
}

/// 피버 막대 (진행 게이지 안 오른쪽 끝, 얇게): 평소엔 0~1 채움.
/// 피버 v2(사용자 2026-10-17): 피버 중엔 줄어드는 '남은 시간' 막대 + 'FEVER ×n' 칩(n = meta.fever.damageMultiplier).
class FeverMeter extends ConsumerStatefulWidget {
  const FeverMeter({super.key});

  @override
  ConsumerState<FeverMeter> createState() => _FeverMeterState();
}

class _FeverMeterState extends ConsumerState<FeverMeter> {
  /// 이번 피버의 처음 남은 틱 (표의 지속 시간이 바뀌어도 막대가 맞게).
  int _total = 1;

  @override
  Widget build(BuildContext context) {
    final (fever, left) = ref.watch(
      gameStateProvider.select((s) => ((((s.battle?.fever ?? 0) * 20).round()) / 20, s.battle?.feverTicksLeft ?? 0)),
    );
    if (left > _total) _total = left;
    if (left == 0) _total = 1;
    final l10n = AppLocalizations.of(context);
    final on = left > 0;
    final value = on ? left / _total : fever;
    final mult = ref.watch(tablesProvider).meta.raw.obj('fever').number('damageMultiplier');
    return Semantics(
      label: on ? l10n.uiFeverChip(shortDecimal(mult)) : '${l10n.uiFever} ${(fever * 100).round()}%',
      excludeSemantics: true,
      child: Row(
        key: Key(on ? 'fun.fever.meter.on' : 'fun.fever'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (on)
            Container(
              key: const Key('fun.fever.chip'),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: const Color(0xFFFF8A2A), borderRadius: BorderRadius.circular(6)),
              child: Text(l10n.uiFeverChip(shortDecimal(mult)), style: Skin.text(10, color: Colors.white)),
            )
          else
            Text(l10n.uiFever, style: Skin.text(11, color: const Color(0xFFFFC27A))),
          const SizedBox(width: 3),
          SizedBox(
            width: 36,
            height: on ? 6 : 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                key: Key(on ? 'fun.fever.time' : 'fun.fever.fill'),
                value: value.clamp(0.0, 1.0),
                color: on ? const Color(0xFFFFD84A) : const Color(0xFFFF9A3C),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
