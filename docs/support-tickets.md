# STA-171 문의 접수와 운영자 알림

앱 문의는 Firestore에 먼저 저장됩니다. 메일 발송 여부와 접수 성공은 별개입니다. 이번 변경은 서버·규칙·앱과 로컬 검증을 포함하며 실제 환경 배포, 메일 Secret/발신 도메인 설정, 실제 받은편지함 검증은 수행하지 않았습니다.

## 저장·재시도 계약

`cloudboardSubmitSupportTicket`은 로그인한 일반 계정만 호출할 수 있습니다. payload의 `accountId`가 인증 UID와 정확히 같아야 하므로 업로드/토큰 취득 사이 계정 전환도 이전 초안을 다른 계정으로 접수시키지 않습니다. 휴대전화 인증/유료 플랜은 문의의 전제 조건이 아닙니다. 익명 TV는 연결된 휴대폰·웹의 문의에서 진단을 포함합니다.

```json
{
  "accountId": "signed-in-uid",
  "requestId": "stable-client-request-id",
  "message": "발생 상황 (최대 4000자)",
  "replyEmail": "reply@example.test",
  "diagnostics": {"errorId": "error-event-id", "action": "playback.start"},
  "attachments": [{"path": "users/signed-in-uid/support/stable-client-request-id/screenshot-id"}]
}
```

첨부가 없으면 `attachments: []`입니다. 서버는 `{ticketId, ticketNumber, receivedAtMs, notificationStatus, duplicate}`를 반환합니다. `ticketNumber`는 `CB-`와 서버 해시로 구성한 문자열입니다. 상태는 `queued`(접수됨), `sent`(메일 제공자 접수 응답 확인), `retrying`(알림 설정/발송 재확인 필요)입니다. **`sent`는 받은편지함 도착을 뜻하지 않습니다.**

- `users/{uid}/supportTickets/{requestId}`에 본문·답장 주소·허용된 진단·첨부 참조를 저장합니다.
- 같은 transaction에서 서버 전용 `supportNotificationOutbox/{sha256(uid/requestId)}`를 만듭니다. 접수 저장 실패 시 알림 작업도 생성되지 않습니다.
- 같은 소유자·요청 ID·정규화 payload 재시도는 같은 문의 번호와 최신 알림 상태를 반환하며 횟수에 추가하지 않습니다. 같은 ID에 다른 입력을 보내면 `already-exists`입니다.
- 문의 접수는 계정별 1시간 5회/24시간 20회입니다. 업로드 허가에도 별도로 같은 제한을 둡니다. 임의 요청 ID로 문의 전 파일만 무한 업로드하는 우회를 막습니다.
- 입력 수정 시 앱은 새 요청 ID를 만들고, 불확실한 응답의 재시도는 기존 payload/ID를 유지합니다.

## 스크린샷과 개인정보 경계

`cloudboardPrepareSupportAttachment({accountId, requestId, fileId, contentType, sizeBytes, sha256}) -> {path}`가 15분 업로드 허가를 발급합니다. 파일은 한 장, PNG/JPEG/WebP, 최대 5MiB입니다. 서버는 `users/{uid}/supportUploads/{requestId}`에 정확한 경로·MIME·크기·SHA-256을 보관합니다.

Storage는 본인에게 허용된 새 객체 생성만 허용합니다. 다른 경로, 크기/타입/해시 메타데이터 불일치, 덮어쓰기·삭제는 차단합니다. 본인의 없는 파일 metadata 조회는 object-not-found가 되어 응답 유실 후 앱이 기존 파일을 재사용할 수 있습니다. 접수 서버는 실제 바이트 해시와 이미지 magic bytes도 확인하고 bearer download token을 제거합니다. 메일에는 공개 다운로드 URL을 넣지 않습니다. 앱이 제출한 SHA 메타데이터는 보존하므로 첨부 있는 접수의 상태 재확인도 멱등입니다.

문의/첨부 읽기는 본인 또는 Admin이 부여한 `supportOperator: true` 사용자만 가능하며 직접 쓰기는 금지됩니다. outbox·rate·permit·메일 설정은 앱에서 읽거나 쓸 수 없습니다. 메일의 Firebase Console 상세 링크는 별도 프로젝트 IAM 권한이 있는 운영자만 열 수 있습니다. 운영자 custom claim만으로 Console IAM이 생기지는 않습니다.

서버 진단 allowlist는 `support-tickets.js`의 `keys`/`tvKeys`이며 앱의 `support_ticket.dart`와 맞춥니다. 오류 ID·시각·버전·빌드·명시적인 작업/수업 단계 및 확보된 TV 상태만 저장합니다. `operationId`, `startStage`, `preparationStage`도 보존합니다. 원시 오류·스택·breadcrumb·토큰·URL·이메일·전화·센터명 등은 진단에서 제외/치환합니다. 본문/답장 주소는 사용자가 직접 제출한 문의 내용으로 별도 보존합니다. TV는 최대 10개이며 `users/{uid}/devices/{deviceId}`에 실제 소유 기록이 있어야 합니다. 상태는 관찰 당시 값이며 현재 준비 완료로 추정하지 않습니다.

기존 `reportClientDiagnostic`의 Cloud Logging marker `client_diagnostic`, `accountHash=sha256(uid)[0:16]`, `eventId`와 동일한 필터를 메일 검색 링크에 사용합니다. 단위/통합 테스트는 동일 hash·eventId 연결을 확인합니다. 실제 운영 오류 로그가 수집되어 검색되는지, 운영자 IAM에서 링크가 열리는지는 배포 후 확인 항목입니다.

## 알림 발송과 중복 방지

Firestore 생성 trigger와 5분 scheduler가 같은 transaction lease를 사용합니다. 한 작업은 2분 lease를 획득하고 20초 HTTP timeout으로 Resend에 요청합니다. 최초 발송 전에 **메일 envelope와 제공자 idempotency key를 영속화**하고 재시도 시 그대로 사용합니다. 따라서 제공자가 수락한 뒤 응답이 유실되거나 Firestore 상태 갱신이 실패해도 동일 메일 재요청입니다. 서버 설정 변경으로 재시도 본문/키가 바뀌지 않습니다.

1분부터 최대 6시간 간격의 backoff, 최대 8회이며 한 scheduler는 최대 20건을 순차 처리합니다(HTTP 최악 400초, 함수 540초 제한에 DB 여유 확보). 설정이 없을 때는 문의를 보존하고 15분 후 다시 확인하며 제공자 시도 횟수를 소비하지 않습니다. 이미 저장한 envelope도 설정 `enabled: false`로 추가 발송을 정지할 수 있습니다.

Resend의 idempotency key 보장 기간은 24시간입니다. 최초 외부 요청 후 23시간이 지났거나 최대 시도에 도달하면 outbox를 `needsReview`로 두고 자동 발송을 중단합니다. 불확실한 발송을 새 key로 임의 재전송하지 않습니다. 운영자는 제공자 기록을 원래 key/provider ID와 대조해 수신 여부를 확인한 뒤 필요 시 별도 응대합니다. [Resend idempotency 문서](https://resend.com/docs/dashboard/emails/idempotency-keys), [Send Email API](https://resend.com/docs/api-reference/emails/send-email).

## 설정과 배포 순서 (미실행)

예시 환경값: [support-email.env.example](examples/support-email.env.example). 기본은 모두 `false`입니다. 단순 함수 배포는 새 메일 Secret을 요구하거나 메일을 보내지 않습니다. 개발 환경에도 실제 발송은 기본 off이며 운영 키를 복사하지 않습니다.

1. Firestore/Storage 규칙과 `supportUploads.cleanupAtMs` collection-group index, 문의 callable 2개, 생성 trigger, retry/cleanup scheduler, 계정 삭제 정리를 같은 backend 릴리스에 포함합니다. 앱 출시는 backend 준비 후 진행합니다. 개발 deploy target에도 문의 함수 5개를 포함하며 기본은 접수·큐 보존만 실행합니다.
2. 실제 사용할 발신 도메인을 Resend에서 인증하고, 발신 주소와 API 키를 발급합니다. Secret Manager의 `SUPPORT_EMAIL_API_KEY`에 API 키를 보관하고 해당 runtime identity에만 접근을 부여합니다. 키/발신 도메인은 이번 작업에서 생성하지 않았습니다.
3. 배포 환경의 `SUPPORT_EMAIL_SECRETS_ENABLED=true`로 Secret binding을 명시적으로 활성화한 뒤 함수 metadata를 검증합니다. `SUPPORT_EMAIL_DELIVERY_ENABLED`는 실제 발송 승인 전까지 `false`로 둡니다.
4. Admin으로만 Firestore `supportConfig/email`을 준비합니다:

   ```json
   {"enabled": false, "provider": "resend", "recipientEmail": "vividxxxxx@gmail.com", "fromEmail": "VERIFIED_SENDER@YOUR_VERIFIED_DOMAIN"}
   ```

   수신자는 사용자가 확인한 `vividxxxxx@gmail.com`과 정확히 일치해야 합니다. 다른 수신자는 서버가 발송하지 않습니다. 수신자 변경은 별도 확인과 서버 승인값 변경이 필요합니다. 발신자는 인증된 도메인의 실제 주소로 설정합니다.
5. 운영자가 실제 테스트 발송을 승인한 뒤 runtime config `enabled: true` 및 deployment `SUPPORT_EMAIL_DELIVERY_ENABLED=true`를 활성화합니다. 기존 큐도 처리되므로 먼저 outbox 대상·수량을 확인합니다. 아무것도 설치/배포/발송하지 않은 현재 상태에서는 이 단계가 남아 있습니다.
6. Android/iOS/Web에서 작성→첨부 선택→접수 번호를 확인하고 실제 운영자 받은편지함의 수신·스팸함, 답장, 비공개 상세 링크를 확인합니다. `receivedAtMs`, 제공자 수락 시각/ID, **실제 수신 시각**을 별도 운영 기록에 남깁니다. 실기기·받은편지함 검증은 사용자 후속 작업입니다.

중단은 `supportConfig/email.enabled=false`로 새 발송을 정지하고 문의/큐를 보존합니다. 필요하면 배포 delivery flag도 끕니다. 기존 문의를 제거하거나 새 key로 재발송하는 rollback은 하지 않습니다.

## 계정 삭제와 정리

계정 삭제 lock은 접수/업로드/조회/메일 claim을 차단합니다. worker는 제공자 호출 직전 lock을 다시 확인합니다. 이미 시작된 외부 HTTP 요청과 삭제 사이 경합은 완전히 취소할 수 없으며, 이미 보낸 운영자 이메일은 계정 삭제로 회수되지 않습니다. 운영자의 이메일 보관/삭제 처리는 별도 관리 대상입니다.

기존 계정 삭제 절차에 outbox/rate 정리와 잔여 검증을 추가합니다. 기존 user recursive delete와 Storage 사용자 prefix 삭제가 문의·permit·첨부를 함께 제거합니다. 미접수 업로드는 24시간 후 정리 대상이 되고 매일 scheduler가 최대 100개를 처리합니다. 삭제 claim 후 새 제출/permit 갱신이 해당 객체를 재사용하지 못하도록 상태를 transaction으로 잠급니다. 접수된 첨부는 이 정리에서 제외되며 계정 삭제 때 제거됩니다.

## 자동 검증

- Node 22.23.3 전체 Functions 테스트: 184개 통과(신규 10개 포함).
- Firestore/RTDB/Storage demo emulator 8개 통합 그룹 통과: 실제 규칙 및 SDK를 사용해 동시 접수·변경 payload 충돌·계정 경계·소유 TV·첨부 permit·불변 파일·실제 바이트·요청/업로드 quota·provider lease·재시도·설정 누락·삭제 정리를 검증합니다. 메일 transport는 모두 fake이며 외부 발송은 없습니다.
- `tool/firebase/contract-suites.json`의 `support-tickets`는 CI 필수 suite입니다. `requires`에 Storage를 포함합니다. 공통 runner는 항상 Storage를 시작하고 rules를 로드/초기화하며 suite는 실제 업로드/읽기/거절을 assert합니다. `coverage`는 Firestore/RTDB의 ruleCoverage 산출물만 뜻합니다(Storage emulator는 이 export API가 없음).
- 앱 화면·작성/재시도·작은 화면 캡처는 [앱 검토](design/sta171/app-review.md)를 참고합니다. 실제 Firebase 운영 callable과 실기기, 실제 이메일 수신을 자동 테스트 결과로 대체하지 않습니다.
