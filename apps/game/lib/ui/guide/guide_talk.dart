import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/ui/dock/home_dock.dart' show kDockHeight;
import 'package:pirate_dot/ui/guide/guide_spots.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

// 가이드 v3 (S1 결정 2026-10-17 — '친절해졌지만 부자연스럽다'): 시스템 카드 대신 안내 캐릭터(옥토 선장, PB 그림)가 아래에서 쏙 올라와
// 말풍선으로 말한다. 짧은 해요체 대화(2줄·25자 안팎), 누를 곳은 빛나는 테두리 + 톡톡 손가락, 행동하면 '좋아요! …' 반응.
// 지금은 스토리보드(S1 승인 전) 시안 — 흐름 연결은 승인 뒤.

/// 한 마디.
typedef GuideLine = ({
  /// 말 (2줄 안팎).
  String text,

  /// 누를 곳 TutorialSpot id (없으면 말만).
  String? spot,

  /// 행동 뒤 반응('좋아요! 공격력 +20%') — 초록 말풍선, 손가락 없음.
  bool reaction,

  /// 화면을 살짝 어둡게(첫 두 단계만).
  bool dim,
});

/// 말풍선 자리 높이(초상 72 + 여유) — 누를 곳과 겹치는지 볼 때.
const _talkHeight = 110.0;

/// 지금 할 말 (null = 조용). 흐름 연결 전에는 스토리보드·운영자가 넣는다.
final guideLineProvider = NotifierProvider<GuideLineNotifier, GuideLine?>(GuideLineNotifier.new);

class GuideLineNotifier extends Notifier<GuideLine?> {
  @override
  GuideLine? build() => null;

  // 말을 바꾸는 동작이라 메서드로 둔다.
  // ignore: use_setters_to_change_properties
  void say(GuideLine? line) => state = line;
}

/// 옥토 선장이 말하는 층: 화면 아래(도크 위)에 초상 + 말풍선, 누를 곳은 금빛 테두리 + 손가락.
class GuideTalkLayer extends ConsumerStatefulWidget {
  const GuideTalkLayer({super.key});

  @override
  ConsumerState<GuideTalkLayer> createState() => _GuideTalkLayerState();
}

class _GuideTalkLayerState extends ConsumerState<GuideTalkLayer> {
  final GlobalKey _box = GlobalKey();
  Timer? _track;
  Rect? _hole;

  @override
  void initState() {
    super.initState();
    _track = Timer.periodic(const Duration(milliseconds: 150), (_) => _refresh());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _track?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    final spot = ref.read(guideLineProvider)?.spot;
    final box = _box.currentContext?.findRenderObject();
    Rect? next;
    if (spot != null && box is RenderBox && box.hasSize) {
      final r = guideSpotRects([spot]).firstOrNull;
      if (r != null) next = Rect.fromPoints(box.globalToLocal(r.topLeft), box.globalToLocal(r.bottomRight));
    }
    if (next != _hole) setState(() => _hole = next);
  }

  @override
  Widget build(BuildContext context) {
    final line = ref.watch(guideLineProvider);
    final pad = MediaQuery.paddingOf(context);
    final hole = _hole;
    return Stack(
      key: _box,
      children: [
        if (line != null && line.dim)
          const Positioned.fill(
            child: IgnorePointer(child: ColoredBox(color: Color(0x55000000))),
          ),
        if (line != null && hole != null && !line.reaction) ...[
          // 누를 곳만 살짝 빛나는 금빛 테두리.
          Positioned.fromRect(
            rect: hole.inflate(4),
            child: IgnorePointer(
              child: DecoratedBox(
                key: const Key('talk.glow'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD84A), width: 3),
                  boxShadow: const [BoxShadow(color: Color(0xAAFFD84A), blurRadius: 12, spreadRadius: 2)],
                ),
              ),
            ),
          ),
          Positioned(
            left: hole.right - 26,
            top: hole.bottom - 30,
            child: const IgnorePointer(
              child: Icon(
                Icons.touch_app_rounded,
                key: Key('talk.finger'),
                size: 42,
                color: Colors.white,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
        ],
        if (line != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) {
                // 기본은 도크 바로 위. 누를 곳이 그 자리(아래 [_talkHeight])와 겹치면 누를 곳 위로 올린다.
                final bottom = kDockHeight + pad.bottom + 8;
                final zoneTop = box.maxHeight - bottom - _talkHeight;
                final overlaps = hole != null && hole.bottom > zoneTop && hole.top < box.maxHeight - bottom;
                return Stack(
                  children: [
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: overlaps ? box.maxHeight - hole.top + 12 : bottom,
                      child: IgnorePointer(child: _Talk(line: line)),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

/// 초상(원) + 말풍선(꼬리) — 반응이면 초록 테두리.
class _Talk extends StatelessWidget {
  const _Talk({required this.line});

  final GuideLine line;

  @override
  Widget build(BuildContext context) {
    final edge = line.reaction ? Skin.mint : const Color(0xFFFFC53D);
    return Align(
      alignment: Alignment.bottomLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Row(
          key: const Key('talk'),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBFE6FF),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: Skin.shadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                pbPortrait('octo'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.face, size: 48),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: Skin.card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                  ),
                  border: Border.all(color: edge, width: 2.5),
                  boxShadow: Skin.shadow,
                ),
                child: Text(line.text, key: const Key('talk.text'), maxLines: 3, style: Skin.text(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
