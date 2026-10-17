import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/hud/boss_traits.dart';
import 'package:pirate_dot/ui/pixel/pixel_frame.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/text/table_text.dart';

// 보스전 상시 약점 줄은 없앴다(사용자 2026-10-18 '띠 아래 안내 줄이 보스를 가린다') — 약점은 보스 등장 이름표(BossIntro, 2초)·
// 항해 탭·편성 칩이 보인다. 여기엔 칩 위젯만 남는다.
/// ‘약점’ + 계열 칩들 (보스전 HUD와 항해 탭 해역 보스 미리보기가 같이 쓴다).
class WeakChips extends ConsumerWidget {
  const WeakChips({required this.boss, this.labelStyle, super.key});

  final BossDef boss;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    // 특성 카운터까지 합치면 칩이 많다 — 좁으면 다음 줄로.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        Text(l10n.uiBossWeak, style: labelStyle),
        // 약점 = 표의 약점 + 특성 카운터 계열 (#25).
        for (final f in bossCounters(boss)) ...[
          const SizedBox(width: 4),
          // 약점 칩: 도트 프레임 (누르는 것 아님).
          PixelFrame(
            key: Key('boss.weak.$f'),
            padding: 2,
            highlight: null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                tableText(l10n, tables.skills.byId(f).nameKey),
                style: labelStyle?.copyWith(color: Skin.ink) ?? Skin.text(13),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
