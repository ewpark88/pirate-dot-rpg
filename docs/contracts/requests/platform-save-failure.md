# platform → ui: 저장 실패(diskFull·io) 표시 (S1 중계 → S4)

- 요청 레인 / 날짜: platform(S5) / 2026-10-15 · 스펙 `docs/specs/platform-save.md`
- 바꿀 경로: ui 레인 소유(`apps/game/lib/ui/`, `parts/ui.*.arb`) + main.dart override 1줄(S1). 계약 변경 없음.

## 왜 필요한가
- `FileSaveStore.write`는 던지지 않고 실패를 `failure`(`ValueListenable<SaveFailure?>`: `diskFull`·`io`, 성공하면 `null`)로만 알린다.
  지금은 아무도 듣지 않아서 **저장 공간이 가득 차도 플레이어는 모른 채 진행이 날아갈 수 있다.**
- 디스크 가득은 재시도해도 소용없어 사람이 공간을 비워야 한다 → 알려 줘야 한다.

## 제안 (코드 스케치)
```dart
// ui/state/… (이름은 ui가 정함)
final saveFailureProvider = Provider<ValueListenable<SaveFailure?>>((_) => ValueNotifier(null));
// main.dart (S1): saveFailureProvider.overrideWithValue(store.failure)

// HUD 위 얇은 띠(또는 SnackBar 1회) — failure가 null이 아닌 동안만
//   diskFull: "저장 공간이 부족해 진행을 저장하지 못했어요. 공간을 비우면 자동으로 다시 저장해요."
//   io:       "진행을 저장하지 못했어요. 잠시 뒤 다시 시도해요."
// 다음 저장이 성공하면 failure가 null로 돌아가 띠가 사라진다(어댑터가 처리).
```
- 문구 톤은 설계서 4.9(재촉 없음, 짧게). en도 함께.
- 자동 재시도는 이미 있다: 10초 자동 저장·`SaveRequested`·백그라운드 전환마다 다시 쓴다.
- `SaveFailure` import: `package:pirate_dot/adapters/file_save_store.dart`.

## 그동안 쓰는 임시 어댑터
없음(표시 안 함). 저장 자체는 어댑터가 막지 않고 다음 기회에 다시 쓴다.

## 처리 결과 (S1 작성)
- [ ] 반영 / 거절 / 수정 반영 — 커밋:
