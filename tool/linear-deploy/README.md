# Linear 프로젝트 자동 업데이트

`.github/workflows/linear-project-update.yml`이 main의 웹 / Google Play / TestFlight 배포 워크플로 완료 이벤트를 받아 `cloudboard` 프로젝트에 업데이트 글을 남긴다. 별도 문서·이슈·댓글을 만들지 않는다.

## 동작

- 저장소·프로젝트·배포 커밋 SHA로 고정 UUID를 계산한다. 첫 결과에 글을 생성하고 다른 플랫폼 결과와 재실행 결과는 같은 글을 갱신한다.
- 배포 워크플로 목록과 **실제 업로드 단계**를 함께 확인한다. 빌드 성공/업로드 건너뜀을 배포 성공으로 쓰지 않는다. 실패·취소도 기록한다.
- 각 SHA의 가장 최근 실행 및 실행 시도만 사용한다. 이전 시도의 성공으로 새 실패를 덮지 않는다.
- Android는 비공개 Alpha 제출, iOS는 TestFlight 업로드로 표기한다. 스토어 심사·처리·설치 가능 상태는 이 액션의 검증 범위가 아니다.
- 버전은 배포 SHA의 pubspec에서, 빌드 번호는 기존 배포 산출물 이름에서 읽는다. 빌드 번호가 여러 개면 추측하지 않고 생략한다.
- 최근 main 배포 실행 100개 안에서 가장 가까운 이전 main 커밋을 기준으로 변경 커밋을 모은다. 첫 실행/기록이 없는 경우 첫 부모와 비교한다. 일반 develop→main merge의 변경 커밋을 포함한다. 기록이 100개 이상 벌어진 장기 재실행은 비교 범위가 좁아질 수 있다.
- 커밋 제목을 변경 요약으로 사용한다. 커밋 본문/merge 메시지의 `STA-숫자` 참조를 관련 이슈 링크로 연결한다. 커밋 메시지에 없는 기능 설명을 임의로 생성하지 않는다.
- 프로젝트 건강 상태나 이슈 상태, `테스트 필요` 라벨은 변경하지 않는다. 자동 글 본문은 갱신되므로 수동 검수 의견은 글의 댓글/기존 이슈에 작성한다.
- 실패한 기록 액션은 GitHub에서 재실행하면 된다. 생성 응답 유실 시에도 같은 UUID를 조회하며 새 글을 중복 생성하지 않는다. 기존 글을 보관 처리했다면 재생성하지 않고 실패로 알린다.

## 설정

- GitHub 저장소 Secret: `LINEAR_API_KEY`
- Linear 개인 키: `Cloudboard GitHub deployment updates`
- 권한: Write(읽기·쓰기 포함), 팀: Cloudboard만. Admin 제외.
- 프로젝트 ID: `00a512bb-598c-4967-b435-e78cadc4e8f2` (워크플로 환경 변수)
- 2026-09-18 브라우저에서 키 생성 및 Secret 등록 완료. 키 값은 소스에 저장하지 않았다.

워크플로와 스크립트가 기본 브랜치 main에 있어야 `workflow_run`이 실행된다. 배포 워크플로 이름, 업로드 단계 이름, 산출물 이름을 바꿀 때는 `pipelines` 설정도 함께 수정한다.

기록 액션은 별도 워크플로로 동작해 기록 실패 때문에 앱을 재배포하지 않는다. PR/포크 배포는 대상에서 제외하고, 실행 코드는 기본 브랜치에서만 체크아웃한다. GitHub Token은 contents/actions 읽기 권한만 사용한다. API 키는 글 게시 단계에만 전달한다.

## 검증

```sh
node --test tool/linear-deploy/*.test.mjs
```

실제 GitHub 실행의 `workflow_run` 페이로드를 `GITHUB_EVENT_PATH`에 제공하고 `LINEAR_DRY_RUN=true`로 실행하면 Linear 쓰기 없이 결과를 출력한다. `GITHUB_REPOSITORY`, `GITHUB_TOKEN`, `LINEAR_PROJECT_ID`도 필요하다. dry-run에는 Linear 키가 필요 없다.

- 회귀 테스트 10개: 소스 제한, 최신 실행 선택, 업로드 단계 확인, 단일 글 갱신·생성 응답 유실, API 오류, merge 및 다중 커밋 변경 범위.
- 실제 main `661b055`의 배포 실행을 read-only dry-run으로 조회: 웹 완료 / Android 빌드 32 제출 / iOS 빌드 526 업로드 확인.
- 실제 Linear 게시 및 GitHub 자동 실행은 main 반영 후 첫 실행에서 확인해야 한다. 이 설정 작업에서 과거 배포 글을 게시하거나 앱을 배포하지 않았다.

공식 참고: [프로젝트 업데이트](https://linear.app/docs/initiative-and-project-updates), [Linear GraphQL](https://linear.app/developers/graphql), [공식 API 스키마](https://github.com/linear/linear/blob/master/packages/sdk/src/schema.graphql), [GitHub workflow_run](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run).
