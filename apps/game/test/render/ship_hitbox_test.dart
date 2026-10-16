import 'dart:typed_data';

import 'package:flame/cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/src/battle/topdown/geometry.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:pirate_dot/render/sprites/sprite_bank.dart';

import 'helpers.dart';

/// 배 충돌 크기 = 배 그림 크기 (제안 docs/plans/active/platform-ship-hitbox.md, S1 채택 2026-10-15).
/// 등급·선체 강화 단계마다 선체 층(`td:<tier>:hull` 프레임)의 불투명 영역 × waves.top.shipScale을 재서,
/// 엔진 선체 캡슐(geometryFor)의 반폭·뱃머리·배꼬리와 ±[_tolerance] 단위 안인지 본다. 배율·그림·표 중 하나만 바뀌면 실패한다.
/// 돛·포신 층은 넣지 않는다(적이 돛 밑까지 오게, S3).
const _tolerance = 2.5; // 화면 약 5dp. 그림의 단계별 크기가 고르지 않은 곳(군함 3단계 뱃머리 −1px)까지 받는다.

void main() {
  testWidgets('선체 캡슐이 선체 그림과 맞다(등급 × 선체 단계)', (tester) async {
    final bank = (await tester.runAsync(() => SpriteBank.load(Images(prefix: 'assets/'), tables)))!;
    final scale = tables.waves.raw.obj('top').number('shipScale');
    for (final tier in tables.shipTiers.tiers) {
      final sheet = bank['td:${tier.id}:hull'];
      expect(sheet, isNotNull, reason: '${tier.id} 선체 그림');
      final bytes = (await tester.runAsync(() => sheet!.image.toByteData()))!;
      final fw = sheet!.frameW.round();
      final fh = sheet.frameH.round();
      for (var f = 0; f < sheet.frames; f++) {
        final (hw, bow, stern) = _extents(
          bytes,
          sheet.image.width,
          f * fw,
          fw,
          fh,
          ram: f + 1 >= _ramFromStage ? _ramPx : 0,
        );
        final geo = geometryFor(tables, tier.stage, hullStage: f + 1) as TopGeometry;
        final t = geo.top;
        final eBow = t.hullHalfLength - t.hullOffset;
        final eStern = t.hullHalfLength + t.hullOffset;
        final row =
            '${tier.id} 단계${f + 1}: 그림(반폭·뱃머리·배꼬리) ${(hw * scale).toStringAsFixed(1)}·${(bow * scale).toStringAsFixed(1)}·'
            '${(stern * scale).toStringAsFixed(1)} 엔진 ${t.hullHalfWidth.toStringAsFixed(1)}·${eBow.toStringAsFixed(1)}·'
            '${eStern.toStringAsFixed(1)}';
        expect((hw * scale - t.hullHalfWidth).abs(), lessThanOrEqualTo(_tolerance), reason: row);
        expect((bow * scale - eBow).abs(), lessThanOrEqualTo(_tolerance), reason: row);
        expect((stern * scale - eStern).abs(), lessThanOrEqualTo(_tolerance), reason: row);
      }
    }
  });
}

/// 충각(뱃머리 앞 돌출)은 선체 강화 5단계부터 7픽셀(tools/art gen_topdown_ships, S3) — 충돌에는 넣지 않는다.
const _ramFromStage = 5;
const _ramPx = 7;

/// 선체 그림의 반폭, 배 중심(프레임 가운데)에서 뱃머리·배꼬리까지(그림 픽셀 = 배율 1 단위). S3 규칙:
/// 바깥 외곽선 1픽셀은 빼고, 뱃머리는 바우스프릿(폭 3픽셀 이하 줄)과 충각([ram]픽셀)을 뺀다.
(double, double, double) _extents(ByteData bytes, int stride, int x0, int w, int h, {required int ram}) {
  final cx = w / 2;
  final cy = h / 2;
  var hw = 0.0;
  int? first;
  var last = 0;
  for (var y = 0; y < h; y++) {
    var left = -1;
    var right = -1;
    for (var x = 0; x < w; x++) {
      if (bytes.getUint8(((y * stride) + x0 + x) * 4 + 3) <= 32) continue;
      if (left < 0) left = x;
      right = x;
    }
    if (left < 0) continue;
    final dx = ((left - cx).abs() > (right + 1 - cx).abs() ? (left - cx).abs() : (right + 1 - cx).abs()) - 1;
    if (dx > hw) hw = dx;
    if (right - left + 1 <= 3) continue; // 바우스프릿
    first ??= y;
    last = y;
  }
  return (hw, cy - first! - 1 - ram, last + 1 - cy - 1);
}
