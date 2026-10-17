import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart' show GameState;
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 선장 필살기 버튼 (사용자 2026-10-18 '보스전도 밋밋하다, 핵앤슬래시 하고 싶다' — S1 예고, 엔진은 S2: 게이지·UseCaptainSkill·
// 자동 필살기 설정 — S2 이름: BattleView.captainGauge · TriggerUltimate() · Settings.autoUltimate): 오른쪽 아래 엄지 자리(배 체력 막대 위) 큰 원. 게이지만큼 금빛 원이 차고, 가득이면 금빛 맥박,
// 누르면 크게 눌리고 화면이 번쩍(S3 컷인과 이어짐). 계약이 오기 전엔 임시 어댑터 — 운영자 '필살기(가짜)'가 켜면 피버 게이지를 빌린다.

/// 필살기 버튼 지름.
const double captainSkillSize = 72;

/// 필살기 화면 값: 게이지 0~1 · 쓸 수 있나.
typedef CaptainSkillView = ({double gauge, bool ready});

/// 운영자 '필살기(가짜)' — 계약 전 화면 확인용.
final captainSkillFakeProvider = NotifierProvider<CaptainSkillFake, bool>(CaptainSkillFake.new);

class CaptainSkillFake extends Notifier<bool> {
  @override
  bool build() => false;

  // 운영자 토글(뒤집기).
  void toggle() => state = !state;
}

/// 지금 필살기 값(없으면 버튼을 숨긴다). S2 계약(BattleView 필살기 게이지)이 오면 여기만 바꾼다.
final captainSkillProvider = Provider<CaptainSkillView?>((ref) {
  if (!ref.watch(captainSkillFakeProvider)) return null;
  final g = ref.watch(gameStateProvider.select((s) => ((s.battle?.fever ?? 0) * 20).round() / 20));
  return (gauge: g.clamp(0, 1).toDouble(), ready: g >= 1);
});

/// 필살기가 가득 찼나(가이드 'guide.ult' — 처음 가득 찰 때 옥토 한 마디). S2 계약(BattleView.captainGauge)이 오면
/// `(s.battle?.captainGauge ?? 0) >= 1`로 바꾼다 — 그전엔 늘 false.
bool captainSkillReady(GameState s) => false;

/// 누르면 할 일(계약 전엔 화면 연출만). S2 UseCaptainSkill이 오면 명령을 보낸다.
final captainSkillUseProvider = Provider<void Function()>((_) => () {});

class CaptainSkillButton extends ConsumerStatefulWidget {
  const CaptainSkillButton({super.key});

  @override
  ConsumerState<CaptainSkillButton> createState() => _CaptainSkillButtonState();
}

class _CaptainSkillButtonState extends ConsumerState<CaptainSkillButton> {
  bool _down = false;

  void _use() {
    ref.read(captainSkillUseProvider)();
    if (!MediaQuery.disableAnimationsOf(context)) _flash(context);
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(captainSkillProvider);
    if (v == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    // 맥박: 전장 틱 기준 0.5초마다 밝게/옅게(끝없는 애니메이션 없음 — 도크 환생 맥박과 같은 방식).
    final bright = v.ready && ref.watch(gameStateProvider.select((s) => ((s.battle?.tick ?? 0) ~/ 10).isEven));
    return Semantics(
      button: true,
      enabled: v.ready,
      label: l10n.uiCaptainSkill,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('captain.skill'),
        behavior: HitTestBehavior.opaque,
        onTapDown: v.ready ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: v.ready
            ? (_) {
                setState(() => _down = false);
                _use();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.82 : (bright ? 1.06 : 1),
          duration: const Duration(milliseconds: 120),
          child: SizedBox.square(
            dimension: captainSkillSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 바탕 원 + 금빛 테(가득이면 빛).
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Skin.navyPanel,
                    border: Border.all(color: Skin.outline, width: 2.5),
                    boxShadow: v.ready
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD84A).withValues(alpha: bright ? 0.9 : 0.5),
                              blurRadius: 16,
                            ),
                          ]
                        : Skin.shadowSmall,
                  ),
                ),
                // 게이지 원 채움.
                SizedBox.square(
                  dimension: captainSkillSize - 8,
                  child: CircularProgressIndicator(
                    key: const Key('captain.skill.gauge'),
                    value: v.gauge,
                    strokeWidth: 6,
                    color: const Color(0xFFFFD84A),
                    backgroundColor: Colors.white12,
                  ),
                ),
                Opacity(
                  opacity: v.ready ? 1 : 0.55,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SkinIcon(UiSprites.star, size: 30),
                      OutlineText(l10n.uiCaptainSkillShort, size: 12, tone: OutlineTone.gold),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 번쩍(흰빛 0.25초) — S3 필살기 컷인으로 이어진다.
void _flash(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final entry = OverlayEntry(
    builder: (_) => IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: const Key('captain.skill.flash'),
        tween: Tween(begin: 0.7, end: 0),
        duration: const Duration(milliseconds: 250),
        builder: (_, a, _) => ColoredBox(color: Colors.white.withValues(alpha: a)),
      ),
    ),
  );
  overlay.insert(entry);
  unawaited(Future<void>.delayed(const Duration(milliseconds: 400), () => entry.mounted ? entry.remove() : null));
}
