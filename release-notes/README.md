# 앱 업데이트 소식

설정 → 업데이트 소식에서 현재 설치된 버전에 해당하는 요약과 이전 내역을 보여준다. 새 소식 점은 상세 페이지를 실제로 열었을 때 사라지며 읽은 상태는 계정별로 현재 기기에 보관한다. 일반 팝업이나 홈 배너는 사용하지 않는다.

## 작성과 게시

1. 사용자에게 알릴 변경이 있으면 `current.json`을 수정한다. 새로운 소식은 **새 id**를 사용하고, `version`은 `pubspec.yaml`의 버전과 맞춘다. 제목·요약·기능별 설명 1~5개만 작성한다. 날짜는 `YYYY-MM-DD`이다. 이미지·HTML·개발 로그·사용자 정보는 넣지 않는다.
2. 같은 릴리스에 대한 재배포라면 파일을 유지한다. 이미 게시된 id의 내용은 덮어쓰지 않는다. 수정 공지도 새 id로 추가한다.
3. main 배포 완료 후 `.github/workflows/app-update-news.yml`이 **배포된 커밋의 파일**을 읽어 앱 소식만 게시한다. GitHub의 실제 배포/업로드 성공 단계와 산출물에서 확인한 플랫폼별 빌드 번호만 Firestore `appContent/updateNews`에 연결한다. 모바일 산출물이 누락되거나 모호하면 해당 플랫폼 소식은 게시하지 않는다. 확인된 빌드가 하나도 없으면 게시 파일을 만들지 않는다.
4. 앱은 현재 실행 중인 플랫폼·버전·빌드가 조건을 만족하는 소식만 표시한다. iOS/TestFlight 업로드만으로 스토어에 출시되었다고 표시하지 않는다. 열린 웹 탭의 버전은 컴파일 시점 값으로 고정된다.

게시 작업은 플랫폼 완료 이벤트마다 같은 id에 조건을 합친다. 트랜잭션으로 중복·경합을 방지하고, 재실행이 기존 사용자의 소식을 숨기지 않도록 최초 호환 빌드를 보존한다. 공개 피드는 최근 100개를 보관하며 클라이언트 쓰기는 차단된다. 네트워크 오류 시 캐시가 있으면 그대로 보여준다.

소식은 앱에서만 제공하며, 배포할 때 Linear 프로젝트 활동 글을 자동으로 생성하거나 갱신하지 않는다. Linear 인증 정보는 필요 없다. 기존 프로젝트 활동 글을 삭제하지는 않는다.

## 자동화와 복구

`Publish app update news` 워크플로는 main의 웹 / Google Play / TestFlight 배포 워크플로 완료 이벤트를 받는다. 게시기가 각 SHA의 가장 최근 실행 및 실행 시도를 다시 조회하고 **실제 배포·업로드 단계**의 성공 여부를 확인한다. 빌드 성공만으로 게시하지 않으며, 이전 실행의 성공으로 새로운 실패를 덮지 않는다. 플랫폼별 빌드 번호는 기존 배포 산출물 이름에서 읽고 웹은 실행 번호·시도 번호를 사용한다.

Firebase 인증은 기존 GitHub `FIREBASE_SERVICE_ACCOUNT_CLOUD_BOARD_STATIOND`를 재사용하며, 게시할 파일이 있을 때만 인증하고 Firestore 게시기를 실행한다. 별도 AI 호출이나 관리자 화면은 필요 없다. 배포 커밋에 소식 파일이 없으면 게시를 건너뛴다.

게시 실패 시 GitHub에서 `Publish app update news`를 재실행하거나, main에서 수동 실행하며 `deployment_run_id`에 기존 main 배포 실행 ID를 입력한다. 앱을 다시 빌드하거나 배포하지 않고 최신 게시 코드로 해당 배포의 소식만 복구한다. 자동 실행과 수동 복구는 직렬 처리한다. 전환 중 이전 워크플로의 실행과도 직렬 처리되도록 concurrency group 이름 `linear-deployment-publisher`는 유지한다.

워크플로와 스크립트가 기본 브랜치 main에 있어야 `workflow_run`이 실행된다. PR/포크 배포는 게시 대상에서 제외하며, 수동 복구도 GitHub에서 조회한 실행의 저장소·브랜치·이벤트·워크플로를 재검증한다. 실행 코드는 신뢰할 수 있는 기본 브랜치에서만 체크아웃한다. GitHub Token은 배포 증거를 읽는 단계에만 전달하며 contents/actions 읽기 권한만 사용한다. 배포 워크플로 이름, 업로드 단계 이름, 산출물 이름을 바꿀 때는 `tool/update-news/publish.mjs`의 `pipelines` 설정도 함께 수정한다.

## 검증

```sh
node --test tool/update-news/*.test.mjs
fvm flutter test test/update_news_test.dart
```

실제 GitHub 실행의 `workflow_run` 페이로드를 `GITHUB_EVENT_PATH`에 제공하고 `GITHUB_EVENT_NAME=workflow_run`, `GITHUB_REPOSITORY`, `GITHUB_TOKEN`을 설정한다. `UPDATE_NEWS_DRY_RUN=true node tool/update-news/publish.mjs`로 실행하면 GitHub의 배포 증거를 읽어 결과를 확인할 수 있다. dry-run에서는 게시 파일을 쓰지 않으며 Firebase 인증도 필요 없다.

일반 실행은 `UPDATE_NEWS_OUTPUT_PATH`에 확인된 빌드가 포함된 JSON을 기록한다. 파일 검증은 `node functions/tools/publish-update-news.mjs <파일>`로 하고, 실제 Firestore 반영은 인증 후 `--apply` 옵션으로 실행한다. 스토어 심사·처리·설치 가능 여부는 이 자동화의 검증 범위가 아니므로 공개 배포 전에 별도로 확인한다.
