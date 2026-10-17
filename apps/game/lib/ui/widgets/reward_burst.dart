import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/icon_cell.dart';
import 'package:pirate_dot/ui/skin/outline_text.dart';
import 'package:pirate_dot/ui/widgets/reward_rays.dart';

export 'package:pirate_dot/ui/widgets/reward_rays.dart' show RewardTier;

/// 보상 하나: HD 아이콘 경로(UiSprites) + 수량 글자(이미 줄여 쓴 '1.2K' 등) + 칸 색 등급(없으면 연출 등급).
typedef RewardItem = ({String icon, String label, RewardTier? tier});

/// 보상 터짐(디자인 개편 ③ — 참고 이미지 상자 연출): 가운데 보상 출처 그림([source] — 상자·보스 초상·도감 책)이
/// 흔들리다 열리며(0~0.25) 뒤로 회전 빛기둥·둥근 빛·반짝이 별이 펼쳐지고, 아이템이 등급색 칸(IconCell) 안에 담겨
/// 위로 회전하며 부채꼴로 튀었다가(~0.45) 화면 가운데 칸 줄로 튕기며 정렬된다(5개 넘으면 2줄). 수량은 칸 오른쪽 아래 외곽선 숫자.
/// 기존 연출(TopBossLoot·ChestOpened)·결과 창 위 덮개 — 누름은 통과(IgnorePointer).
/// [lite](절전·발열)면 빛줄기·반짝이를 줄이고 회전을 멈춘다. [progress]를 주면 그 순간에 멈춘다(골든 시험).
class RewardBurst extends StatefulWidget {
  const RewardBurst({
    required this.items,
    this.source,
    this.openedSource,
    this.tier = RewardTier.gold,
    this.lite = false,
    this.progress,
    super.key,
  });

  final List<RewardItem> items;

  /// 가운데 출처 그림(HD 아이콘·보스 초상 경로). [openedSource]가 있으면 열린 뒤 그것으로(상자 → 열린 상자).
  /// null이면 그림 없이 빛만(소환 결과처럼 창이 따로 카드를 보여 줄 때 — 뒤 배경).
  final String? source;
  final String? openedSource;
  final RewardTier tier;
  final bool lite;
  final double? progress;

  /// 터짐부터 정렬까지(그 뒤 빛은 천천히 계속 돈다).
  static const duration = Duration(milliseconds: 2000);

  @override
  State<RewardBurst> createState() => _RewardBurstState();
}

class _RewardBurstState extends State<RewardBurst> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.progress != null) return;
    _c = AnimationController(vsync: this, duration: RewardBurst.duration);
    unawaited(_c!.forward());
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: _c == null
        ? _frame(widget.progress!, 0)
        : AnimatedBuilder(
            animation: _c!,
            builder: (context, _) => _frame(_c!.value, (_c!.lastElapsedDuration?.inMilliseconds ?? 0) / 1000),
          ),
  );

  /// 출처가 열리는 때(이때 빛이 펼쳐지고 아이템이 튀어나온다).
  static const _open = 0.22;

  Widget _frame(double t, double sec) => LayoutBuilder(
    builder: (context, box) {
      // 기기 '애니메이션 줄이기'도 가볍게(접근성).
      final lite = widget.lite || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
      final size = box.biggest;
      final n = widget.items.length;
      final perRow = math.max(1, n > 5 ? (n / 2).ceil() : n); // 아이템이 없으면(빛만) 1
      // 칸 56~64dp, 좁으면 줄인다(간격 = 칸 × 0.25 일정).
      final cell = math.min<double>(64, size.width / (perRow * 1.25 + 0.5)).clamp(40.0, 64.0);
      final rows = (n / perRow).ceil();
      final source = Offset(size.width / 2, size.height * 0.3);
      // 정렬 칸 줄: 화면 가운데 근처(출처 아래).
      final gridTop = size.height * 0.5 - (rows - 1) * cell * 0.65;
      final bt = ((t - _open) / (1 - _open)).clamp(0.0, 1.0);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: RewardRaysPainter(
                center: source,
                t: bt,
                spin: lite ? 0 : (widget.progress ?? sec) * 0.6,
                tier: widget.tier,
                lite: lite,
              ),
            ),
          ),
          if (widget.source != null) _source(t, source, cell * 2),
          for (var i = 0; i < n; i++) _item(i, bt, source, size, cell, perRow, gridTop),
        ],
      );
    },
  );

  /// 출처 그림: 0~0.15 흔들림 → 열림(펑 1.25배 → 1) → 열린 그림.
  Widget _source(double t, Offset at, double side) {
    final shake = t < 0.15 ? math.sin(t * 90) * 0.12 * (t / 0.15) : 0.0;
    final pop = t < _open ? 1.0 : 1 + 0.25 * math.max(0, 1 - (t - _open) / 0.12);
    final opened = t >= _open && widget.openedSource != null;
    return Positioned(
      left: at.dx - side / 2,
      top: at.dy - side / 2,
      width: side,
      height: side,
      child: Transform.rotate(
        angle: shake,
        child: Transform.scale(
          scale: pop,
          child: Image.asset(
            opened ? widget.openedSource! : widget.source!,
            key: const Key('reward.source'),
            width: side,
            height: side,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// 아이템 i(열린 뒤 시간 [bt]): 0~0.4 출처에서 회전하며 부채꼴 위로 → 0.4~0.75 칸 줄로 튕기며 → 이후 제자리.
  Widget _item(int i, double bt, Offset source, Size size, double cell, int perRow, double gridTop) {
    final n = widget.items.length;
    final item = widget.items[i];
    final row = i ~/ perRow;
    final col = i % perRow;
    final inRow = math.min(perRow, n - row * perRow);
    final gap = cell * 1.25;
    final slot = Offset(size.width / 2 + (col - (inRow - 1) / 2) * gap, gridTop + row * cell * 1.3);
    final fan = n == 1 ? 0.0 : (i / (n - 1) - 0.5) * 2 * math.pi / 3;
    final peak = source + Offset(math.sin(fan) * cell * 2.2, -cell * 1.2 - math.cos(fan) * cell * 0.5);
    final delay = i * 0.035;
    final u = ((bt - delay) / (1 - delay)).clamp(0.0, 1.0);
    final spinDir = i.isEven ? 1.0 : -1.0;
    Offset at;
    double scale;
    double angle;
    if (u < 0.4) {
      final k = u / 0.4;
      at = Offset.lerp(source, peak, Curves.easeOutCubic.transform(k))!;
      scale = 0.3 + 0.8 * Curves.easeOutBack.transform(k);
      angle = spinDir * (1 - k) * 1.2;
    } else if (u < 0.75) {
      final k = (u - 0.4) / 0.35;
      // 튕김: easeOutBack으로 칸을 살짝 지나쳤다 돌아온다.
      at = Offset.lerp(peak, slot, Curves.easeOutBack.transform(k))!;
      scale = 1.1 - 0.1 * k;
      angle = spinDir * math.sin(k * math.pi) * 0.15;
    } else {
      at = slot;
      scale = 1 + 0.05 * math.sin((u - 0.75) / 0.25 * math.pi);
      angle = 0;
    }
    return Positioned(
      left: at.dx - cell / 2,
      top: at.dy - cell / 2,
      width: cell,
      height: cell,
      child: Opacity(
        opacity: bt > delay ? 1 : 0,
        child: Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconCell(
                  key: Key('reward.item.$i'),
                  color: (item.tier ?? widget.tier).color,
                  size: cell,
                  child: Image.asset(item.icon, width: cell, height: cell, fit: BoxFit.contain),
                ),
                Positioned(right: -4, bottom: -6, child: OutlineText(item.label, size: cell * 0.32)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 보상 터짐을 창으로 띄운다(창 밖에서 받는 보상 — 상자·보스·도감). 누르거나 [hold]가 지나면 닫힌다.
/// 닫힐 때까지 기다린다(보스 처치 창 같은 다음 창을 그 뒤에 띄우게).
Future<void> showRewardBurst(
  BuildContext context, {
  required List<RewardItem> items,
  String? source,
  String? openedSource,
  RewardTier tier = RewardTier.gold,
  bool lite = false,
  Duration hold = const Duration(milliseconds: 1200),
}) async {
  var open = true;
  final close = Timer(RewardBurst.duration + hold, () {
    if (open && context.mounted) Navigator.of(context).pop();
  });
  await showDialog<void>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (dialog) => GestureDetector(
      key: const Key('reward.burst'),
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(dialog).pop(),
      child: RewardBurst(items: items, source: source, openedSource: openedSource, tier: tier, lite: lite),
    ),
  );
  open = false;
  close.cancel();
}
