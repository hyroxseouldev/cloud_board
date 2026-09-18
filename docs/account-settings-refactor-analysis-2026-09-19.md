# 계정 공통 설정 리팩토링·성능 개선 분석

작성: 2026-09-19 · 대상: develop, STA-16 후속

상태: 분석 작성 시점의 소스 분석 및 설계 제안. 후속 구현 결과는 `docs/account-settings-refactor-implementation-2026-09-19.md` 참조. 앱 코드·운영 DB·보안 규칙은 변경하지 않았다. 빌드, 테스트, 성능 측정은 실행하지 않았다. 아래 효과는 코드 경로에 근거한 예상이며 실측 결과가 아니다.

## 결론

계정 공통 설정으로 제품 정책이 정해졌으므로 최종 저장 구조는 **워크아웃 콘텐츠 + 계정 설정 한 벌**이 맞다. 수업별 설정 필드를 계속 유지하면서 읽을 때 덮어쓰는 구조는 호환용 중간 단계로만 사용한다.

단, 진행 중인 수업에는 시작 당시 콘텐츠와 설정을 복사한 **불변 스냅샷**이 필요하다. 이는 수정 가능한 설정 원본을 중복 관리하는 것과 다르다. 다른 기기에서 공통 설정을 수정해도 현재 수업의 카운트다운·효과음이 바뀌면 안 된다.

DB 제품을 교체할 필요는 없다. 기존 Firestore·Realtime Database 안에서 저장 책임과 조회 경로를 분리하는 것을 권장한다.

## 확인된 구조와 개선 우선순위

| 우선순위 | 확인된 코드 경로 | 영향 | 권장 변경 |
| --- | --- | --- | --- |
| P0 | `LoadWorkouts.detail()`이 원본 조회 후 `preferences.apply()` 실행 | 편집용 객체가 이미 공통 설정으로 덮여 있고, 저장 시 워크아웃 문서에 다시 기록됨 | 콘텐츠 조회와 재생 설정 해석을 분리 |
| P0 | 새 워크아웃도 `initialDefaults.applyTo(Workout.empty())`로 생성 | 신규 데이터에서도 공통 설정 복제가 계속됨 | 새 초안은 콘텐츠만 생성, 미리보기에서 설정 합성 |
| P0 | `WorkoutModel`을 Firestore·로컬 저장·세션 스냅샷에 함께 사용 | `toJson()`에서 필드를 지우면 수업 스냅샷/구버전 호환까지 손상 가능 | 콘텐츠 DTO, 설정 DTO, 세션 DTO의 직렬화 경계 분리 |
| P1 | 상세 조회의 사용자 문서 조회 + 원격 시작의 `fresh: true` 재조회 | 캐시가 없는 상세 준비부터 시작까지 설정 조회가 두 차례 발생할 수 있음 | 편집 상세에는 설정 조회 없음. 원격 시작 시에만 최신 설정을 한 번 확정 |
| P1 | 공통 설정이 없으면 사용자 문서를 다시 읽어 `countdownDefaults` 조회 | 설정 화면 초기화가 순차적인 두 조회에 의존 | 레거시 사용자 문서 한 번으로 두 필드를 함께 해석 |
| P1 | 설정 저장 후 `ref.invalidate(workoutDetailProvider)` | 모든 활성 상세 공급자가 다시 로드될 수 있음. 초안 UI 안정성에도 불필요한 부담 | 계정 설정/미리보기만 갱신. 콘텐츠와 실행 중 스냅샷 유지 |
| P1 | 설정 저장 API가 `Future<void>`, 업로드 URL을 반환하지 않음 | 화면 초안에 로컬 이미지 데이터가 남아 재저장 시 같은 이미지 재업로드 가능 | 정규화된 저장 결과를 반환하고 초안·기준값·캐시에 반영 |
| P2 | 요약 목록을 모두 읽은 뒤 상세 전체를 두 작업자로 예열 | 첫 화면은 가볍지만 콜드 캐시에서는 결국 다수 상세 문서 다운로드 | 최근 사용/예약 수업 우선, 오프라인 저장 정책을 명시적으로 분리 |
| P2 | 페이지 단위로 나누지만 `loadSummaryPages()`가 마지막까지 자동 조회 | UI에서 일부만 보여도 전체 요약 읽음 | 실제 수요 기반 페이지 조회 검토. 검색·예약의 전체 목록 의존부터 분리 |

조회 호출 수와 실제 청구 읽기 수는 동일하다고 단정하지 않는다. 캐시·연결 상태·규칙 평가를 포함해 별도 측정해야 한다.

이미 구현된 좋은 구조는 유지한다: 목록 전용 `workoutSummaries`, 워크아웃/요약 원자적 저장, 세션 상태와 스냅샷 분리 프로토콜, 스냅샷 디코딩 재사용, 타이머 하위 위젯만 주기적으로 갱신하는 구독.

## 목표 DB 구조

```text
Firestore
users/{uid}                         프로필 및 기존 계정 메타데이터
users/{uid}/settings/workout         공통 설정 원본 1개 (신규 제안)
  schemaVersion: 1
  revision: 정수
  updatedAt: 서버 시각
  brandL / brandR
  soundTheme / countdownSound / workStartSound / restStartSound
  workoutEndSound / soundVolume
  countdown: {seconds, backgroundColor, imageSource, appearance}
users/{uid}/workouts/{workoutId}      콘텐츠만 (새 스키마 버전 명시)
  id / ownerId / author / name / folder / modules / createdAt / updatedAt
users/{uid}/workoutSummaries/{id}     목록용 요약, 유지

Realtime Database (기존 사용자 경로 아래)
activeSession                       진행 상태와 스냅샷 참조
playbackSnapshots/{sessionId}        시작 당시 콘텐츠 + 확정한 설정
                                    설정 revision/출처 추가 검토
```

`settings/workout` 경로는 제안이며 아직 존재 여부를 운영 DB에서 확인하지 않았다. 현재 구현의 `users/{uid}.workoutSettings`는 별도 테이블이 아니라 사용자 문서 안의 필드다.

별도 문서는 설정의 권한·버전·캐시 수명을 프로필과 분리하기 위해 추천한다. 경로를 분리하는 것 자체가 비용 절감이나 속도 향상을 보장하지는 않는다. 최소 변경만 원하면 현재 필드를 유지하고 읽기/쓰기 경계부터 분리해도 핵심 문제는 해결된다.

운동/휴식 시간, 세트, 슬라이드 이미지·텍스트·타이머 배치·색상, 슬라이드별 효과음 사용 여부 등 **콘텐츠별 옵션은 워크아웃에 남긴다**. 공통 설정으로 옮길 대상은 현재 STA-16의 화면 문구·카운트다운·사운드 종류/볼륨이다.

## 코드와 캐시 설계

1. `WorkoutContent`: 편집·복제·저장 대상. 계정 공통 설정 필드가 없다.
2. `AccountWorkoutSettings`: 공통 설정과 revision. 설정 UI도 가짜 `Workout.empty('account-settings')` 대신 이 타입을 직접 편집한다.
3. `PlaybackSnapshot`: 콘텐츠와 확정 설정을 가진 재생 전용 객체. 저장 저장소의 입력 타입으로 사용할 수 없게 한다.
4. `ResolvePlaybackSnapshot`: 로컬 재생·원격 시작·예약 시작·미리보기에서 동일한 해석 규칙을 사용하되, 조회 정책은 목적에 맞게 지정한다.
5. 구형 JSON 해석은 데이터 계층의 호환 어댑터에 모은다. 화면에 구형 필드 우선순위를 흩어 놓지 않는다.

계정 설정은 UID별 공유 캐시와 진행 중 요청 공유로 중복 조회를 줄인다. 로그인 전환/로그아웃 시 반드시 해제한다. 미리보기와 설정 화면은 캐시를 활용하고, 다른 기기 변경은 화면 사용 중 한 개의 공유 구독 또는 명시적 갱신으로 반영한다. 앱 전체에 영구 구독을 무조건 추가하지 않는다.

원격 수업 시작은 최신 설정 조회에 실패하면 기존처럼 실패를 알린다. 캐시로 몰래 대체하지 않는다. 로컬 오프라인 재생은 마지막으로 확인한 설정을 사용할 수 있도록 출처와 revision을 보관한다. 실행 중인 수업은 설정 공급자를 실시간 구독하지 않는다.

설정 저장은 revision 조건을 확인하는 트랜잭션으로 다른 기기의 변경을 조용히 덮어쓰지 않게 한다. 충돌 시 입력을 유지하고 다시 불러오기/재적용 안내를 제공한다. 이미지 업로드는 트랜잭션 밖에서 수행하고 정규화된 URL을 저장 결과로 반환한다. 실패 후 남은 파일은 참조 확인 후 정리한다.

## 기존 데이터 전환

**수업마다 설정이 다른 옛 계정을 아무 동작 변화 없이 하나의 공통 설정으로 자동 합치는 것은 불가능하다.** 대표값을 결정하는 과정이 필요하다.

| 기존 계정 상태 | 처리 |
| --- | --- |
| 이미 `workoutSettings` 저장됨 | 이 값을 그대로 공통 설정으로 이전 |
| 공통 설정 없음, 모든 워크아웃의 설정이 같음 | 구형 디코더로 기본값까지 해석한 후 동일성이 확인된 설정을 이전 |
| 공통 설정 없음, 워크아웃마다 설정이 다름 | 기존 동작 유지 상태로 표시. 사용자가 대표 워크아웃 설정 또는 새 공통 설정을 한 번 확정 |
| 워크아웃 없음 | 기존 `countdownDefaults`가 있으면 카운트다운을 계승하고 나머지는 앱 기본값 |

워크아웃은 있으나 `countdownDefaults`만 따로 존재하는 계정은 공통 설정이 확정된 것으로 보지 않는다. 이 값은 과거 신규 생성용 기본값이므로 기존 수업 설정보다 자동 우선하면 안 된다.

전환 순서:

1. 읽기 전용 사전 조사: 계정별 공통 설정 존재 여부, 서로 다른 구형 설정 묶음 수, 누락/손상 필드, 참조 이미지, 클라이언트/디스플레이 지원 상태를 집계. 실제 건수는 아직 조사하지 않았다.
2. 기존 형식과 새 형식을 모두 읽는 호환 앱을 먼저 배포. 콘텐츠/재생 직렬화를 분리하고 누락 필드 처리도 선행.
3. 새 설정 문서 규칙과 소유자 검증을 배포. 현재 규칙에는 `settings` 하위 문서 허용이 없으므로 앱만 경로를 바꾸면 권한 오류가 난다. 타입·범위·허용 필드·revision 검증을 포함한다.
4. 멱등적인 서버 이관 도구를 준비: dry-run 보고서, 계정별 체크포인트, 원본 백업, revision/문서 변경 조건 확인, 이미 이전한 값 보호. 운영 데이터는 클라이언트 화면 진입 중 일괄 변환하지 않는다.
5. 구버전 공존 기간에는 단일 쓰기 권한 경로를 결정한다. 새/옛 경로의 무조건 양방향 동기화는 금지한다. 구버전 설정 편집을 업데이트 안내로 차단할 수 없다면 서버에서 충돌 처리하는 한시적 호환 쓰기 경로가 먼저 필요하다.
6. 호환 클라이언트 보급 및 읽기 경로 검증 후 콘텐츠 전용 쓰기를 활성화. 전환 완료 계정만 옛 워크아웃 설정 필드를 제거한다. 미확정 계정은 원본을 유지한다.
7. 마지막에 사용자 문서의 `workoutSettings`·`countdownDefaults`와 구형 코드 경로를 제거. 진행 중 세션은 원래 스냅샷 형식을 유지한다.

현재 워크아웃 저장은 `merge: true`이므로 새 JSON에서 키만 생략해도 기존 필드가 삭제되지 않는다. 정리 도구가 명시적인 필드 삭제를 해야 한다. 구버전은 `brandL/brandR` 등이 있는 JSON을 전제로 하므로 필드를 먼저 삭제하면 안 된다.

롤백은 신형 앱/호환 앱으로 가능하도록 유지한다. 원본 필드 제거 후 예전 바이너리로 단순 회귀하는 것은 보장할 수 없다. 백업 복원 시에는 이관 이후 변경된 콘텐츠를 덮어쓰지 않도록 설정 필드만 조건부 복원한다.

계정 삭제는 현재 서버에서 사용자 문서 하위 `recursiveDelete`를 수행하므로 새 설정 문서도 해당 범위에 들어간다. 이미지 파일은 활성 세션·복제 워크아웃·기존 참조가 남을 수 있어 이관 직후 삭제하지 않는다.

## 성능 개선의 범위와 검증 계획

가장 확실한 효과는 불필요한 설정 조회와 상세 전체 무효화 제거다. 설정 필드 용량 자체는 이미지나 긴 슬라이드 데이터보다 작을 수 있으므로, 필드 제거만으로 큰 속도 향상을 약속하지 않는다.

| 측정 흐름 | 개선 목표 |
| --- | --- |
| 기존 워크아웃 편집 진입 | 콘텐츠 조회가 설정 조회 완료를 기다리지 않음 |
| 공통 설정 첫 진입 | 같은 레거시 사용자 문서 중복 조회 제거 |
| 공통 설정 저장 | 워크아웃 원본 쓰기 0, 상세 재조회 0 |
| 상세 준비 → 원격 시작 | 설정 서버 확정 1회. 별도 폴링이나 상세 단계 선조회 없음 |
| 같은 이미지로 설정 재저장 | 이미지 추가 업로드 0 |
| 목록 콜드 캐시 | 초기 표시 시간과 전체 네트워크/문서 읽기를 각각 측정 |
| 실행 중 설정 변경 | 타이머 재시작·효과음 변경·세션 스냅샷 갱신 0 |

향후 검증에는 구형 데이터 디코딩, 공통 설정 미확정 계정, 복수 기기 동시 저장, 계정 전환, 오프라인/인증 만료, 콘텐츠만 저장, 세션 불변성, 규칙 권한, 반복 이관·부분 실패 복구가 필요하다. 이전 테스트 통과 결과를 이번 제안의 검증으로 간주하지 않는다.

목록의 전체 상세 예열 최적화는 별도 후속 작업으로 분리한다. 현재의 오프라인 사용 경험과 검색·예약 기능을 바꾸므로, 설정 정리와 한 번에 엮지 않는 편이 원인 확인과 롤백에 유리하다.

## 권장 작업 묶음

1. **우선 적용**: 콘텐츠/설정/재생 타입과 직렬화 분리, 설정 조회 공유, 선택적 캐시 갱신, 저장 결과 URL 반영.
2. **DB 전환**: 새 설정 문서·규칙·버전 관리, 사전 조사와 이관 도구, 구버전 전환 정책, 구형 필드 정리.
3. **측정 후 적용**: 목록 조회와 오프라인 예열 최적화, 이미지 참조 기반 정리.

## 근거 소스

- `lib/src/app/feature/workouts/domain/usecases/workout_actions.dart`
- `lib/src/app/feature/workouts/data/models/workout_model.dart`
- `lib/src/app/feature/workouts/data/datasources/workout_preferences_data_source.dart`
- `lib/src/app/feature/workouts/data/datasources/countdown_defaults_data_source.dart`
- `lib/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart`
- `lib/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart`
- `lib/src/app/feature/workouts/data/repositories/workout_repository_impl.dart`
- `lib/src/app/feature/workouts/presentation/controllers/workout_preferences_controller.dart`
- `lib/src/app/feature/workouts/presentation/views/workout_editor_screen.dart`
- `lib/src/app/feature/operations/presentation/widgets/account_workout_settings_tab.dart`
- `lib/src/app/feature/playback/domain/usecases/playback_actions.dart`
- `lib/src/app/feature/playback/data/models/playback_session_model.dart`
- `lib/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart`
- `firestore.rules`, `functions/src/index.js`

Firestore는 문서 내부 필드와 하위 컬렉션을 모두 지원한다. 여기서 문서 분리는 성능 보장보다 책임 분리를 위한 선택이다. [공식 데이터 구조 안내](https://firebase.google.com/docs/firestore/manage-data/structure-data)

동시 수정 처리에는 트랜잭션 재시도를 고려해야 하며, 업로드 같은 외부 부수 효과를 트랜잭션 함수에 넣지 않는다. [공식 트랜잭션 안내](https://firebase.google.com/docs/firestore/manage-data/transactions)

읽기 비용은 문서 읽기 및 쿼리/리스너 등의 조건을 따른다. 예상 호출 수만으로 비용 절감률을 제시하지 않는다. [공식 과금 안내](https://firebase.google.com/docs/firestore/pricing)
