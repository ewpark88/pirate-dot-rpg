import 'package:flutter/material.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// Pirate Busters 카드 (S1 결정: 선원 그림 = PB 카드 일러스트, S3 import · assets/ui/cards/cards.json 규칙).
/// 캔버스 252×358 (파일은 ×2 = 504×716), 카드 몸 (0,0)~(240,340)은 캔버스 (6,12)부터.
/// 쌓는 순서: 등급 back → 캐릭터(그림 창 12,12–228,250 r9로 자름) → 등급 front → 글자(별 리본·이름) → 배지.
const double pbCardAspect = _canvasW / _canvasH;

const _canvasW = 252.0;
const _canvasH = 358.0;
const _bodyX = 6.0;
const _bodyY = 12.0;

/// 그림 창 (몸 좌표).
const _windowRect = Rect.fromLTWH(12, 12, 216, 238);
const _windowRadius = 9.0;

/// 캐릭터 그림(이미 .74배) 놓는 자리 (몸 좌표), 크기 = 355×480 파일의 절반.
const _charLeft = 31.2;
const _charTop = 13.9;
const _charW = 177.5;
const _charH = 240.0;

/// 이름 자리 (몸 좌표).
const _nameY = 292.0;

/// cards.json `glow` — 등급별 바깥 빛 (전설·신화는 연출에서 키운다).
const Map<String, List<(Color, double)>> pbGlow = {
  'rare': [(Color(0x7358A6FF), 5)],
  'hero': [(Color(0x99C07BFF), 8)],
  'legend': [(Color(0xBFFFC846), 12)],
  'mythic': [(Color(0xB37AF0FF), 10), (Color(0x80FF9AE8), 6)],
};

/// 카드 그림 경로.
String pbCardBack(String rarityId) => 'assets/ui/cards/card_${rarityId}_back.webp';
String pbCardFront(String rarityId) => 'assets/ui/cards/card_${rarityId}_front.webp';
String pbCharacter(String crewId) => 'assets/crew_art/${crewId}_card.webp';
String pbPortrait(String crewId) => 'assets/crew_art/${crewId}_portrait.webp';
const pbLegendRays = 'assets/ui/cards/card_legend_rays.webp';

Widget _image(String asset) => Image.asset(asset, fit: BoxFit.fill);

/// 카드 캔버스(252×358)를 받은 폭에 맞춰 늘린다.
class _Canvas extends StatelessWidget {
  const _Canvas({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: pbCardAspect,
    child: FittedBox(
      child: SizedBox(
        width: _canvasW,
        height: _canvasH,
        child: Stack(clipBehavior: Clip.none, children: children),
      ),
    ),
  );
}

/// 카드 뒷면 (소환 연출의 덮인 카드).
class PbCardBack extends StatelessWidget {
  const PbCardBack({required this.rarityId, super.key});

  final String rarityId;

  @override
  Widget build(BuildContext context) => _Canvas(children: [Positioned.fill(child: _image(pbCardBack(rarityId)))]);
}

/// 카드 앞면: 캐릭터·등급 테두리·별 리본·이름. [silhouette]면 캐릭터를 어두운 실루엣으로(미보유).
class PbCardFront extends StatelessWidget {
  const PbCardFront({
    required this.crew,
    required this.rarity,
    required this.name,
    this.silhouette = false,
    this.topLeft,
    this.topRight,
    super.key,
  });

  final CrewDef crew;
  final RarityDef rarity;
  final String name;
  final bool silhouette;

  /// 그림 창 왼쪽·오른쪽 위 배지 (레벨·카드 수·NEW 등).
  final Widget? topLeft;
  final Widget? topRight;

  @override
  Widget build(BuildContext context) {
    final character = _image(pbCharacter(crew.id));
    return _Canvas(
      children: [
        Positioned.fill(child: _image(pbCardBack(rarity.id))),
        Positioned(
          left: _bodyX + _windowRect.left,
          top: _bodyY + _windowRect.top,
          width: _windowRect.width,
          height: _windowRect.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_windowRadius),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _charLeft - _windowRect.left,
                  top: _charTop - _windowRect.top,
                  width: _charW,
                  height: _charH,
                  child: silhouette
                      ? ColorFiltered(
                          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.82), BlendMode.srcIn),
                          child: character,
                        )
                      : character,
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(child: _image(pbCardFront(rarity.id))),
        // 등급 별은 카드 앞면 그림(리본 왼쪽)에 이미 그려져 있다 — 코드로 또 그리지 않는다(사용자 지적 2026-10-16 별 중복).
        // 이름 (몸 120,292 가운데, 어두운 획).
        Positioned(
          left: 14,
          right: 14,
          top: _bodyY + _nameY - 16,
          child: Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Skin.text(name.length > 8 ? 22 : 26, color: silhouette ? const Color(0xFFB8C2D6) : Colors.white)
                .copyWith(
                  shadows: const [
                    Shadow(color: Color(0xFF14161C), offset: Offset(0, 2)),
                    Shadow(color: Color(0xFF14161C), offset: Offset(2, 0)),
                    Shadow(color: Color(0xFF14161C), offset: Offset(-2, 0)),
                    Shadow(color: Color(0xFF14161C), offset: Offset(0, -1)),
                  ],
                ),
          ),
        ),
        if (topLeft case final w?) Positioned(left: _bodyX + 18, top: _bodyY + 18, child: w),
        if (topRight case final w?) Positioned(right: _bodyX + 18, top: _bodyY + 18, child: w),
      ],
    );
  }
}

/// 카드 위 작은 둥근 배지 (레벨·카드 수).
class PbBadge extends StatelessWidget {
  const PbBadge(this.text, {this.color = const Color(0xCC2B3A55), this.ink = Colors.white, super.key});

  final String text;
  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: Skin.text(19, color: ink)),
  );
}
