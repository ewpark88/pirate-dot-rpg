import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/proto/proto_screen.dart';

import '../ui/ui_harness.dart' show loadGoldenFonts;

/// 시험판 화면: 그려지고, 시간이 흐르면 끝나고 '다시 하기'로 새 판.
/// `PROTO_DUMP=<폴더>`면 몇 장면을 PNG로 남긴다(사람이 그림을 보는 용도, 골든 아님).
void main() {
  final dump = Platform.environment['PROTO_DUMP'];
  final key = GlobalKey();
  setUpAll(loadGoldenFonts);

  Future<void> pumpProto(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Galmuri11'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ko'),
          home: const ProtoScreen(seed: 3),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200))); // 아틀라스 디코드
    await tester.pump();
  }

  Future<void> save(WidgetTester tester, String name) async {
    if (dump == null) return;
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2.8125);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dump/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('그려지고 3분 뒤 결과 → 다시 하기', (tester) async {
    await pumpProto(tester);
    for (final (sec, name) in [(20, 'proto_020s'), (70, 'proto_070s'), (170, 'proto_170s')]) {
      final target = Duration(seconds: sec);
      var t = Duration.zero;
      while (t < target) {
        await tester.pump(const Duration(milliseconds: 100));
        t += const Duration(milliseconds: 100);
      }
      await save(tester, name);
      if (sec == 70) {
        // 연속 프레임 8장(50ms 간격) — 움직임 확인용 시트
        for (var f = 0; f < 8; f++) {
          await tester.pump(const Duration(milliseconds: 50));
          await save(tester, 'seq_$f');
        }
      }
    }
    // 프레임마다 시뮬 최대 4걸음(멈춤 방지) — 100ms 프레임이면 실제보다 느리게 흐르므로 결과가 뜰 때까지 더 돌린다.
    for (var i = 0; i < 2000 && find.byKey(const Key('proto.again')).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('proto.again')), findsOneWidget);
    await save(tester, 'proto_result');
    await tester.tap(find.byKey(const Key('proto.again')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('proto.again')), findsNothing);
  });
}
