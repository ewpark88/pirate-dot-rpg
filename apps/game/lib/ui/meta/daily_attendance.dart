import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/ribbon.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 일일 창의 출석 7칸 (daily_sheet.dart에서 나눔 — 300줄).

class DailyAttendance extends ConsumerWidget {
  const DailyAttendance(this.view, {super.key});

  final AttendanceView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SubRibbon(l10n.uiAttendanceTitle),
        const SizedBox(height: 8),
        // 두 줄 (스킨 r2 다듬기): 1~4일 · 5~6일 + 7일(두 칸 폭, 큰 보상). 좁은 폰에서도 글이 한 줄에 들어간다.
        for (final row in _rows(view.rewards.length)) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final day in row)
                  Expanded(
                    flex: day == view.rewards.length && row.length < 4 ? 2 : 1,
                    child: _DayCell(day: day, reward: view.rewards[day - 1], view: view),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (!view.claimedToday)
          Align(
            alignment: Alignment.centerRight,
            child: PixelButton(
              key: const Key('attendance.claim'),
              primary: true,
              onPressed: () => ref.read(commandSinkProvider).send(const ClaimAttendance()),
              child: Text(l10n.uiAttendanceClaim),
            ),
          ),
      ],
    );
  }
}

/// 칸 줄 나누기: 앞 4일, 나머지(마지막 날은 두 칸 폭).
List<List<int>> _rows(int n) => n <= 4
    ? [
        [for (var d = 1; d <= n; d++) d],
      ]
    : [
        [for (var d = 1; d <= 4; d++) d],
        [for (var d = 5; d <= n; d++) d],
      ];

class _DayCell extends StatefulWidget {
  const _DayCell({required this.day, required this.reward, required this.view});

  final int day;

  /// `meta.attendance.rewards`의 한 칸: `gems` 또는 `summon`+`minRarity`(영웅 이상 확정 소환).
  final JsonReader reward;
  final AttendanceView view;

  @override
  State<_DayCell> createState() => _DayCellState();
}

// 출석 칸 손맛 (S1 2026-10-18 HD 결): 오늘 칸은 창이 열릴 때 통통(한 번), 받는 순간 빨간 도장이 쾅 찍힌다(지난 칸은 찍힌 채).
class _DayCellState extends State<_DayCell> with SingleTickerProviderStateMixin {
  late final AnimationController _stamp;

  @override
  void initState() {
    super.initState();
    _stamp = AnimationController(vsync: this, duration: const Duration(milliseconds: 380), value: 1);
  }

  bool _checked(_DayCell w) => w.day < w.view.day || (w.day == w.view.day && w.view.claimedToday);

  @override
  void didUpdateWidget(_DayCell old) {
    super.didUpdateWidget(old);
    if (_checked(widget) && !_checked(old) && !MediaQuery.disableAnimationsOf(context)) {
      _stamp.forward(from: 0).ignore();
    }
  }

  @override
  void dispose() {
    _stamp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (day, reward, view) = (widget.day, widget.reward, widget.view);
    final today = day == view.day;
    final ticket = !reward.has('gems');
    // 출석은 하루 빠져도 이어서 받는다(리셋 없음) — 지난 날은 모두 받은 칸.
    final checked = day < view.day || (today && view.claimedToday);
    // 오늘(안 받음) = 금색 판·진한 글, 받은 날 = 흐린 판·초록 체크, 나머지 = 흰 판. 7일(소환권)은 금 테두리.
    // k2: 받은 날 = 옅은 회보라(Skin.track은 남색이라 글이 묻힌다), 나머지 = 연보라 안쪽 판.
    final fill = today && !checked ? Skin.goldTop : (checked ? const Color(0xFFD3D1EA) : Skin.insetFill);
    final ink = today && !checked ? Skin.goldInk : (checked ? Skin.sub : Skin.ink);
    final box = SkinDepth(
      fill: fill,
      border: today ? Skin.goldEdge : (ticket ? Skin.goldBottom : Skin.outline),
      borderWidth: today ? 2.5 : 2,
      radius: 12,
      shadow: Skin.shadowSmall,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        children: [
          Text(l10n.uiAttendanceDay(day), maxLines: 1, style: Skin.text(12, color: ink)),
          const SizedBox(height: 3),
          if (checked)
            const SkinIcon(UiSprites.check, size: 22)
          else
            // 소환권 = 카드 뒷면 그림 (별은 등급만 뜻한다 — 사용자 지적 2026-10-16).
            SkinIcon(ticket ? UiSprites.cardBack : UiSprites.gem, size: 22),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              ticket ? l10n.uiAttendanceTicket : '${reward.integer('gems')}',
              maxLines: 1,
              style: Skin.text(13, color: ink),
            ),
          ),
        ],
      ),
    );
    final calm = MediaQuery.disableAnimationsOf(context);
    return Padding(
      key: Key('attendance.day.$day.${checked ? 'checked' : (today ? 'today' : 'later')}'),
      padding: const EdgeInsets.all(2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 오늘(안 받음) 칸: 열릴 때 한 번 통통.
          if (today && !checked && !calm)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.82, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, k, c) => Transform.scale(scale: k, child: c),
              child: box,
            )
          else
            box,
          if (checked)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _stamp,
                  builder: (_, _) => Center(
                    child: Transform.rotate(
                      angle: -0.25,
                      child: Transform.scale(
                        scale: 1 + 1.2 * (1 - Curves.easeOutBack.transform(_stamp.value)),
                        child: _Stamp(key: Key('attendance.stamp.$day'), text: l10n.uiAttendanceStamp),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 받은 칸 빨간 도장(둥근 테 + 글).
class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x22E0453D),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xCCE0453D), width: 2.5),
    ),
    child: Text(text, style: Skin.bold(12, color: const Color(0xFFD03A33))),
  );
}
