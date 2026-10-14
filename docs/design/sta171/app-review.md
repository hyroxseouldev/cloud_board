# STA-171 · 앱 문의 접수 검토

문의는 앱 내에서 작성하고 서버 접수 번호를 받은 뒤에만 완료로 표시한다. 더보기의 도움말·프로필 설정과 오류 안내의 `문제 문의하기`에서 같은 폼을 사용한다. 수업 중 문의 경로는 기존 `ActiveClassShell` 내부에 추가해 플레이어 소유 범위를 유지한다. Android TV와 표시 모드에서는 긴 문의 폼 대신 연결된 휴대폰/웹 이용 안내를 제공한다.

## 입력과 실제 상태

- 발생 상황 1–4000자, 답변 이메일, 선택 스크린샷 1장(PNG/JPEG/WebP, 최대 5MiB).
- 첨부를 선택한 후 실제 이미지를 확인하고 제거할 수 있다. 갤러리 파일명·로컬 경로는 서버에 보내지 않는다.
- 접수 진행 중에는 입력·첨부·중복 전송을 비활성화한다. 접수 실패 시 메시지·이메일·첨부·진단 스냅샷과 요청 ID를 그대로 유지한다.
- 서버가 티켓 ID·문의 번호·접수 시각·허용된 알림 상태를 모두 반환해야 완료 화면을 표시한다. `queued`와 `retrying`은 문의 저장 완료/알림 확인 중으로 구분하고, 이메일 수신 완료나 무한 자동 재시도를 주장하지 않는다.
- 알림 상태 재확인은 동일 요청 ID와 동일 본문을 사용한다. 내용 수정이나 새 문의 작성에는 새 요청 ID를 발급한다.
- 같은 계정의 화면 이동 중 초안은 메모리에 유지한다. 로그아웃·계정 변경은 초안을 지우며 진행 중 요청의 늦은 응답도 새 계정에 표시하지 않는다. 아직 접수하지 않은 입력을 디스크에 기록하지 않으며 앱 종료 시 사라질 수 있음을 안내한다.
- 로그인/온보딩 장애에서도 `/support` 안내 경로를 열 수 있다. 미로그인 사용자는 서버 작성 폼 대신 로그인 및 기존 지원 이메일 안내를 보며 익명 TV 접수는 데이터 계층과 서버가 차단한다.

## 진단 최소 수집

기존 `ErrorReporter`의 실제 이벤트 ID·발생 시각·작업 및 허용된 기술 참조만 추출한다. 새 오류 이벤트가 필요한 경우 같은 수집 경로로 기록하며 원본 오류 문자열·스택·토큰·URL·임의 provider 상태를 문의에 첨부하지 않는다. 진단 경로의 이벤트 ID는 운영자의 기존 오류 로그 검색 참조다.

앱 버전/build는 `PackageInfo` 또는 기존 진단 초기화 결과에서 읽는다. 없거나 `unknown`인 값은 전송하지 않고 화면에 `미확인`으로 표시한다. 연결된 TV 최대 10대의 실제 ID·설치 버전·온라인/연결 값과 확보한 최근 준비 응답(status/revision/checkedAtMs/imageCount/audioReady)을 함께 보여준다. 과거 준비 응답은 시각을 표시하며 현재 준비 완료라고 해석하지 않는다. 계정 소유권 전환 중이거나 기기 스트림이 로딩/오류 상태이면 이전 계정의 TV 진단을 재사용하지 않는다.

## 서버 계약

[서버 권한·메일 운영 문서](../../support-tickets.md)와 함께 검토한다.

1. 선택 첨부: `cloudboardPrepareSupportAttachment(accountId, requestId, fileId, contentType, sizeBytes, sha256)`으로 업로드 허가를 얻는다.
2. 반환 경로가 `users/{uid}/support/{requestId}/{fileId}`와 일치할 때만 업로드한다. 응답이 유실된 업로드는 기존 객체의 크기·타입·SHA256 메타데이터를 확인해 재사용한다.
3. `cloudboardSubmitSupportTicket({accountId, requestId, message, replyEmail, diagnostics, attachments:[{path}]})`를 호출한다. 첨부 없는 문의는 이 호출만 수행한다.
4. `{ticketId, ticketNumber, receivedAtMs, notificationStatus: queued|sent|retrying}`만 성공 응답으로 취급한다. 원격 문의 문서에 클라이언트가 직접 쓰지 않는다.

## 자동 검증과 캡처

- VM: 신규 문의 단위/위젯 테스트와 오류 수집·라우터·계정 관리·관리 여정·디스플레이·복구 회귀 62개 통과.
- 신규 케이스: 일반 문의, 스크린샷 미리보기·취소·제한, 입력 보존, 저장 실패/재시도, 중복 탭, 알림 상태 재확인, 누락된 접수 응답 거부, 실제 오류 ID 연결, 계정 전환/동일 UID 재로그인 경합, 360px·2배 글자.
- Chrome: 신규 문의·오류 수집·라우터 16개 통과.
- 최종 UI·캡처: 신규 11개 + 캡처 4개, 총 15개 통과. `flutter analyze`: No issues found.
- 최종 생성기를 실행했으며 `git diff --check`도 통과했다.

| 실제 위젯 캡처 | 상태 |
| --- | --- |
| [모바일 작성](screenshots/form-mobile.png) | 390×844, 입력 내용·이메일·진단 연결 |
| [선택 첨부](screenshots/attachment-mobile.png) | 390×844, 이미지 미리보기·제거 |
| [실패·재시도](screenshots/retry-mobile.png) | 390×844, 작성 내용 유지·동일 요청 재확인 |
| [데스크톱 접수 완료](screenshots/received-desktop.png) | 1280×900, 문의 번호·알림 확인 중 |

PNG는 논리 크기의 2배 해상도로 렌더링했다.

캡처는 실제 제품 위젯과 테스트 전송 계층을 사용한다. 예시 이메일·TV·오류 ID·문의 번호를 사용하며 실제 문의나 이메일을 보내지 않는다. 첨부 미리보기에는 기존 STA-164 UI 테스트 캡처를 예시로 사용했다. 실기기 실행, 운영 배포, 운영자 수신함 도착 확인은 이번 검증에 포함하지 않았다.

재현:

```sh
flutter test test/support_ticket_test.dart test/support_screen_test.dart test/error_reporter_test.dart test/auth_router_test.dart test/account_management_section_test.dart test/management_journey_ui_test.dart test/display_settings_test.dart test/playback_recovery_test.dart
flutter test --platform chrome test/support_ticket_test.dart test/support_screen_test.dart test/error_reporter_test.dart test/auth_router_test.dart
flutter test tool/sta171_capture_test.dart
flutter analyze
```
