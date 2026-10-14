# 스펙: 저장 견고화 — 재시도·디스크 가득·백업 2단

- 상태: 작업 지시(S1, 2026-10-14) — 결과 보고 때 검토 · 레인: platform · 설계서 5.2 · 대상 `apps/game/lib/adapters/file_save_store.dart`
- 계약(`SaveStore` 포트)·세이브 스키마 변경 없음.

## 문제
1. `EngineHost.save()`는 `_saving = _saving.then((_) => store.write(text))`로 저장을 줄 세운다. `write`가 한 번 던지면 `_saving`이
   실패한 Future로 남아 **이후 모든 저장이 조용히 건너뛰어진다**(앱을 다시 켤 때까지). 던진 예외는 잡히지 않아 Crashlytics에 치명 오류로 간다.
2. 쓰기가 일시적으로 실패해도(파일 잠금·I/O) 다시 시도하지 않는다.
3. 디스크가 가득 차면 반쯤 쓴 `save.tmp`가 남아 공간을 더 막는다.
4. `save.json`과 `save.bak`이 둘 다 깨지면 새 게임이 된다.

## 규칙
1. `write`는 **절대 던지지 않는다**. 실패는 `failure`(`ValueListenable<SaveFailure?>`)로 알린다: `diskFull` | `io`. 다음 성공 때 null.
2. 일시 실패(`FileSystemException`, 디스크 가득 제외)는 최대 3번 시도(대기 50ms → 200ms). 그래도 실패하면 `io`.
3. 디스크 가득(OS 오류 코드 Android/Linux 28 `ENOSPC`, Windows 112·39)은 재시도하지 않고 `save.tmp`를 지운 뒤 `diskFull`.
4. 어떤 실패에서도 기존 `save.json`·`save.bak`은 그대로다(tmp에 먼저 쓰고, 성공해야 돌린다).
5. 돌리기: `save.bak` → `save.bak2`, `save.json` → `save.bak`, `save.tmp` → `save.json`.
6. `readBackup()`: `save.bak`이 없거나 `SaveCodec.decode`가 실패하면 `save.bak2`가 있으면 그것을, 없으면 `save.bak` 원문을 준다
   (→ `loadSave`(코어) 변경 없이 3단 복구).
7. 같은 내용이 연속으로 와도 그대로 쓴다(최적화 안 함 — 10초마다라 비용 무시).

## 수용 기준
1. 쓰기 2번 실패 후 3번째 성공 → 저장됨, `failure` null, 대기 [50ms, 200ms].
2. 3번 다 실패 → 던지지 않음, `failure` = io, 기존 `save.json` 그대로.
3. 디스크 가득 → 1번만 시도, `save.tmp` 없음, `failure` = diskFull, 기존 `save.json`·`save.bak` 그대로.
4. 실패 뒤 성공하면 `failure` null.
5. 세 번 쓰면 json = 3번째, bak = 2번째, bak2 = 1번째.
6. json·bak이 깨지고 bak2가 온전 → `loadSave`가 bak2로 복구.
7. bak만 깨지고 bak2 없음 → 기존처럼 `SaveCorruptException`(새 게임은 main.dart가 결정).
8. 기존 테스트(저장·복원 통합 포함) 그대로 통과.

## UI·S1에 넘길 것
- `failure`를 보여 줄지(예: "저장 공간이 부족해요" 토스트)는 ui 레인 결정 — 문구 키는 ui 접두어. 필요하면 요청서.
- `EngineHost`도 이중 안전장치로 `s.write(text)`에 `catchError`를 두길 권함(S1 소유).
