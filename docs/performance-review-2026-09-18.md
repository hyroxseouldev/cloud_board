# 앱 기능·성능·서버 최적화 분석 — 2026-09-18

현재 작업 트리의 Flutter, Firebase RTDB/Firestore/Storage, Cloud Functions, 기존 성능 문서를 검토했다. 서비스 로직 및 배포 설정은 수정하지 않았다. 실기기 프로파일과 운영 Firebase 사용량은 수집하지 않았으므로 아래 우선순위는 코드 구조에 근거하며 실제 지연·비용 절감률은 미측정이다.

## 판단

기존 클라이언트 최적화가 이미 적용되어 있다. 다음 단계의 효과는 예약 실행 안정성, 불필요한 조회 제거, 이미지 전송량 감소, 목록과 재생 데이터 구조 개선에서 기대된다. 현재 근거만으로 서버 증설이나 백엔드 교체를 권할 이유는 없다. 일반 재생 경로는 클라이언트가 Firebase에 직접 연결하며 functions/src/index.js의 함수들은 계정 삭제와 재시도에 쓰인다.

## 유지해야 하는 기존 개선

- 서버 기준 시각을 이용한 기기 내 타이머 계산과 자연스러운 단계 전환. 100ms 타이머는 서버에 100ms마다 쓰는 로직이 아니다.
- `select`를 이용한 재생 본문과 타이머 갱신 분리, 이미지 크기에 맞춘 디코딩, Base64 바이트 캐시, 네이티브 디스크 캐시.
- 최대 3개 병렬 이미지 준비와 현재/다음 두 슬라이드의 이미지 선행 로딩.
- 최초 프레임 후 초기화, 캐시 우선 목록 표시, 원격 재생 상태 전달과 로컬 체크포인트 저장 분리.
- 명령의 세션 ID·revision·만료 시각 검사. 통신량을 줄이더라도 이 동시성 보호는 유지해야 한다.

## 우선순위별 개선

### 1. 예약 실행권 선점 후 실패 복구 — 최우선, 정확성

근거: `lib/src/app/feature/operations/presentation/controllers/store_operations_controller.dart:127`, `lib/src/app/feature/operations/data/datasources/store_operations_realtime_data_source.dart:88`.

`claimOccurrence`가 lastOccurrenceKey를 먼저 기록하고 start를 호출한다. 그 이후 실패하면 다음 실행에서 동일 키를 거절해 같은 회차 재시도가 막힐 수 있다. 반대로 키를 무조건 지우는 방식은 서버에서 시작에 성공했지만 응답만 유실된 경우 중복 실행을 일으킨다.

개선: 회차별 작업에 pending/starting/started/failed, 만료 가능한 lease, 고정 sessionId를 두고 멱등적으로 실행한다. 재시도 전에 실제 세션을 조회해 성공 여부를 조정한다. 동시 컨트롤러의 서로 다른 예약도 activeSession을 덮어쓰지 않도록 시작 충돌 정책을 둔다.

검증: 선점 직후 종료, 서버 반영 후 응답 유실, 동시 컨트롤러, 수동 시작과 예약 충돌, 동일 회차 재시도.

### 2. 예약 확인의 불필요한 서버 조회 제거 — 최우선, 작은 변경

근거: `lib/src/app/feature/device/presentation/views/device_mode_home_screen.dart:41`, `lib/src/app/feature/operations/presentation/controllers/store_operations_controller.dart:102`, `lib/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart:63`.

홈의 컨트롤러 모드에서 20초마다 runDue를 호출한다. 실행 대상 예약을 검사하기 전에 activeSession.get()을 수행한다. 따라서 예약이 없어도 타이머가 계속 실행되는 조건에서는 한 시간에 약 180회의 조회 호출이 생긴다. 이는 RTDB 호출 수 계산이며 Firestore 문서 읽기 과금이나 실제 다운로드 바이트를 의미하지 않는다.

개선: 로컬 예약 목록에서 실행 후보를 먼저 판단하고, 후보가 있을 때만 최신 세션을 확인한다. 이미 구독하는 세션은 빠른 사전 판단에 활용하되 실행 직전 서버 동시성 검증을 유지한다. 다음 예약 시각에 맞춘 타이머와 앱 복귀 시 재검사를 조합한다.

기능 한계: 예약 실행기는 현재 홈 화면에 달려 있다. 앱이 종료되거나 OS가 실행을 중단한 상태의 무인 예약을 보장하지 않는다. 무인 운영을 제공하려면 서버 실행기로 회차 생성을 옮기고, 매장 시간대·예약 수정/취소·중복 방지·오프라인 TV 처리까지 정의해야 한다.

### 3. 원본 이미지와 편집 임시저장 경량화 — 체감 속도 우선

근거: `lib/src/app/feature/workouts/presentation/views/slide_editor_screen.dart:370`, `lib/src/app/feature/workouts/data/datasources/workout_storage_data_source.dart:14`, `lib/src/app/feature/workouts/data/repositories/slide_editor_repository_impl.dart:25`, `lib/src/app/feature/workouts/presentation/controllers/slide_editor_controller.dart:127`.

슬라이드 이미지는 선택 시 해상도/품질 제한 없이 읽고 Base64 문자열로 보관한다. 이미지가 포함된 모듈 JSON을 450ms 디바운스 임시저장으로 SharedPreferences에 쓴다. 이미지가 바뀌지 않은 텍스트 편집에도 큰 문자열 직렬화/저장이 포함될 수 있다. 신규 모듈 이미지는 한 장씩 순차 업로드한다. 표시용 ResizeImage는 디코딩 크기를 줄이지만 업로드 원본이나 최초 다운로드 파일 크기를 줄이지 않는다.

개선:
- 이미지 입력 공통 처리: 표시 목적에 맞는 해상도·품질과 바이트 제한. 1080p/4K 품질 선택은 실제 화면으로 검증한다. 투명 PNG와 GIF 애니메이션은 별도 정책이 필요하다.
- 편집 중 이미지 바이트는 파일/Blob 저장소에 보관하고 draft에는 참조만 기록한다. 웹과 네이티브 저장 구현은 분리한다.
- 저장 시 동시 업로드 2~3개로 제한하고 순서 보존, 해시 기반 중복 제거, 진행률, 실패한 파일 재시도를 추가한다.
- 서버에서 썸네일/표시용 파일을 만들면 변환 처리 비용도 함께 측정한다.

검증: 이미지 다수의 수업 저장 시간, 편집 중 UI 프레임, peak 메모리, 네트워크 업로드/다운로드 바이트.

### 4. TV 준비 완료 확인과 이미지 선행 로딩 범위 — 기능·메모리 개선

근거: `lib/src/app/feature/workouts/presentation/widgets/workout_preflight_dialog.dart:54`, `lib/src/app/feature/playback/presentation/views/display_mode_screen.dart:158`, 같은 파일 `:187`, `lib/src/app/feature/workouts/presentation/views/workout_player_screen.dart:290`.

수업 준비 화면은 컨트롤러에서 전체 모듈 이미지 로딩을 기다린다. TV는 별도로 전체 이미지를 준비하고, 플레이어도 현재부터 3장을 준비한다. SDK 캐시가 중복 다운로드를 줄일 수 있지만 중복 작업과 큰 이미지의 디코드/퇴출 비용은 남을 수 있다. TV의 acknowledgedRevision은 이미지 준비 완료를 기다리지 않고 기록하므로 수신 확인과 실제 재생 준비는 다르다. 준비 대상 목록에 카운트다운 이미지는 포함되어 있지 않다.

개선: TV별 received/preparing/ready/error를 분리한다. 세션 버전과 필요한 자산 목록을 기준으로 준비 결과를 보고하고, 첫 화면·카운트다운·다음 슬라이드를 우선 준비한다. 나머지는 제한된 작업 큐로 내려받고 디코딩은 작은 범위로 유지한다. 완전 오프라인 재생을 약속하려면 전체 파일을 디스크에 고정 보관하는 별도 정책을 둔다. 준비 미완료 TV를 기다릴지 제외할지도 사용자가 확인할 수 있게 한다.

### 5. 운동 목록을 요약과 상세로 분리 — 데이터 증가 시 우선

근거: `lib/src/app/feature/workouts/data/datasources/workout_firestore_data_source.dart:26`, `lib/src/app/feature/workouts/data/repositories/workout_repository_impl.dart:36`.

24개씩 가져오지만 while 루프로 마지막 페이지까지 자동 조회한다. 문서에 모든 modules가 들어 있으므로 목록 표시에도 전체 운동 상세를 읽는다. 페이지마다 누적 items를 다시 병합·정렬하는 비용도 생긴다. 캐시 표시와 CUD의 로컬 반영은 이미 구현되어 있어 매번 화면을 열거나 저장할 때 모두 다시 읽는다고 해석해서는 안 된다.

개선: 이름·폴더·썸네일·총시간·수정 시각만 담은 요약 문서로 목록을 구성하고 상세는 진입/재생/해당 예약에서 조회한다. 초기 24개 이후 스크롤 요청 시 추가 로딩한다. 전체 검색과 폴더 개수, 예약 조회가 현재 전체 목록에 의존하므로 함께 바꿔야 한다. 요약과 상세 저장은 batch 등으로 일관성을 유지한다.

이 효과는 목록 최초 표시뿐 아니라 전체 로딩 완료 시간, 읽은 문서 수, 수신 바이트를 별도로 측정한다. 같은 문서를 작게 만드는 것만으로 문서 읽기 횟수가 줄지는 않는다.

### 6. 재생 스냅샷과 제어 상태 분리 — 중간 규모 구조 변경

근거: `lib/src/app/feature/playback/data/datasources/playback_realtime_data_source.dart:47,136`.

현재 activeSession에는 불변 workoutSnapshot과 작은 가변 재생 상태가 함께 있고 명령은 부모 노드 전체를 트랜잭션한다. 앱의 변환 캐시는 이미 있지만 서버 트랜잭션 범위는 전체 스냅샷을 포함한다.

개선: 버전이 고정된 수업 스냅샷과 상태 노드를 나누어 작은 상태만 트랜잭션한다. 클라이언트는 스냅샷을 받은 뒤 해당 버전의 상태만 적용한다. ID/revision/명령 만료 및 원자적 시작을 보존한다.

호환성: Android 알림, iOS ClassControls, 보안 규칙, 로컬 복구, 계정 삭제 코드도 기존 activeSession을 참조한다. Flutter 한 곳만 바꾸면 안 된다. 구버전 클라이언트 호환 전략이 필요하다. RTDB의 이벤트 스냅샷 크기와 실제 wire 전송량은 같다고 단정하지 않고 profiler로 확인한다.

### 7. TV 구독을 자기 기기로 제한 — 디스플레이 수 증가 시

근거: `lib/src/app/feature/device/data/datasources/device_pairing_realtime_data_source.dart:89,263`, `lib/src/app/feature/playback/presentation/views/display_mode_screen.dart:64`.

각 TV가 전체 devices를 구독하고 자기 기기를 찾는다. 각 TV의 명령 수신 확인 쓰기가 다른 TV의 전체 목록 변환/정렬도 유발한다. 기기 수가 늘면 불필요한 구독 알림 관계가 대략 D×D로 증가할 수 있다. 전체 데이터가 매번 wire로 재전송된다는 뜻은 아니다.

개선: 관리 컨트롤러는 전체 목록, TV는 devices/{deviceId}만 구독한다. 기기 1/3/10대에서 이벤트 수와 CPU를 비교한다.

### 8. 운영 통계·저장소의 장기 비용 관리

근거: `lib/src/app/feature/operations/data/datasources/store_operations_realtime_data_source.dart:53`, `lib/src/app/feature/operations/domain/operations_metrics.dart:3`, `lib/src/app/feature/workouts/data/repositories/workout_repository_impl.dart:113`, `firestore.indexes.json`.

- 운영 이벤트는 최근 1,000개만 받아 월간 통계를 계산한다. 이달 이벤트가 1,000개를 넘으면 통계가 누락될 수 있고, 접속 구간 경계도 잘릴 수 있다. 일별 집계+원본 이력 페이지를 분리하고 집계 재처리는 eventId로 중복을 막는다. 집계 비용과 원본 보관 기간을 정한다.
- 이미지 교체/운동 삭제 시 기존 파일을 보존한다. 복사본과 활성 재생이 같은 URL을 쓸 수 있어 안전한 현재 선택이지만 계정 삭제 전까지 미사용 파일이 누적될 수 있다. 워크아웃·카운트다운·템플릿·대기화면·재생 스냅샷 등의 참조를 확인하는 자산 관리와 유예 기간 있는 GC가 필요하다.
- 저장소의 Firestore 설정에는 fieldOverrides가 없다. 실제 배포 설정을 확인한 뒤 쿼리하지 않는 큰 modules 같은 필드의 인덱스 제외를 검토한다. updatedAt 등 실제 조회 필드는 유지한다. 인덱스 제외는 공식 권장 사항과 일치한다: https://firebase.google.com/docs/firestore/best-practices
- RTDB는 코드상 asia-southeast1, 계정 삭제 Functions는 asia-northeast3이다. 일반 재생은 해당 Functions를 통과하지 않으므로 함수 메모리 증설이나 minInstances 변경으로 재생 지연이 해결되지는 않는다. 리전은 측정과 데이터 이전 계획 없이 변경하지 않는다.

## 실행 순서와 측정

1. 기준선 계측과 예약 실패 복구, 예약 없을 때 조회 제거.
2. 이미지 입력/업로드/임시저장 개선, TV 준비 상태 표시.
3. 실제 운동 수가 많은 계정부터 요약 목록·상세 분리.
4. 명령 payload/지연과 기기 수 측정에 따라 RTDB 상태 분리·TV 단일 구독.
5. 운영 통계 집계, 자산 GC, Firestore 인덱스 정리.

측정 매트릭스: 운동 10/100/500개, 수업 이미지 5/30/100장, TV 1/3/10대. 이 숫자는 부하 시험 입력이며 운영 규모 추정치가 아니다. 캐시 없음/있음, 실기기 저사양 TV, 정상/저속/재연결 네트워크를 구분한다.

기록할 지표:
- 실행→사용 가능한 첫 화면, 목록 첫 24개/전체 완료 시간.
- 이미지 저장 및 수업 준비 완료 시간, TV별 준비 성공률.
- 명령→TV 수신과 실제 표시의 p50/p95, 시간 초과 및 중복 실행 수.
- 프레임 UI/raster 시간, peak 메모리, GC, 장시간 재생 후 메모리 추이.
- 매장별 RTDB 다운로드/연결/작업량, Firestore 읽기/쓰기, Storage 바이트·미참조 자산량.

Flutter 실기기 profile 측정 지침: https://docs.flutter.dev/perf/ui-performance
RTDB 구독 최적화와 사용량 측정: https://firebase.google.com/docs/database/usage/optimize
RTDB profiler: https://firebase.google.com/docs/database/usage/profile

## 이번 검증 결과

기존 테스트 7개 파일, 총 18개 테스트 통과: startup_performance, auth_startup_performance, player_rebuild_performance, workout_image_performance, workout_loading_performance, playback_delivery_performance, schedule_runner_initialization.

이 검증은 현재 구현의 일부 회귀 방지를 확인한다. 운영 부하·실기기 속도 측정이나 위 개선안 구현 완료를 뜻하지 않는다.
