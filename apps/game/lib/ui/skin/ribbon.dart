import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

// 스킨 k2 리본 (디자인 개편 ①, S1 2026-10-17 — 쿵푸할매 '스킬 비전서' 창 머리·'북극 빙결' 소제목).

/// 창 머리 리본 아래 진한 노랑 띠 (입체).
const _ribbonBand = Color(0xFFE08A00);

/// 소제목 리본 양 끝 뾰족한 길이.
const _tip = 10.0;

/// 창 머리 노란 리본: 둥근 노란 판(위 광택) + 아래 진한 노랑 띠 + 굵은 외곽선, 가운데 흰 외곽선 제목.
class RibbonHeader extends StatelessWidget {
  const RibbonHeader({required this.title, this.padRight = 12, super.key});

  final String title;

  /// 오른쪽 여백 (X 버튼 자리). 왼쪽도 같게 해 제목이 가운데.
  final double padRight;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const Key('dialog.ribbon'),
    decoration: const BoxDecoration(
      color: _ribbonBand,
      border: Border(
        bottom: BorderSide(color: Skin.outline, width: Skin.outlineWidth),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEE8A), Skin.ribbonTop, Skin.ribbonBottom],
            stops: [0, 0.45, 1],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(padRight, 10, padRight, 8),
          child: Text(title, textAlign: TextAlign.center, maxLines: 2, style: Skin.outlined(22)),
        ),
      ),
    ),
  );
}

/// 창 안 소제목: 양 끝이 뾰족한 작은 노란 리본 + 진한 굵은 글자 (가운데 정렬).
class SubRibbon extends StatelessWidget {
  const SubRibbon(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: CustomPaint(
      painter: const _RibbonPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_tip + 12, 4, _tip + 12, 5),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Skin.bold(16, color: Skin.outline),
        ),
      ),
    ),
  );
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final path = Path()
      ..moveTo(0, h / 2)
      ..lineTo(_tip, 0)
      ..lineTo(w - _tip, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w - _tip, h)
      ..lineTo(_tip, h)
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEE8A), Skin.ribbonTop, Skin.ribbonBottom],
          ).createShader(Offset.zero & size),
      )
      // 아래 진한 띠 (입체) — 리본 모양 안에서만.
      ..save()
      ..clipPath(path)
      ..drawRect(Rect.fromLTWH(0, h - 5, w, 5), Paint()..color = _ribbonBand)
      ..restore()
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..color = Skin.outline,
      );
  }

  @override
  bool shouldRepaint(_RibbonPainter oldDelegate) => false;
}
