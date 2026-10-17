import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

// 스킨 k2 아이콘 칸 (디자인 개편 ①, S1 2026-10-17 — 쿵푸할매 장비 화면): 색 네모 칸(초록·파랑·보라 …) + 굵은 외곽선 +
// 위 광택, 왼쪽 위 작은 'Lv' 배지. 배 부위 줄과 선원 칸이 같이 쓴다.

/// 배 부위 칸 색 (부위 순서대로 돌려 쓴다).
const partCellColors = [Color(0xFF3FB54A), Color(0xFF3D8BE0), Color(0xFF9B5BE0), Color(0xFFE0883D), Color(0xFF3DBFC0)];

class IconCell extends StatelessWidget {
  const IconCell({required this.color, required this.child, this.size = 56, this.level, this.levelKey, super.key});

  /// 칸 색 (등급·부위 색).
  final Color color;
  final Widget child;
  final double size;

  /// 왼쪽 위 배지 글 (예 'Lv 16'). null이면 배지 없음.
  final String? level;
  final Key? levelKey;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(color, Colors.white, 0.28)!, color, Color.lerp(color, Skin.outline, 0.25)!],
                stops: const [0, 0.55, 1],
              ),
              borderRadius: BorderRadius.circular(size * 0.2),
              border: Border.all(color: Skin.outline, width: Skin.outlineWidth),
              boxShadow: Skin.shadowSmall,
            ),
          ),
        ),
        // 위 광택.
        Positioned(
          left: size * 0.12,
          right: size * 0.12,
          top: 4,
          height: size * 0.22,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
              ),
              borderRadius: BorderRadius.circular(size * 0.12),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: EdgeInsets.all(size * 0.1),
            child: Center(child: child),
          ),
        ),
        if (level case final lv?)
          Positioned(
            left: -4,
            top: -6,
            child: Container(
              key: levelKey,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: Skin.navyPanel,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Skin.outline, width: 1.5),
              ),
              child: Text(lv, style: Skin.outlined(11)),
            ),
          ),
      ],
    ),
  );
}
