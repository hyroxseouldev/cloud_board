# STA-189 1차 A/C 검증 및 인계

범위는 수업 저장과 센터 템플릿 생성이다. 디스플레이, 재생 세션, 타이머,
음원, 기기 연결 정책은 변경하지 않는다. 배포/병합 및 실제 앱 검증은 통합 담당이 수행한다.

## 변경 및 호환성

- 클라이언트 저장 준비에서 설정과 기존 수업을 `Source.server`로 함께 읽는다.
  두 조회가 모두 성공해야 callable을 호출한다. 기존 unknown field, 레거시
  설정, `ifAbsent`, 복원, last-writer-wins DTO 처리는 그대로다.
- `saveWorkout`의 기존 수업 내용 수정은 수업/요약만 쓴다. 전체 사용량
  조회와 usage 문서 read/write를 생략한다. 삭제된 수업 복원은 신규 생성이다.
- 생성/복원은 같은 트랜잭션에서 usage 공유 문서를 읽고 쓰며, 현재 수업/슬라이드
  문서를 projection으로 집계한다. 두 마지막 슬롯 요청은 공유 usage 충돌로
  직렬화된다. 레거시 직접 삭제 직후도 실제 문서를 세므로 비동기 트리거를 기다리지 않는다.
  기존 문서를 읽은 뒤 동시 삭제되면 Firestore 트랜잭션이 재시도해 생성 분기로 간다.
- `syncWorkoutPlanUsage`는 before/after 문서가 둘 다 존재하는 수정만 생략한다.
  생성/삭제 또는 불완전한 이벤트는 기존 현재 문서 재집계를 유지한다.
  중복/역순 이벤트는 event count delta를 적용하지 않는다.
- 미리보기와 추가가 호출하는 `renderDraft`에서 최종 1920×1080 PNG 한 장만
  최대 8 MiB까지 메모리에 보관한다. 더 큰 결과는 반환하되 저장하지 않는다.
  같은 권한 세대와 전체 편집 내용/레시피/렌더러 버전의 진행 중 요청도 공유한다.
- 계정/센터는 repository lifetime으로 격리한다. 카탈로그 변경/권한 거부/만료/
  scope 해제는 결과와 진행 중 요청 참조를 폐기한다. 추가 호출도 현재 권한과
  게시된 정확한 레시피를 검사하며, 늦은 결과도 다시 검사한다. 기존 6시간 권한
  유효기간 정책, 배경 20 MiB 캐시, 180ms debounce, 인증된 Storage 요청은 유지한다.
- 결과는 계속 표준 PNG `imageSource`다. 새로운 디스플레이 처리 계약은 없다.
  서버 변경은 `saveWorkout`, `syncWorkoutPlanUsage`에 해당하며 기존 앱 입력을 받는다.

## 실행 환경과 관련 검증

Flutter 3.47.0 / Dart 3.13.0 설치 경로: `/Users/sunmkim/fvm/versions/3.47.0/bin`.
서버: Node 22.21.1, Android Studio JBR OpenJDK 21.0.8, Firebase CLI.
기본 시스템 Java 19로 에뮬레이터 시작이 한 번 실패했고 JBR 21로 재실행했다.

```sh
flutter test test/workout_quota_save_data_source_test.dart \
  test/center_slide_render_cache_test.dart test/center_slide_catalog_test.dart \
  test/center_slide_renderer_test.dart test/center_slide_creation_test.dart \
  test/center_slide_template_actions_test.dart --reporter expanded

node --test functions/test/workout-save-performance.test.js \
  functions/test/plan-usage-migration.test.js

firebase emulators:exec --project demo-cloudboard-plan-quotas \
  --config firebase.security-test.json --only firestore \
  'node functions/test/plan-quotas-emulator.mjs'

node functions/test/run-workout-save-callable-emulator.mjs
```

- Flutter 관련 68개와 Node 관련 11개 통과. 변경 Dart 파일 정적 분석도 수행.
- Firestore 에뮬레이터: 기존 수정 usage updateTime 불변, 최초 저장/재시도,
  last-writer-wins, createdAt, unknown fields, 레거시 설정 변환/복구, 삭제/복원,
  Free 마지막 슬롯 경쟁, 레거시 직접 삭제, 계정 삭제 lock 및 기존 플랜 호환 통과.
- HTTP callable 에뮬레이터: 실제 `src/index.js`의 `saveWorkout`만 재수출해
  Auth/Firestore와 실행한다. 무관한 트리거를 제외해 동기 저장 경로를 별도로
  검증한다. 앱 클라이언트 대신 테스트 HTTP 요청으로 새 수업/수정/읽기 복원,
  plain image 모듈과 요약, usage 불변, 동시 마지막 슬롯/복원/인증 거부를 확인했다.
  비동기 usage 수정 생략은 별도 단위 및 Firestore 에뮬레이터 검증으로 확인했다.
  포트는 Functions 19401, Auth 19490, Firestore 19480, hub 19440이다.
  runner는 demo 프로젝트와 임시 로컬 fixture만 쓰고 종료 시 정리한다.
- 캐시: 동일 미리보기/추가 렌더 횟수 1, 실제 PNG 1920×1080, 진행 중 공유,
  편집·레시피·권한·계정·센터 무효화, 늦은 결과 차단, 8 MiB 상한, 실패 재시도 검증.

이 결과는 성능 향상률이나 운영 지연 수치를 측정한 것이 아니다.

## 통합 담당의 실제 앱 확인

앱 E2E와 웹 브라우저 CORS 네트워크 검증은 아직 하지 않았다.

1. 같은 통합 SHA의 iOS 컨트롤러와 웹에서 기존 수업 수정 → 저장 → 재열기.
   실제 `saveWorkout` 실행과 Firestore 내용/요약이 맞는지 확인한다.
2. 센터 템플릿 미리보기 → 내용 그대로 추가 → 저장 → 재열기. PNG가 1920×1080이고
   `designTemplate/style/fingerprint`가 없거나 null인 기존 plain image 계약인지 확인한다.
3. 미리보기 뒤 문구/레시피 변경, 계정·센터 변경/권한 회수 시 오래된 PNG가 추가되지
   않는지 확인한다. 웹의 인증된 배경 PNG 다운로드 및 STA-194 CORS 경로도 확인한다.
4. 테스트 수업을 실제 디스플레이로 재생해 이미지/타이머/종료를 확인한다.
   이 작업의 단위 검증만으로 혼합 버전 실기 호환이나 실제 수업 성공을 주장하지 않는다.
