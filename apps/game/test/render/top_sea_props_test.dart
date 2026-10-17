import 'package:flutter_test/flutter_test.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/top/top_sea_props.dart';

import 'helpers.dart';

/// 흘러가는 바다 소품(사용자 2026-10-18 '떠내려가는 것들이 꼭 필요한가?' → 표 키로 끔, 코드는 남김).
void main() {
  test('지금 표: 소품 꺼짐(enabled false) — 다시 켜면 생긴다', () {
    final sea = tables.fxMap.raw.obj('topSea');
    expect(TopSeaProps.of(sea), isNull);
    final on = Map<String, dynamic>.of(sea.raw)..['props'] = {...sea.obj('props').raw, 'enabled': true};
    expect(TopSeaProps.of(JsonReader(on, 'topSea')), isNotNull);
  });

  test('풍경(섬·등대)은 전투 시야 밖 가장자리에 드물게 — 옆 거리가 화면 반폭 이상, 한 화면 1개', () {
    final land = tables.fxMap.raw.obj('atmosphere').obj('landmarks');
    final halfView = tables.waves.raw.obj('top').number('viewWidth') / 2;
    expect(land.number('lateral') * 0.8, greaterThanOrEqualTo(halfView * 0.9));
    expect(land.integer('maxOnScreen'), 1);
  });
}
