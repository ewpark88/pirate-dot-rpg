import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/pixel/pixel_sprite.dart';
import 'package:pirate_dot/ui/skin/skin.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/skin/skin_icon.dart';

import 'ui_harness.dart';

/// 스킨 r2 시안 (docs/specs/ui-skin-r2.md) — 승인용 그림만 찍는다. 앱 코드는 승인 뒤에 바꾼다.
/// `UI_MOCK_R2=1 flutter test test/ui/skin_r2_mock_test.dart --update-goldens`로만 돈다.
/// 왼쪽 = 지금(r1, 실제 위젯), 오른쪽 = r2 제안(이 파일의 시안 위젯).

final bool _on = Platform.environment['UI_MOCK_R2'] == '1';

// ── r2 제안 토큰 ──
const _cardTop = Color(0xFFFFFFFF);
const _cardBottom = Color(0xFFF3F8FF);
const _cardEdge = Color(0xFFD3E1F3);
const _highlight = Color(0xCCFFFFFF);
const _shadowR2 = [
  BoxShadow(color: Color(0x241E3C78), blurRadius: 18, offset: Offset(0, 6)),
  BoxShadow(color: Color(0x141E3C78), blurRadius: 3, offset: Offset(0, 1)),
];

/// r2 카드: 위가 밝은 그라데이션 + 아래 3dp 진한 테두리(살짝 떠 있는 판) + 안쪽 위 하이라이트 + 두 겹 그림자.
class _R2Card extends StatelessWidget {
  const _R2Card({required this.child, this.ribbon});

  final Widget child;
  final String? ribbon;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _cardEdge,
      borderRadius: BorderRadius.circular(18),
      boxShadow: _shadowR2,
    ),
    padding: const EdgeInsets.only(bottom: 3),
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cardTop, _cardBottom],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _highlight, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ribbon != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE6F3FF), Color(0xFFF7FBFF)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
              ),
              child: Text(ribbon!, style: Skin.text(15, color: Skin.primaryEdge)),
            ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    ),
  );
}

/// r2 뱃지 하나로 통일: 빨간 원 + 흰 테두리 + 숫자(없으면 점), 'NEW'는 같은 자리 알약.
class _R2Badge extends StatelessWidget {
  const _R2Badge({required this.child, this.count, this.isNew = false});

  final Widget child;
  final int? count;
  final bool isNew;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      child,
      Positioned(
        right: -6,
        top: -6,
        child: Container(
          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          padding: EdgeInsets.symmetric(horizontal: isNew || (count ?? 0) > 9 ? 6 : 0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF7A8A), Color(0xFFF0384F)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x40F0384F), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: Text(
            isNew ? 'NEW' : (count == null ? '' : '$count'),
            style: Skin.text(11, color: Colors.white),
          ),
        ),
      ),
    ],
  );
}

/// r2 버튼 겉모습(정지 화면): r1 버튼 위에 위쪽 절반 광택 띠 + (보상 버튼) 빛 줄기가 지나가는 한 장면.
class _R2Gloss extends StatelessWidget {
  const _R2Gloss({required this.child, this.shine});

  final Widget child;

  /// 0~1 빛 줄기 위치 (null이면 없음).
  final double? shine;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      Positioned(
        left: 6,
        right: 6,
        top: 4,
        height: 14,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      if (shine != null)
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Skin.radiusButton),
              child: Align(
                alignment: Alignment(-1 + 2 * shine!, 0),
                child: Transform.rotate(
                  angle: 0.4,
                  child: Container(
                    width: 16,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// r2 보상 반짝임: 숫자 둘레에 별 4~6개가 반짝(정지 화면은 한 장면).
class _Sparkles extends StatelessWidget {
  const _Sparkles({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(foregroundPainter: _SparklePainter(), child: child);
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(3);
    for (var i = 0; i < 6; i++) {
      final c = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height);
      final r = 5.0 + rng.nextDouble() * 4;
      final p = Path();
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        final rr = k.isEven ? r : r * 0.35;
        final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
        k == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      p.close();
      canvas
        ..drawPath(p, Paint()..color = i.isEven ? const Color(0xFFFFC93C) : const Color(0xFFFFF3B0))
        ..drawPath(
          p,
          Paint()
            ..color = const Color(0x80D98A00)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => false;
}

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6, top: 14),
  child: Text(text, style: Skin.text(14, color: Skin.sub)),
);

Widget _row(String title, Widget r1, Widget r2) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    _label(title),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: r1),
        const SizedBox(width: 16),
        Expanded(child: r2),
      ],
    ),
  ],
);

Widget _plainCard(Widget child) => Container(
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(color: Skin.card, borderRadius: BorderRadius.circular(16), boxShadow: Skin.shadow),
  child: child,
);

Widget _partLine(String name, String lv) => Row(
  children: [
    const SkinIcon('assets/ui/part_cannon.png', size: 28),
    const SizedBox(width: 8),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Skin.text(17)),
          Text(lv, style: Skin.text(13, color: Skin.sub)),
        ],
      ),
    ),
  ],
);

Widget _dockIcon(String asset, {bool r2 = false}) {
  final icon = Container(
    width: 50,
    height: 50,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Skin.card,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2.5),
      boxShadow: r2 ? _shadowR2 : Skin.shadow,
      gradient: r2
          ? const LinearGradient(
              colors: [_cardTop, _cardBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
          : null,
    ),
    child: PixelSprite(asset, dots: 16),
  );
  return icon;
}

void main() {
  testWidgets('시안: r2 구성 요소 (r1 | r2)', skip: !_on, (tester) async {
    await loadGoldenFonts();
    tester.view
      ..physicalSize = const Size(760, 660) * 2
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ko'),
        home: Scaffold(
          backgroundColor: Skin.sky,
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('r1 (지금)', style: Skin.text(22))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text('r2 제안', style: Skin.text(22, color: Skin.primaryEdge)),
                    ),
                  ],
                ),
                _row(
                  '1. 패널 깊이감 — 아래 테두리·위 하이라이트·두 겹 그림자·머리띠',
                  _plainCard(_partLine('대포', 'Lv 52')),
                  _R2Card(ribbon: '배 강화', child: _partLine('대포', 'Lv 52')),
                ),
                _row(
                  '2. 뱃지 통일 — 점/숫자/NEW 모두 같은 빨간 알약, 같은 자리(오른쪽 위 -6)',
                  Row(
                    children: [
                      PixelDot(child: _dockIcon(UiSprites.tabShip)),
                      const SizedBox(width: 18),
                      PixelDot(child: _dockIcon(UiSprites.tabCrew)),
                      const SizedBox(width: 18),
                      _dockIcon(UiSprites.tabSummon),
                    ],
                  ),
                  Row(
                    children: [
                      _R2Badge(child: _dockIcon(UiSprites.tabShip, r2: true)),
                      const SizedBox(width: 18),
                      _R2Badge(count: 3, child: _dockIcon(UiSprites.tabCrew, r2: true)),
                      const SizedBox(width: 18),
                      _R2Badge(isNew: true, child: _dockIcon(UiSprites.tabSummon, r2: true)),
                    ],
                  ),
                ),
                _row(
                  '3. 버튼 — 위 광택 띠, 보상(금색) 버튼은 3초마다 빛 줄기 1번 + 누를 때 짧은 "톡" 소리(pop 높은 음)',
                  Column(
                    children: [
                      SkinButton(onPressed: () {}, child: const Text('보스 도전')),
                      const SizedBox(height: 8),
                      SkinButton(tone: SkinTone.gold, onPressed: () {}, child: const Text('받기 ×2')),
                    ],
                  ),
                  Column(
                    children: [
                      _R2Gloss(
                        child: SkinButton(onPressed: () {}, child: const Text('보스 도전')),
                      ),
                      const SizedBox(height: 8),
                      _R2Gloss(
                        shine: 0.55,
                        child: SkinButton(tone: SkinTone.gold, onPressed: () {}, child: const Text('받기 ×2')),
                      ),
                    ],
                  ),
                ),
                _row(
                  '4. 전환 — 시트·창은 96%→100% + 흐림→선명(220ms), 탭 바꿀 때 내용이 옆으로 살짝 밀림 (세 장면)',
                  _plainCard(Text('r1: 위로 올라오기만', style: Skin.text(15, color: Skin.sub))),
                  Row(
                    children: [
                      for (final t in [0.3, 0.7, 1.0]) ...[
                        Expanded(
                          child: Opacity(
                            opacity: t,
                            child: Transform.scale(
                              scale: 0.96 + 0.04 * t,
                              child: _R2Card(
                                child: SizedBox(height: 40, child: Center(child: Text('${(t * 220).round()}ms'))),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                _row(
                  '5. 보상 반짝임 — 받은 숫자 둘레 별이 반짝, 숫자는 굴러 올라감',
                  _plainCard(
                    Row(
                      children: [
                        const SkinIcon(UiSprites.gem, size: 28),
                        const SizedBox(width: 8),
                        Text('젬 +50', style: Skin.text(20)),
                      ],
                    ),
                  ),
                  _R2Card(
                    child: _Sparkles(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SkinIcon(UiSprites.gem, size: 28),
                          const SizedBox(width: 8),
                          Text('젬 +50', style: Skin.text(22, color: Skin.primaryEdge)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await precacheImages(tester);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../../../docs/specs/ui-skin-r2/components.png'));
  });
}
