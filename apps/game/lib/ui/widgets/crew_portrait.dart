import 'package:flutter/material.dart';
import 'package:game_data/game_data.dart';

/// 선원 초상 (도트 팩 32×32, `crews.json`의 portrait → `assets/<portrait>`).
/// 도트가 번지지 않게 최근접 확대. 이미지가 없으면(팩 누락) 사람 아이콘으로 대신한다.
class CrewPortrait extends StatelessWidget {
  const CrewPortrait({required this.crew, this.size = 32, super.key});

  final CrewDef crew;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/${crew.portrait}',
    width: size,
    height: size,
    // 기본(BoxFit.scaleDown)은 32px보다 키우지 않는다 → 칸에 꽉 채운다.
    fit: BoxFit.fill,
    filterQuality: FilterQuality.none,
    errorBuilder: (_, _, _) => Icon(Icons.person, size: size),
  );
}
