# forwardClassOperation 제거 검증

- 요청: TIMO Firebase 복사 후 기존 외부 수업 이벤트 전송 함수 제거.
- 기준: `origin/develop`의 `d73cbee`에서 분리한 `chore/remove-class-operation-forwarder` 브랜치.
- 변경: `functions-monitoring` 패키지와 전용 Firebase 배포·에뮬레이터 설정 제거. 종료 문서와 AGENTS의 해당 경로 갱신.
- 검증 환경: macOS, Node.js 24.14.0, `npm ci --prefix functions --no-audit --no-fund`로 원본 lockfile의 의존성 설치.
- 검증 대상: 이 문서를 포함하는 커밋. 정확한 인계 SHA와 실행 SHA는 PR 본문에 기록한다.

## 실행 결과

| 확인 | 유형·명령 | 결과 | 외부 연결 |
| --- | --- | --- | --- |
| 함수의 실제 운영 상태 | Cloud Functions v1·v2 GET, `asia-southeast1/functions/forwardClassOperation` | 기존 운영·TIMO 모두 404. 함수는 확인 시점에 이미 없었음 | Google API 읽기 전용 |
| 기존 이벤트 기록·중복 방지·권한·할당량 | `node --test functions/test/operation-telemetry.test.js` | 6개 통과 | 없음. 저장소 mock 유닛 테스트 |
| 기존 앱·서버·규칙 보존 | `git diff --exit-code d73cbee -- lib functions functions-legacy firebase.json firebase.development.json database.rules.json firestore.rules storage.rules firestore.indexes.json` 및 원본 바이트 비교 | 895개 파일 동일 | 없음 |
| 재배포 경로 제거 | `test ! -e functions-monitoring && test ! -e firebase.monitoring.json && test ! -e firebase.monitoring.emulator.json` | 통과 | 없음 |
| 공백 오류 | `git diff --check` | 통과 | 없음 |

클라우드 확인 시각·대상·상태는 [JSON 증거](class-monitoring-cloud-status.json)에 기록했다.
최초 유닛 실행은 새 worktree의 의존성 미설치로 시작하지 못했다. 의존성 설치 후 동일 테스트가 6개 모두 통과했다.

## 범위와 한계

- 운영 함수 삭제 API를 실행하지 않았다. 이미 없는 함수를 새로 삭제했다고 보고하지 않는다.
- 기존 계정·수업 데이터와 이벤트 기록을 읽거나 수정하지 않았다. 함수 리소스 상태만 조회했다.
- 서버·웹·모바일 배포, 전체 CI, 앱 빌드, 실제 앱 저장·재생, 실제 수업 이벤트 수신 검증은 미실행. 일반 앱·서버·규칙 코드에 변경이 없어 이번 제거 범위에서 요구하지 않았다.
- 외부 전송 기능의 패키지 전체를 제거하므로 그 패키지 전용 테스트도 함께 제거했다. 유지되는 서버의 테스트나 기존 클라이언트 계약은 삭제하지 않았다.
- 과거 Git 커밋·태그, 기존 Secret Manager 비밀, 서비스 계정·IAM은 이번 작업에서 수정하지 않았다.
- PR은 `develop` 대상으로 인계한다. 소스 제거의 main 반영 및 병합 여부는 PR 상태와 구분한다. 워크플로 자체를 변경하거나 적용 완료로 주장하지 않는다.
