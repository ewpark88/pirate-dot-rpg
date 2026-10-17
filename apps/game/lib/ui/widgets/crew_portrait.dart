import 'package:flutter/material.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/skin/pb_card.dart' show pbPortrait;

/// 선원 초상: Pirate Busters 고해상 초상(카드와 같은 그림, 둥근 칸). 그림이 없으면 옛 도트 팩(`crews.json` portrait,
/// 최근접 확대), 그것도 없으면 사람 아이콘. (S1 실기기 ⑤ — MVP 창이 옛 작은 도트였다.)
class CrewPortrait extends StatelessWidget {
  const CrewPortrait({required this.crew, this.size = 32, super.key});

  final CrewDef crew;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.22),
    child: Image.asset(
      pbPortrait(crew.id),
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/${crew.portrait}',
        width: size,
        height: size,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => Icon(Icons.person, size: size),
      ),
    ),
  );
}
