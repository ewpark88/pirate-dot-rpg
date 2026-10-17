import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 도크 탭 바로 열기 요청 (알약·안내의 바로가기 → 홈 화면이 그 탭 시트를 연다). 0 항해 · 1 배 · 2 선원 · 3 소환.
final dockTabRequestProvider = NotifierProvider<DockTabRequest, int?>(DockTabRequest.new);

class DockTabRequest extends Notifier<int?> {
  @override
  int? build() => null;

  // 요청은 동작(열어 줘)이라 메서드로 둔다.
  // ignore: use_setters_to_change_properties
  void open(int tab) => state = tab;

  /// 열린 시트를 닫아 달라 (환영 카드 순간 — 전장 가운데 카드 연출이 보이게, S3 c12ced0a).
  void close() => state = dockCloseRequest;

  /// 홈 화면이 처리한 뒤 비운다.
  void done() => state = null;
}

/// [DockTabRequest.close]의 값 (탭 번호가 아님).
const dockCloseRequest = -1;

/// 항해 탭 번호 (환생 카드가 있는 곳).
const voyageTab = 0;

/// 배 탭 번호 (화물칸 강화 줄이 있는 곳).
const shipTabIndex = 1;

/// 선원 탭 번호 (레벨업·합치기·승급).
const crewTabIndex = 2;
