import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/bounty/bounty_card.dart' show BossPortrait;
import 'package:pirate_dot/ui/hud/battle_hud_buttons.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/tutorial/tutorial.dart';

// 사용자 지시 2026-10-16: "새로고침 버튼 같은 보스를 바로 불러오는 버튼을 다른 것으로" — 새로고침 화살표 금지.

/// 보스 도전 버튼 (파밍 중): 해역 보스 초상 + '보스 도전!' 빨강·금 알약, 칼 교차, 맥박, 처음 1회 말풍선.
class BossChallengeButton extends ConsumerStatefulWidget {
  const BossChallengeButton({super.key});

  @override
  ConsumerState<BossChallengeButton> createState() => _BossChallengeButtonState();
}

class _BossChallengeButtonState extends ConsumerState<BossChallengeButton> {
  bool? _bubble;
  Timer? _hide;

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    final (show, stage, tick, flashOn) = ref.watch(
      gameStateProvider.select(
        (s) => (
          s.progress.farming && !(s.battle?.bossActive ?? false),
          s.progress.stage,
          s.battle?.tick ?? 0,
          s.settings.flash,
        ),
      ),
    );
    if (!show) {
      _bubble = null;
      return const SizedBox.shrink();
    }
    // 가이드 v3: 처음 안내는 옥토 선장 말(guide.bossRetry)로 합쳤다 — 버튼 위 말풍선은 띄우지 않는다.
    _bubble ??= false;
    final boss = tables.regions.regionAt(stage).boss;
    final calm = MediaQuery.disableAnimationsOf(context);
    final pulse = flashOn && !calm ? 0.5 + 0.5 * math.sin(tick / 3) : 0.0;
    return TutorialSpot(
      id: 'boss.challenge',
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 길게 누르면 설명.
          Tooltip(
            message: l10n.uiBossChallenge,
            child: Semantics(
              button: true,
              label: l10n.uiBossChallenge,
              excludeSemantics: true,
              child: GestureDetector(
                key: const Key('boss.challenge'),
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(commandSinkProvider).send(const ChallengeBoss()),
                child: Transform.scale(
                  scale: 1 + 0.05 * pulse,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFF5A4A), Color(0xFFC0122E)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Color.lerp(Skin.goldTop, Colors.white, pulse)!, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF8A2A).withValues(alpha: 0.25 + 0.35 * pulse),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: const BoxDecoration(color: Color(0xFF1B2A4A), shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: BossPortrait(bossId: boss, size: 30),
                        ),
                        const SizedBox(width: 4),
                        const CustomPaint(size: Size(14, 14), painter: _SwordsPainter()),
                        const SizedBox(width: 3),
                        Text(
                          l10n.uiBossRetry,
                          style: Skin.text(14, color: Colors.white, weight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_bubble ?? false)
            Positioned(
              bottom: 52,
              right: 0,
              child: IgnorePointer(
                child: HudBubble(key: const Key('boss.bubble'), text: l10n.uiBossRetryHint),
              ),
            ),
        ],
      ),
    );
  }
}

/// 칼 두 자루 교차 (코드 그림).
class _SwordsPainter extends CustomPainter {
  const _SwordsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final blade = Paint()
      ..color = const Color(0xFFFFE27A)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final hilt = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(w * 0.15, w * 0.15), Offset(w * 0.8, w * 0.8), blade)
      ..drawLine(Offset(w * 0.85, w * 0.15), Offset(w * 0.2, w * 0.8), blade)
      ..drawLine(Offset(w * 0.6, w * 0.95), Offset(w * 0.95, w * 0.6), hilt)
      ..drawLine(Offset(w * 0.05, w * 0.6), Offset(w * 0.4, w * 0.95), hilt);
  }

  @override
  bool shouldRepaint(_SwordsPainter old) => false;
}
