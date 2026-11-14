# TV 0대 수업 시작 복구 (2.2.1+13)

사용자의 2026-11-14 정정으로 이전 문서의 “0 TV/빈 선택은 Start 비활성” 가정을 폐기한다. 기준은 `origin/develop`의 `ba825941343591bbdb7516e319f95906293ad48c`다. 원본 dirty checkout, normalize2dirty, 버전, router/편집 화면, 서버·규칙·배포 설정은 변경하지 않는다.

등록 TV 0대와 전체 해제 모두 같은 준비 화면에서 최신 수업 설정·기기 목록·접근 확인·기존 serverConfirmed 수업 entitlement가 확인되면 Start를 활성화한다. 빈 workout, 접근/entitlement 거부·미확인, 준비 오류와 중복 제출은 계속 차단한다. 사용자에게 모드 선택이나 선택 적용을 요구하지 않는다.

빈 선택은 기존 `WorkoutPreflightSelection.localOnly` 및 목록/편집 caller의 `/player/:id` 경로로 연결한다. 이는 이미 존재하는 `sessionId == null` 플레이어의 로컬 타이머/제어 경로다. 새로운 서버 세션/방송 프로토콜을 만들지 않는다. Start 직전에 인증된 usage gate 읽기를 다시 수행하고 owner·entitlement·controller epoch를 확인한다. 로컬 수업도 기존 수업 이용 권한이 필요하며, TV가 없다는 quota/upgrade 조건은 추가하지 않는다.

준비 후보가 있으면 Start에서만 그 후보의 ID를 취소한다. nonenrolled는 기존 session-ID 조건부 `DisplayPreparationRepository.cancel`, enrolled는 기존 `cancelAdmission(admissionId)`를 사용한다. 후자는 같은 admission/session/epoch의 cancelled/expired 응답을 확인한 후 이동하며 active/committing/불명확 응답은 차단한다. 실패하면 준비 페이지에서 재시도할 수 있다. 다른 controller의 새 후보와 기존 active remote class를 종료하거나 변경하지 않는다. 서버 취소 outbox의 epoch/admission fence와 예약 반환 계약은 변경하지 않는다.

`prepare([])`, `commitSelected([])`, 원격 `start([])`는 호출하지 않는다. resolveManifest의 빈 배열=전체 TV, 기존 TV 수신기의 empty-target 방송 의미와 nonempty subset 검증을 그대로 보존한다. 1대 이상 선택하면 기존 C 전체 사전 확인, checkbox RPC0, 정확한 S 시작 경로가 그대로 실행된다.

세션 없는 컨트롤러에도 기존 on-demand 미리보기를 적용한다. 준비/카운트다운/닫힌 컨트롤러는 이미지 warmup/GET을 시작하지 않으며 명시적으로 미리보기를 열면 기존 이미지·managed preview lease/quota 경로를 사용한다. TV audience, legacy empty-target remote session, 별도 WorkoutRehearsalScreen/예시 화면의 렌더는 유지한다. 음향·로컬 타이머·슬라이드 제어 구현은 바꾸지 않는다.

## 검증 범위와 인계

Flutter 3.47.8, macOS VM 위젯/유닛 검사. production app router → 실제 WorkoutListScreen → 준비 → 실제 WorkoutPlayerScreen/PlayerController를 사용하고 외부 repository·플랫폼 오디오/잠금만 fake다. 시작·카운트다운·타이머 감소·일시정지/재개·종료 복귀를 확인한다. 미디어 HTTP client 생성 자체를 차단·계수하므로 준비/플레이어의 새로운 HTTP GET도 0이다. 홈의 기존 썸네일은 별도 범위이며 기존 remote class fixture는 이미지 없는 별도 snapshot을 사용한다.

| fixture | prepare | access reads | 자기 후보 cancel | remote repository calls | 준비/컨트롤러 media HTTP | 기존 active |
| --- | --- | --- | --- | --- | --- | --- |
| 등록 0대 | 0 | 2 | 0 | 0 | 0 | 동일 |
| 등록 2대, 전체 해제 | 1 | 2 | 1 | 0 | 0 | 동일 |

별도 enrolled fixture는 등록 0에서 admission prepare/cancel 0, 등록 1 전체 해제에서 prepare 1/cancel 1을 확인한다. 두 경우 localOnly=true이며 empty remote commit은 없다. 관련 기존 subset·start lifecycle·player 이미지 안정성 검사를 재사용하고 필요한 실패 검사를 포함한다.

증거 루트: `/Users/sunmkim/CloudBoard-release-artifacts/2.2.1-zero-target-hotfix`. `local-fixture-{0,2}-tv-start-enabled.png`, `local-fixture-{0,2}-tv-timer-controls.png`는 390×844 위젯 fixture 캡처이며 실제 SDK/실기기 증거가 아니다. 일부 아이콘 글꼴은 위젯 테스트 환경의 대체 모양이다. 정확한 검사 커밋·명령·결과는 PR 인계와 증거 루트 REPORT.md에 기록한다.

실제 Firebase callable/취소 예약 반환·실기기 오디오·실제 TV/서버·시뮬레이터·TestFlight: 미실행/미확인. 앱 저장 흐름은 변경하지 않았다. 백엔드 추가 배포 필요 없음; 기존 서버의 cancel 계약을 사용한다. 전체 CI·native build·업로드·merge·tag는 실행하지 않았으며 root가 검토한 고정 SHA로 Dev TestFlight 교체를 담당한다. 앱 소스 표시 버전은 2.2.1+13이며 실제 ASC 빌드 번호는 후속 업로드에서 별도 배정한다.
