# platform → S1(계약): 유료 상품 기반 — PurchasePort v2 · 세이브 entitlements · 구매 명령

- 요청 레인 / 날짜: platform(S5) / 2026-10-18 · 지시: S1 '사용자 — 유료 상품 추가'. 상품 목록·값·보상은 S2 기획서 `economy-iap.md`(작성 중)가 정하고, 이 요청은 **틀**만.
- 바꿀 경로: `packages/game_core/lib/src/ports/ports.dart`(PurchasePort), `game_state.dart`(+entitlements·purchaseTokens), 명령·이벤트, 세이브 v+1 마이그레이션,
  `game_data/tables/iap.json`(S2 표), `apps/game/pubspec.yaml`(+`in_app_purchase: 3.3.1` — 2026-09 공개, 4주 지난 안정판, Dart ≥3.10. 지금 Flutter 3.44 OK).

## 왜 필요한가
지금 `PurchasePort`는 `purchase(id) → bool`·`owned()`뿐이다. Play 결제는
① 결과가 나중에 스트림으로 온다(대기 중·취소·실패·지급) ② 지급한 뒤 **acknowledge(비소모)·consume(소모)** 해야 하고 3일 안에 안 하면 자동 환불 ③ 앱이 죽으면 다음 실행에 같은 구매가 다시 온다 ④ 구독은 만료·환불을 다음 조회에서야 안다.
→ 포트가 이 흐름을 담아야 하고, 엔진은 **같은 구매를 두 번 지급하지 않게** 영수증 토큰을 기억해야 한다(세이브).

## 제안
### 1. 포트 (game_core, 결정론 밖 — 앱이 결과를 명령으로 엔진에 넣는다)
```dart
enum ProductKind { consumable, nonConsumable, subscription }

class ProductInfo { // 스토어가 준 값(현지화 가격 문자열). 없으면 그 상품 버튼을 숨긴다.
  final String id; final ProductKind kind; final String price; final String? currency; final int? micros;
}

sealed class PurchaseUpdate { final String productId; }
class PurchasePending  extends PurchaseUpdate {}                       // 결제 대기(편의점 결제 등) — UI '처리 중'
class PurchaseDelivered extends PurchaseUpdate { final String token; final DateTime at; }  // 지급해도 됨(검증 통과)
class PurchaseFailed   extends PurchaseUpdate { final String reason; } // cancelled | error | unavailable | alreadyOwned | invalid
class PurchaseRevoked  extends PurchaseUpdate {}                       // 복원 조회에서 사라짐(구독 만료·환불)

abstract interface class PurchasePort {
  Future<bool> available();                       // 결제 가능 기기·계정인가(아니면 상점 숨김)
  Future<List<ProductInfo>> products(Set<String> ids);
  Future<void> buy(String productId);             // 결과는 updates로
  Stream<PurchaseUpdate> get updates;
  Future<void> restore({required Set<String> active}); // 소유 비소모·구독을 다시 받음. [active] 중 스토어에 없는 것은 Revoked
  Future<void> complete(String token);            // 지급·저장이 끝난 뒤에만 부른다(acknowledge/consume)
}
```
`NoPurchases`(available=false)를 기본으로 둔다 — iOS(M6 전)·SDK 실패·운영자 끔.

### 2. 세이브 (v+1)
- `GameState.entitlements: Map<String, Entitlement>` — `Entitlement(since: DateTime, until: DateTime?)`. 키 = iap.json의 권리 id(예: `noAds`·`pass`). 구독은 `until` 대신 다음 조회에서 Revoked면 지운다.
- `GameState.purchaseTokens: List<String>` — 지급한 영수증 토큰(최근 200개, 해시 16자). 같은 토큰이 다시 오면 지급하지 않고 complete만.
- 마이그레이션: 빈 값.

### 3. 명령·이벤트 (EconomySystem — S2 구현)
| 이름 | 내용 |
| --- | --- |
| `GrantPurchase(productId, token, at)` | 토큰이 처음이면 iap.json 보상(젬·소환권 등)·권리를 지급하고 토큰 기록. 모르는 상품·이미 쓴 토큰이면 아무것도 안 함 |
| `RevokeEntitlement(id)` | 권리 끄기(구독 만료·환불) |
| `OpSetEntitlement(id, on)` | 운영자 '권리 켜기/끄기'(실제 결제 없음) |
| 이벤트 `PurchaseGranted(productId, rewards, entitlement?)` · `EntitlementChanged(id, active)` | UI 보상 연출·광고 끄기 등 |
- 권리를 읽는 곳(광고 제거면 AdsPort 앞, 패스면 보상 배수)은 S2 기획서대로 — 엔진 계산에 들어가면 game_core, 광고면 앱 배선.

### 4. 순서 (잃어버리지 않게 — 앱 배선 `main.dart`, S1)
`updates`의 `PurchaseDelivered` → `GrantPurchase` 명령 → 엔진 처리 + **즉시 저장(SaveRequested)** → 저장 완료 뒤 `complete(token)`.
저장 전에 앱이 죽으면 Play가 다음 실행에 같은 구매를 다시 보내고(미완료), 토큰이 처음이라 그때 지급된다. 지급 뒤·complete 전에 죽으면 다시 와도 토큰이 이미 있어 complete만.

### 5. 검증 (서버 없는 단계 — 로컬)
- 어댑터가 `PurchaseDelivered` 전에 확인: 상태 PURCHASED · 패키지 이름 일치 · 상품 id가 우리 표에 있음 · 토큰 있음. 아니면 `PurchaseFailed(invalid)`.
- (2단계, 사람 키 필요) Play 공개 키로 서명 확인 — 키는 Play 콘솔 > 수익 창출 설정에서 사람이 복사. 서버 검증은 랭킹 서버 생길 때.
- 한계: 로컬 검증은 루팅 기기 조작을 막지 못한다(오프라인 싱글 게임 — 감수, 설계서 9장 '서버 없음').

## 그동안 (platform, 계약 머지 전에도)
- 앱 쪽에 `adapters/purchase/`: `BillingSdk`(얇은 SDK 포장 인터페이스) + 가짜 SDK + `PlayPurchases`(위 포트 모양 그대로, 임시로 앱 안 인터페이스) + 시험(구매·취소·대기·중복 토큰·복원·Revoked·complete 순서).
- SDK 연결 파일(`in_app_purchase` 의존)은 pubspec 추가가 머지된 뒤.
- 운영자 패널 '구매 흉내'(가짜 SDK로 성공·취소·대기·환불) · '권리 켜기/끄기'는 계약 머지 뒤.

## 사람이 할 일 (Play 콘솔)
- 결제 프로필(판매자 계정) 만들기 · 상품 id 등록(S2 표와 같은 id) · 라이선스 테스트 계정(테스트 카드) · 비공개 테스트 트랙에 올린 빌드가 있어야 상품 조회가 된다
- (2단계) 앱 공개 키 복사 → 빌드 설정(커밋 안 함)
- 데이터 보안 양식: '금융 정보 > 구매 내역' 수집 여부 다시 답함(`data-safety.md`), 콘텐츠 등급 '디지털 구매' = 예로 다시

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
