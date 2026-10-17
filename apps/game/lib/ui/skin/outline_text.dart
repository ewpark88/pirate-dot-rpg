import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:pirate_dot/render/text/outline_digits.dart';

/// 쿵푸할매식 테두리 글자(디자인 개편 공용 부품, docs/plans/active/design-kungfu-screens.md 0번):
/// 흰·금·빨강·초록 글씨 + 굵은 검은 테 + 아래쪽 살짝 그림자.
/// - 숫자만인 글자열(0~9·K·M·B·T·%·/·+·×·.·,·-·:·공백)은 아틀라스(assets/ui/digits, [outlineDigitsProvider]로 한 번 읽음)로 그린다.
/// - 그 밖(한글 등)과 아틀라스를 읽기 전에는 TextStyle 두 겹: 테(stroke, 글자 크기 × [strokeRatio]) 위에 채움.
/// [Skin.outlined](size, {color, stroke})와 인자를 맞춰 바꿔 끼울 수 있다 — 위젯이라 color 대신 [tone](4색).
enum OutlineTone {
  white(Color(0xFFFFFFFF)),
  gold(Color(0xFFFFD34A)),
  red(Color(0xFFFF5A4A)),
  green(Color(0xFF6BDC5A));

  const OutlineTone(this.color);

  /// 일반 글자(두 겹 TextStyle)에 쓰는 채움 색. 아틀라스는 같은 이름의 줄.
  final Color color;
}

/// 테 색(검은 남색) · 테 두께 비율 · 그림자.
const outlineInk = Color(0xFF14101C);
const strokeRatio = 0.18;
const _shadowRatio = 0.08;
const _digits = '0123456789KMBT%/+×.,-: ';

/// 아틀라스(기기 배율별로 한 번 읽음). 읽는 동안·실패하면 OutlineText는 두 겹 TextStyle로 그린다.
final FutureProviderFamily<OutlineDigits, double> outlineDigitsProvider = FutureProvider.family<OutlineDigits, double>(
  (ref, dpr) => OutlineDigits.load(devicePixelRatio: dpr),
);

/// 아틀라스로 그릴 수 있는 글자열인가.
bool isOutlineDigits(String s) => s.isNotEmpty && s.split('').every(_digits.contains);

class OutlineText extends ConsumerWidget {
  const OutlineText(
    this.text, {
    this.size = 16,
    this.tone = OutlineTone.white,
    this.stroke,
    this.align = TextAlign.center,
    this.fit = false,
    this.maxLines = 1,
    super.key,
  });

  final String text;

  /// 글자 크기(논리 px) — Skin.text 크기와 같은 뜻.
  final double size;
  final OutlineTone tone;

  /// 테 두께(px). 없으면 size × [strokeRatio].
  final double? stroke;
  final TextAlign align;

  /// 칸보다 길면 줄여서 맞춘다(FittedBox scaleDown — 4기기 줄넘침 방지).
  final bool fit;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final atlas = isOutlineDigits(text) ? ref.watch(outlineDigitsProvider(dpr)).value : null;
    final body = atlas != null ? _atlas(atlas) : _strokeText(context);
    return fit ? FittedBox(fit: BoxFit.scaleDown, child: body) : body;
  }

  /// 아틀라스 숫자 + 같은 글의 보이지 않는 Text (화면 낭독·테스트 find.text가 그대로 찾게).
  Widget _atlas(OutlineDigits atlas) => Stack(
    alignment: Alignment.center,
    children: [
      _AtlasText(text, atlas, size: size, tone: tone),
      Positioned.fill(
        child: Opacity(
          opacity: 0,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: TextStyle(fontSize: size),
          ),
        ),
      ),
    ],
  );

  Widget _strokeText(BuildContext context) {
    final w = (stroke ?? size * strokeRatio) * 2; // 테는 글자 선 가운데에 그려지므로 두 배
    final base = TextStyle(
      fontFamily: 'Jua',
      fontFamilyFallback: const ['GowunDodumSymbols'],
      fontSize: size,
      height: 1.2,
    );
    // 테 층은 RichText(낭독 제외) — find.text·화면 낭독은 채움 층 Text 하나만 본다.
    return Stack(
      children: [
        ExcludeSemantics(
          child: RichText(
            textAlign: align,
            maxLines: maxLines,
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              text: text,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = w
                  ..strokeJoin = StrokeJoin.round
                  ..color = outlineInk,
                shadows: [
                  Shadow(color: const Color(0x78000000), offset: Offset(0, size * _shadowRatio), blurRadius: 1),
                ],
              ),
            ),
          ),
        ),
        Text(
          text,
          textAlign: align,
          maxLines: maxLines,
          style: base.copyWith(color: tone.color),
        ),
      ],
    );
  }
}

/// 아틀라스 숫자 — 크기 = 글자 폭 × 칸 높이.
class _AtlasText extends StatelessWidget {
  const _AtlasText(this.text, this.atlas, {required this.size, required this.tone});

  final String text;
  final OutlineDigits atlas;
  final double size;
  final OutlineTone tone;

  @override
  Widget build(BuildContext context) {
    final h = atlas.layout.heightFor(size);
    return CustomPaint(
      size: Size(atlas.layout.measure(text, height: h), h),
      painter: _AtlasPainter(text, atlas, h, tone.name),
    );
  }
}

class _AtlasPainter extends CustomPainter {
  _AtlasPainter(this.text, this.atlas, this.height, this.color);

  final String text;
  final OutlineDigits atlas;
  final double height;
  final String color;

  @override
  void paint(Canvas canvas, Size size) => atlas.paint(canvas, Offset.zero, text, color: color, height: height);

  @override
  bool shouldRepaint(_AtlasPainter old) =>
      old.text != text || old.atlas != atlas || old.height != height || old.color != color;
}
