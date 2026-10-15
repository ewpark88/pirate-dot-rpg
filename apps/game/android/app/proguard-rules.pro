# R8(릴리스 코드 줄이기) 예외 규칙.
#
# 2026-10-15 S24: 릴리스 빌드가 실행 즉시 종료 — "Failed to create an instance of androidx.work.impl.WorkDatabase".
# androidx.work 2.7.0(AdMob SDK가 끌어옴)은 Room이 리플렉션으로 찾는 *_Impl 클래스를 지키는 규칙이 부족해, R8이 지워 버린다.
# Room 데이터베이스 구현 클래스의 기본 생성자를 지킨다.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
