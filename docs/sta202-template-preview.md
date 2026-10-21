# STA-202 템플릿 생성·미리보기 계약

## 범위와 인벤토리

새 슬라이드 생성에서 `creationTypography: true`를 사용한다. 확정한 일반/기본 슬라이드는 기존 문자열 필드의 `stationd-v3-*` / `studio-v2-*` ID로 고정 typography를 보존한다. 원문·스타일·fingerprint를 남겨 새 앱에서 다시 편집할 수 있으며 저장된 구 ID의 기본 렌더링과 fingerprint version은 변경하지 않는다. 기존 수업의 PNG를 자동으로 만들거나 바꾸지 않는다.

| 분류 | 템플릿 / 연결 샘플 | 새 생성 처리 |
| --- | --- | --- |
| 기본 12종 | 밝은 번호 보드, 어두운 집중 보드, 클래스 포스터, 섹션 카드 보드, 미니멀 화이트, 오렌지 스피드, 블루 나이트, 코랄 서킷, 네온 스테이션, 라벤더 플로우, 크림 클래식, 레드 임팩트 | `aiSlideDesignCatalog`와 `aiSlideDesignSample`; 목록·내용 편집·레이아웃 선택 카드·확대·최종 출력에 같은 모드 |
| 일반 3종 | stationd-v2-numbered / list / interval | 같은 생성 renderer의 역할별 고정 크기 지원; 기존 수업 편집·재생 기본 동작 보존 |
| 원본 7종 | STATION D MON(UNBROKEN), TUE(STRENGTH), WED(MAX), THU(SWEAT), FRI(HYROX 싱글), SAT(HYROX 팀), 돌파 Brick | 기존 7개 원본 자산 그대로; 변경한 슬롯만 고정 글씨로 그리며 넘침 차단 |
| 센터 8종 후보 | 위 원본 7종 + 승인 SWEATMONDAY Team of 3 | 로컬 exporter에서 정확한 원본 배치·번호·배지·서체 픽셀·색상·여백을 복원한 private recipe/PNG/thumbnail 생성 |
| 예시 수업·저장된 수업 | 기존 starter 및 저장된 이미지/디자인 수업 | 타이머·길이·저장본을 변경하거나 일괄 재생성하지 않음 |

1920×1080 기준 일반 새 생성은 제목 64(포스터 76), 부제 38, 보조 분류 32, 본문 48(카드 42), 일반 목록 제목 64/본문 48이다. 제목·분류·부제 슬롯과 카드 높이를 예약해 내용 삭제로 글씨가 확대되거나 몸통 위치가 올라오지 않는다. 기본 12종 본문 weight는 600, 제목은 700이고 기존 가족별 leading·간격·색상·장식은 별개로 유지한다. UNBROKEN은 동일 캔버스에서 약 53px 본문 원본을 비교 기준으로 쓴다. 실제 가독성/TV 확인 전의 구현값이며 검증된 개선율을 주장하지 않는다.

센터 v2는 카탈로그 샘플에서 선택한 열 수를 draft/theme에 보관한다. 본문은 같은 열과 글자 크기에서 자연 줄바꿈하며 자동으로 열을 재선택하거나 폰트를 줄이지 않는다. ‘본문 자동 맞춤’만 명시적으로 크기를 줄일 수 있고 기존 편집 undo history로 되돌린다. v1 원본 슬롯은 넘치면 축약/분할을 안내한다. 입력 문구를 잘라 저장하지 않는다.

## 원본과 최신 로고

7개 원본은 `assets/slide_templates/*_original.png`, 측정 영역은 `original_slide_template.dart`와 기존 reference cases를 사용한다. 이전 run15 v2 backgrounds는 비교 기준이 아니다.

SWEAT 원본과 최신 가로 심볼·SWEATMONDAY·EST.2026 로고 사용본은 운영자 입력 파일로만 받는다. 공용 assets에 포함하지 않는다. 로고 사용본(1672×941)의 source rect `(535,300,615,265)`만 비율 유지 합성하며 아래 대기 안내는 포함하지 않는다. 옛 원본의 세로 심볼 영역은 원본의 빈 크림 배경으로 교체한다. 운동명/횟수와 A/B/C 배지·오른쪽 여백은 원본 기준이다. 변경하지 않은 원본 글자는 원본 픽셀을 유지하며, 편집된 글자는 번들 서체(Pretendard/RacingSansOne/NotoSerifKR)를 사용하므로 원본 미상 서체와의 완전 동일성을 주장하지 않는다.

Brick의 제목은 원본 서예와 겹치는 평면 이미지여서 원본 픽셀을 보존하며 수업 제목은 메타데이터로 유지한다.

## 이미지·권한·호환성

`recipe.thumbnail`은 optional `{path, sha256, revision, width, height}`이다. v1 catalog의 엄격한 최상위/entry 키 집합은 바꾸지 않는다. 기존 recipe reader는 이 선택 필드를 무시할 수 있고 새 앱은 누락 시 저비용 16:9 안내 타일을 보여 준다. 새 최상위 필드 때문에 구형 앱이 카탈로그를 버리는 경로를 피한다. body schema는 그대로 유지한다.

- PNG 경로는 기존 `center-templates/<center>/<template>/<hash>.png`만 허용한다. recipe revision과 thumbnail revision이 일치해야 한다.
- 썸네일은 최대 640×360, 1MiB이며 실제 해시·PNG 헤더·크기를 확인한다. 공개 다운로드 토큰/공용 디스크 캐시를 사용하지 않는다.
- 인증된 이미지 요청은 프로젝트/계정/센터/recipe revision/hash로 격리하고 동시 전송은 3개로 제한한다. 기존 서버 권한 TTL(6시간)을 유지한다.
- 인코딩 메모리 LRU는 20MiB, 디코딩 thumbnail LRU는 8개, TTL은 2분이다. 640×360 RGBA 8개 캐시 소유분은 약 7MiB이다. 화면이 소유한 clone은 별도로 해제된다. 편집 배경 decode는 1920px 폭 상한이다.
- 카탈로그 부분 변경은 바뀌거나 제거된 키만 버린다. 계정/센터 전환·권한 상실 시 모든 해당 private handle을 폐기한다. 정상 캐시 적중은 동기적으로 읽는다.
- skeleton은 고정 16:9의 정적 표현이라 모션 감소에서도 반복 애니메이션이 없다. 실패 재시도는 같은 영역에서 수행한다.
- 편집은 인증된 배경 한 번 decode + 공통 측정 layout의 직접 canvas이다. 입력/목록 조회에서 최종 PNG exporter를 호출하지 않는다. provider 수명과 선택한 draft가 이전 요청 결과를 차단한다.
- 최종 Add는 실제 서버 카탈로그에서 권한/정확한 recipe를 다시 확인한다. 동일 내용 최종 PNG의 기존 STA-189 결과/진행 요청 재사용을 유지한다. 실패한 권한 갱신은 이전 렌더 결과를 재사용하지 않는다.
- 센터 최종 슬라이드는 기존 일반 PNG 이미지 계약을 사용한다. 기본/일반 최종 슬라이드는 원문·스타일과 새 version ID를 보존하고 `showTitle/showBody=false`인 PNG도 함께 저장한다. 새 앱은 같은 고정 renderer로 재편집하고, 등록 구 소스 `a865307`/`1b646438`는 미지원 ID에서 `hasSlideDesign=false` → `WorkoutImage(imageSource)`로 표시한다. `family`나 original style만으로 디자인 ID를 우회 인식하지 않는다. 구버전의 신규 typography 직접 편집은 지원하지 않는다.
- 소스상 `workout-save.js`와 `slide-library.js`는 기존 문자열 `designTemplate`을 제한/삭제하지 않으며 구 DTO도 문자열을 보존한다. 새 저장 필드/스타일 키를 추가하지 않는다. 서버/TV 신규 renderer, minBuild 상향, 기존 fixture 삭제, 저장 수업 마이그레이션이 필요하지 않다. 실제 저장·구 기기 재생 검증은 미실행이다.

## 로컬 도구 (구현 후 실행 승인 때만)

`tool/center_slide_brand_catalog_export_test.dart`는 `CENTER_BRAND_INPUT`, `CENTER_BRAND_SWEAT_IMAGE`, `CENTER_BRAND_LOGO_IMAGE`, 새 `CENTER_BRAND_OUTPUT` 경로를 받는다. `CENTER_BRAND_EXPORT=1`일 때만 실행하며 catalog/backgrounds/previews/thumbnails와 두 PNG manifest, 원본 SHA를 로컬에 쓴다. catalog revision 및 각 recipe revision은 증가한다. 서버 접속/게시 없음.

`tool/sta202_capture_test.dart`는 `STA202_CAPTURE_OUTPUT`의 새 디렉터리에 기본12+일반3+원본7의 동일 1920×1080 before/after/final PNG와 실제 폰트 측정 목록을 쓴다. 기존 원본 골든 fixture는 교체하지 않는다.

등록 도구의 `--local-only --file <catalog> --center-id <id> --images <manifest> --thumbnails <manifest> --output <new canonical.json>` 경로는 credentials/services를 열지 않으며 `--apply`를 거부한다. 앱의 실제 parser/renderer로 로컬 검증하는 단계이므로 테스트 중지 지시 동안에는 이 명령도 실행하지 않는다. 일반 게시 경로는 PNG와 thumbnail을 모두 확인한 뒤 동일 catalog revision으로 게시하도록 준비됐지만 이번 작업에서 실행하지 않는다.

## 남은 경계

실제 private catalog 게시, 저장·재조회 callable E2E, 실제 TV/iPad/Android 가독성, 웹 스크롤·CPU·프레임·최대 메모리 측정은 별도이다. 실제 결과 없이 성능 개선율을 적지 않는다. Section 5는 실제 이미지 생성 endpoint와 별도 편집 경로를 구현했으며 [API·비용·로컬 검증 계약](sta202-ai-raster.md)을 따른다. 키 재사용은 승인되었지만 실제 API 호출·품질 샘플·배포 결과는 구현 상태와 구분한다.
