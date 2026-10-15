import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/text/crew_name.dart';
import 'package:pirate_dot/ui/widgets/rarity_color.dart';

import 'ui_harness.dart';

/// 스킨 r1 시안 (docs/specs/ui-skin-r1.md) — 승인용 그림만 찍는다. 앱 코드는 아직 바꾸지 않는다.
/// `SKIN_MOCK_FONTS=<후보 글꼴 폴더> flutter test test/ui/skin_r1_mock_test.dart --update-goldens`로만 돈다.
/// 글꼴 파일은 커밋하지 않는다(사용자가 고른 뒤 assets로 들인다).

// ── 팔레트 (바다 파스텔 + 선명한 강조) ──
const _sky = Color(0xFFDDF2FF);
const _skyDeep = Color(0xFFB9E3FF);
const _cream = Color(0xFFFFFAF0);
const _card = Color(0xFFFFFFFF);
const _ink = Color(0xFF2B3A55);
const _sub = Color(0xFF7484A3);
const _primaryTop = Color(0xFF63C1FF);
const _primaryBottom = Color(0xFF1F84F2);
const _primaryEdge = Color(0xFF1565C8);
const _goldTop = Color(0xFFFFE27A);
const _goldBottom = Color(0xFFFFB31F);
const _goldEdge = Color(0xFFD98A00);
const _goldInk = Color(0xFF7A4600);
const _danger = Color(0xFFFF5A6E);
const _mint = Color(0xFF3CCB8A);
const _shadow = Color(0x2E1E3C78);

/// 파일 그림은 찍기 전에 미리 디코드해 둔다(골든 테스트의 가짜 시계에서는 파일 읽기가 끝나지 않는다).
final _decoded = <String, ui.Image>{};

Future<void> _decode(String path) async {
  if (_decoded.containsKey(path)) return;
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  _decoded[path] = (await codec.getNextFrame()).image;
}

Widget _file(String path, {FilterQuality quality = FilterQuality.medium, BoxFit fit = BoxFit.fill}) =>
    RawImage(image: _decoded[path], fit: fit, filterQuality: quality);

const _battlePath = 'test/render/goldens/battle_reference.png';

const _radiusCard = 16.0;
const _radiusButton = 14.0;

/// Jua·Gaegu에는 ‘·’ ‘×’ 글리프가 없다 → 그 글자만 Gowun Dodum으로 (실제 적용 때도 같은 대체 글꼴을 둔다).
TextStyle _t(String font, double size, {Color color = _ink, FontWeight w = FontWeight.normal}) => TextStyle(
  fontFamily: font,
  fontFamilyFallback: const ['GowunDodum'],
  fontSize: size,
  color: color,
  fontWeight: w,
  height: 1.2,
);

BoxDecoration _cardDeco({Color color = _card}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(_radiusCard),
  boxShadow: const [BoxShadow(color: _shadow, blurRadius: 10, offset: Offset(0, 3))],
);

/// 위가 밝은 그라데이션 + 아래 두꺼운 테두리(통통한 버튼).
Widget _button(String font, String label, {bool gold = false, Widget? icon, double height = 44, double? width}) {
  final top = gold ? _goldTop : _primaryTop;
  final bottom = gold ? _goldBottom : _primaryBottom;
  final edge = gold ? _goldEdge : _primaryEdge;
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: edge,
      borderRadius: BorderRadius.circular(_radiusButton),
      boxShadow: const [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0, 2))],
    ),
    padding: const EdgeInsets.only(bottom: 4),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
        borderRadius: BorderRadius.circular(_radiusButton),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ?icon,
          if (icon != null) const SizedBox(width: 6),
          Text(
            label,
            style: _t(font, 17, color: gold ? _goldInk : Colors.white, w: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

/// 동그란 아이콘 뱃지 (흰 원 + 그림자 + 빨간 점 선택).
Widget _roundIcon(String asset, {bool dot = false, double size = 44}) => Stack(
  clipBehavior: Clip.none,
  children: [
    Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: _card,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _shadow, blurRadius: 6, offset: Offset(0, 2))],
      ),
      alignment: Alignment.center,
      child: Image.asset(
        asset,
        width: size * 0.62,
        height: size * 0.62,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      ),
    ),
    if (dot)
      Positioned(
        right: -1,
        top: -1,
        child: Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            color: _danger,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
  ],
);

Widget _pill(String font, Widget icon, String text, {Color bg = _card, Color fg = _ink}) => Container(
  height: 32,
  padding: const EdgeInsets.only(left: 4, right: 12),
  decoration: BoxDecoration(
    color: bg,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [BoxShadow(color: _shadow, blurRadius: 5, offset: Offset(0, 2))],
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 6),
      Text(
        text,
        style: _t(font, 16, color: fg, w: FontWeight.bold),
      ),
    ],
  ),
);

Widget _bar(double value, {Color color = _mint, double height = 10}) => Container(
  height: height,
  decoration: BoxDecoration(color: const Color(0xFFE3ECF7), borderRadius: BorderRadius.circular(height)),
  alignment: Alignment.centerLeft,
  child: FractionallySizedBox(
    widthFactor: value.clamp(0.04, 1),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, 0.3)!, color]),
        borderRadius: BorderRadius.circular(height),
      ),
    ),
  ),
);

Widget _coin() =>
    Image.asset('assets/ui/coin.png', width: 24, height: 24, fit: BoxFit.fill, filterQuality: FilterQuality.none);

Widget _gem() => SizedBox(
  width: 22,
  height: 22,
  child: ClipRect(
    child: OverflowBox(
      alignment: Alignment.centerLeft,
      maxWidth: 66,
      child: Image.asset(
        'assets/ui/gem.png',
        width: 66,
        height: 22,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      ),
    ),
  ),
);

/// 상단 바 + 전장(렌더 기준 그림) + 선원 줄 + 목표 띠 — 세 시안이 같이 쓴다.
Widget _top(String font, {required List<Widget> body, required int tab}) {
  final battle = SizedBox(width: 320, height: 180, child: _file(_battlePath, quality: FilterQuality.none));
  return Scaffold(
    backgroundColor: _sky,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Row(
              children: [
                _pill(font, _coin(), '1.25M', fg: _goldInk),
                const SizedBox(width: 8),
                _pill(font, _gem(), '140'),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _pill(
                      font,
                      Image.asset(
                        'assets/ui/tailwind.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.fill,
                        filterQuality: FilterQuality.none,
                      ),
                      '1:30 ×2',
                      bg: const Color(0xFFE8F8EF),
                      fg: const Color(0xFF1E8A57),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _roundIcon('assets/ui/quest.png', dot: true),
                const SizedBox(width: 8),
                _roundIcon('assets/ui/gear.png'),
              ],
            ),
          ),
          // 전장(도트 유지): 둥근 모서리 창 안에.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 300,
                width: double.infinity,
                child: FittedBox(fit: BoxFit.cover, child: battle),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 목표 띠: 둥근 알약.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: _shadow, blurRadius: 5, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/ui/flag.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.none,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('도감 보너스까지 1명', style: _t(font, 16))),
                  SizedBox(width: 90, child: _bar(0.8, color: _goldBottom, height: 9)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(10, 0, 10, 10), children: body),
          ),
          _tabBar(font, tab),
        ],
      ),
    ),
  );
}

Widget _tabBar(String font, int selected) {
  const tabs = [
    ('assets/ui/tab_map.png', '항해', false),
    ('assets/ui/tab_ship.png', '배', true),
    ('assets/ui/tab_crew.png', '선원', false),
    ('assets/ui/tab_summon.png', '소환', true),
  ];
  return Container(
    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [BoxShadow(color: _shadow, blurRadius: 12, offset: Offset(0, 4))],
    ),
    child: Row(
      children: [
        for (final (i, (asset, label, dot)) in tabs.indexed)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 40,
                  decoration: BoxDecoration(
                    color: i == selected ? _skyDeep : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Image.asset(asset, width: 32, height: 32, fit: BoxFit.fill, filterQuality: FilterQuality.none),
                      if (dot && i != selected)
                        Positioned(
                          right: -4,
                          top: -2,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: _danger,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: _t(font, 14, color: i == selected ? _primaryEdge : _sub, w: FontWeight.bold),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// 선원 카드: 흰 카드, 위쪽 등급 색 그라데이션 판에 도트 초상, 레벨 알약, 별, 짧은 이름.
Widget _crewCard(String font, AppLocalizations l10n, CrewDef def, RarityDef rarity, {int? level, int? cards}) {
  final c = rarityColor(rarity);
  final owned = level != null;
  return Container(
    decoration: _cardDeco(),
    padding: const EdgeInsets.all(5),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(c, Colors.white, 0.55)!, Color.lerp(c, Colors.white, 0.15)!],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.bottomCenter,
              child: ColorFiltered(
                colorFilter: owned
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : ColorFilter.mode(Colors.black.withValues(alpha: 0.35), BlendMode.srcIn),
                child: Image.asset(
                  'assets/${def.portrait}',
                  width: 64,
                  height: 64,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
            if (level != null)
              Positioned(
                left: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _ink.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Lv $level',
                    style: _t(font, 12, color: Colors.white, w: FontWeight.bold),
                  ),
                ),
              ),
            if (cards != null && cards > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: _goldBottom, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '×$cards',
                    style: _t(font, 12, color: _goldInk, w: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < rarity.stars; i++)
              Image.asset(
                'assets/ui/star.png',
                width: 11,
                height: 11,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
          ],
        ),
        Text(
          shortCrewName(l10n, def),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _t(font, 15, color: owned ? _ink : _sub, w: FontWeight.bold),
        ),
      ],
    ),
  );
}

/// Pirate Busters 카드 (S1 결정: 선원 그림 = PB 카드 일러스트). 캔버스 252×358, 몸통 (0,0)~(240,340)은 캔버스 (6,12)부터.
/// 레이어: 등급 back → 캐릭터(그림 창 12,12–228,250으로 자름) → 등급 front → 글자(별 리본·이름·레벨).
final String? _pbArt = Platform.environment['PB_ART'];

Widget _pbCard(String font, AppLocalizations l10n, CrewDef def, RarityDef rarity, {int? level, int? cards}) {
  final dir = _pbArt!;
  final owned = level != null;
  Widget img(String path) => _file('$dir/$path');
  final character = img('characters/${def.id}/${def.id}_blue_card@2x.png');
  return AspectRatio(
    aspectRatio: 252 / 358,
    child: FittedBox(
      child: SizedBox(
        width: 252,
        height: 358,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: img('ui/cards/card_${rarity.id}_back@1x.png')),
            // 그림 창 (몸통 12,12,216×238 → 캔버스 18,24), 캐릭터는 translate(31.2,13.9) scale(.74).
            Positioned(
              left: 18,
              top: 24,
              width: 216,
              height: 238,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 31.2 - 12,
                      top: 13.9 - 12,
                      width: 177.6,
                      height: 239.8,
                      child: owned
                          ? character
                          : ColorFiltered(
                              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.82), BlendMode.srcIn),
                              child: character,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(child: img('ui/cards/card_${rarity.id}_front@1x.png')),
            // 별 리본 (기준선 258).
            Positioned(
              left: 0,
              right: 0,
              top: 12 + 244,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < rarity.stars; i++)
                    Image.asset(
                      'assets/ui/star.png',
                      width: 18,
                      height: 18,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.none,
                    ),
                ],
              ),
            ),
            // 이름 (몸통 120,292 가운데).
            Positioned(
              left: 14,
              right: 14,
              top: 12 + 276,
              child: Text(
                shortCrewName(l10n, def),
                textAlign: TextAlign.center,
                maxLines: 1,
                style: _t(font, 26, color: owned ? Colors.white : const Color(0xFFB8C2D6)).copyWith(
                  shadows: const [Shadow(color: Color(0xFF14161C), offset: Offset(0, 2))],
                ),
              ),
            ),
            if (level != null)
              Positioned(
                left: 6 + 18,
                top: 12 + 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _ink.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Lv $level', style: _t(font, 18, color: Colors.white)),
                ),
              ),
            if (cards != null && cards > 0)
              Positioned(
                right: 6 + 18,
                top: 12 + 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _goldBottom, borderRadius: BorderRadius.circular(10)),
                  child: Text('×$cards', style: _t(font, 18, color: _goldInk)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Widget _crewScreen(String font, AppLocalizations l10n, GameTables t, GameState s, {int columns = 4, int count = 12}) {
  final crews = [...t.crews.crews]..sort((a, b) => a.num.compareTo(b.num));
  return _top(
    font,
    tab: 2,
    body: [
      Container(
        decoration: _cardDeco(color: _cream),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('도감 4/40', style: _t(font, 19, w: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFFF0C2), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '공격력 +0%',
                    style: _t(font, 14, color: _goldInk, w: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _bar(0.1, color: _goldBottom),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _button(font, '자동 편성')),
                const SizedBox(width: 8),
                Expanded(child: _button(font, '일괄 합치기', gold: true)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: _pbArt == null ? 0.66 : 252 / 358,
        children: [
          for (final c in crews.take(count))
            (_pbArt == null ? _crewCard : _pbCard)(
              font,
              l10n,
              c,
              s.crews[c.id] == null ? t.rarities.byId(c.baseRarity) : rarityOfLevel(t.rarities, s.crews[c.id]!.level),
              level: s.crews[c.id]?.level,
              cards: s.crews[c.id]?.cards,
            ),
        ],
      ),
    ],
  );
}

Widget _voyageScreen(String font) => _top(
  font,
  tab: 0,
  body: [
    Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/ui/tab_ship.png',
                width: 28,
                height: 28,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('산호초 · 스테이지 37-2', style: _t(font, 19, w: FontWeight.bold)),
              ),
              Text('37/50', style: _t(font, 15, color: _sub)),
            ],
          ),
          const SizedBox(height: 8),
          _bar(0.74, color: _primaryBottom),
          const SizedBox(height: 10),
          Text('해역 보스까지 스테이지 13', style: _t(font, 16)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('대왕 소라게', style: _t(font, 16, w: FontWeight.bold)),
              const SizedBox(width: 8),
              for (final w in ['곡사', '공중'])
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFE3E7), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '약점 $w',
                    style: _t(font, 14, color: const Color(0xFFD23A50), w: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 10),
    Container(
      decoration: _cardDeco(color: _cream),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                'assets/ui/moon.png',
                width: 26,
                height: 26,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('오프라인 골드 시간당 3.03K · 최대 8시간', style: _t(font, 16))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Image.asset(
                'assets/ui/tailwind.png',
                width: 26,
                height: 26,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('순풍 1:30 · 골드 ×2', style: _t(font, 16), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              _button(
                font,
                '×2',
                gold: true,
                height: 38,
                icon: Image.asset(
                  'assets/ui/ad.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    const SizedBox(height: 10),
    Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/ui/tab_map.png',
                width: 28,
                height: 28,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
              const SizedBox(width: 8),
              Text('보물지도', style: _t(font, 19, w: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text('지도 조각 0개 · 피해·골드 +0%', style: _t(font, 16, color: _sub)),
          const SizedBox(height: 8),
          _bar(37 / 40, color: _goldBottom),
          const SizedBox(height: 6),
          Text('스테이지 40부터 환생할 수 있어요', style: _t(font, 15, color: _sub)),
        ],
      ),
    ),
  ],
);

/// 글꼴 비교: 같은 문장(한글·숫자·영문)을 후보마다.
Widget _fontSheet(List<(String, String)> fonts) => Scaffold(
  backgroundColor: _sky,
  body: ListView(
    padding: const EdgeInsets.all(14),
    children: [
      for (final (family, label) in fonts)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _t('GowunDodum', 13, color: _sub)),
              Text('해적 키우기 · 보물지도 열기', style: _t(family, 24, w: FontWeight.bold)),
              Text('1.25M  14.3K  ×2  Lv 15  37/50', style: _t(family, 20)),
              Text('오프라인 골드 시간당 3.03K · 최대 8시간', style: _t(family, 16)),
              Text('Octo · Crab Bros · Summon ×10', style: _t(family, 16)),
            ],
          ),
        ),
    ],
  ),
);

void main() {
  final dir = Platform.environment['SKIN_MOCK_FONTS'];
  setUpAll(() async {
    await loadGoldenFonts();
    if (dir == null) return;
    for (final (family, file) in [
      ('Jua', 'jua_Jua-Regular.ttf'),
      ('GowunDodum', 'gowundodum_GowunDodum-Regular.ttf'),
      ('Gaegu', 'gaegu_Gaegu-Bold.ttf'),
      ('Dongle', 'dongle_Dongle-Bold.ttf'),
    ]) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(File('$dir/$file').readAsBytesSync())));
      await loader.load();
    }
  });

  Future<void> shoot(
    WidgetTester tester,
    Widget screen,
    String name, {
    Size size = s24Size,
    double dpr = s24Dpr,
  }) async {
    await tester.runAsync(() async {
      await _decode(_battlePath);
      final art = _pbArt;
      if (art != null) {
        for (final c in GameTables.load().crews.crews.take(18)) {
          await _decode('$art/characters/${c.id}/${c.id}_blue_card@2x.png');
        }
        for (final r in ['common', 'rare', 'hero', 'legend', 'mythic']) {
          await _decode('$art/ui/cards/card_${r}_back@1x.png');
          await _decode('$art/ui/cards/card_${r}_front@1x.png');
        }
      }
    });
    tester.view
      ..physicalSize = size * dpr
      ..devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    );
    await precacheImages(tester);
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../../../docs/specs/ui-skin-r1/$name.png'));
  }

  testWidgets('시안: 글꼴 비교', skip: dir == null, (tester) async {
    await shoot(
      tester,
      _fontSheet(const [
        ('Jua', 'Jua (OFL) — 둥글고 굵음, 추천'),
        ('GowunDodum', 'Gowun Dodum (OFL) — 부드러운 본문'),
        ('Dongle', 'Dongle (OFL) — 귀엽지만 작게 보임'),
        ('Gaegu', 'Gaegu (OFL) — 손글씨'),
      ]),
      'fonts',
    );
  });

  testWidgets('시안: 선원 탭 (Jua)', skip: dir == null, (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
    await shoot(tester, _crewScreen('Jua', l10n, GameTables.load(), loadFixture('stage37_midgame')), 'crew_jua');
  });

  testWidgets('시안: 항해 탭 (Jua)', skip: dir == null, (tester) async {
    await shoot(tester, _voyageScreen('Jua'), 'voyage_jua');
  });

  testWidgets('시안: 선원 탭 (Gowun Dodum)', skip: dir == null, (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
    await shoot(
      tester,
      _crewScreen('GowunDodum', l10n, GameTables.load(), loadFixture('stage37_midgame')),
      'crew_gowun',
    );
  });

  testWidgets('시안: 선원 탭 태블릿 800×1280 (Jua, 6열)', skip: dir == null, (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ko'));
    await shoot(
      tester,
      _crewScreen('Jua', l10n, GameTables.load(), loadFixture('stage37_midgame'), columns: 6, count: 18),
      'crew_tablet_jua',
      size: const Size(800, 1280),
      dpr: 2,
    );
  });
}
