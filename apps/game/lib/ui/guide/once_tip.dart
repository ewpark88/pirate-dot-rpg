import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/guide/guide_cards.dart' show guidesEnabledProvider;
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 창·시트 안에서 처음 만날 때 옥토 한 마디 (가이드 v3, S1 2026-10-17): 가이드 말풍선 층은 창 아래라 창 안 기능
// (공격 미리보기·교체 비교·철갑판)은 그 창 안에 작은 말풍선으로. 한 번만(세이브 hints [id]), 누르면 접힌다.

class OnceTip extends ConsumerStatefulWidget {
  const OnceTip({required this.id, required this.text, super.key});

  /// 본 기록 id (예 'tip.preview') — 가이드 '안내 다시 보기'(guide. 접두어)와는 따로.
  final String id;
  final String text;

  @override
  ConsumerState<OnceTip> createState() => _OnceTipState();
}

class _OnceTipState extends ConsumerState<OnceTip> {
  /// 이번에 보여 줄지 (처음 그릴 때 정한다 — 본 기록이 늦게 와도 깜빡이지 않게).
  late bool _show;

  @override
  void initState() {
    super.initState();
    // 처음 만나는 안내를 끈 시험 하네스(guidesEnabled false)에선 보이지 않는다.
    _show = ref.read(guidesEnabledProvider) && !ref.read(gameStateProvider).settings.hints.contains(widget.id);
    if (_show) scheduleMicrotask(() => ref.read(commandSinkProvider).send(MarkHint(widget.id)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return GestureDetector(
      key: Key(widget.id),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _show = false),
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBFE6FF),
                border: Border.all(color: Skin.outline, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                pbPortrait('octo'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.face, size: 22),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(color: Skin.outline, width: 2),
                ),
                child: Text(widget.text, style: Skin.text(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
