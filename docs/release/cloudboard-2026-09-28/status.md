# CloudBoard 출시 진행 — 2026-09-28

## 확정 순서
1. 현재 CloudBoard로 스토어 심사 진행
2. 새 브랜드 재선정 (Lumove 적용 보류)
3. 새 브랜드에 맞춘 리디자인 + 구독 시스템 개발
4. iOS / Android / Android TV / 웹앱 업데이트 배포

## Google Play
- 패키지: com.sunmkim.cloudboard
- 프로덕션 액세스 신청: **2026-09-28 11:17 KST 접수 완료**
- 현재 상태: Google 검토 중. 공개 출시 완료가 아님.
- 테스터 12명·14일 조건은 Console에서 충족 확인.
- 사용자 제공 사실: 테스터 16명, 약 2주, 지인 트레이너·수업 운영자·참여자 모집, 이메일 피드백 수집.
- 모집 난이도: 보통이었음.
- 첫해 설치 예상: 사용자 예상 1,000~10,000회에 해당하는 Console 선택지 0~1만 선택.
- 앱 가치 답변에는 제출 당시 확정명이었던 Lumove(기존 클라우드보드)를 포함. 제출 후 사용자가 새 이름 재선정을 지시함. 현재 실제 스토어 명칭은 클라우드보드이며 변경하지 않음.
- [접수 증빙](play-production-request.png)

## Apple
- 앱 ID: 6809105126 / App Store 명칭: CloudBoard StationD
- Bundle ID: com.sunmkim.cloudboard
- **2026-09-28 12:20 KST 심사 제출 완료 — 심사 대기 중**
- 제출 버전: 1.0, 바이너리: 1.0.0 (536)
- 제출 ID: 324915d6-1543-4b31-b0a6-c67001ad84c5
- [App Store Connect 심사 접수](https://appstoreconnect.apple.com/apps/6809105126/distribution/reviewsubmissions/details/324915d6-1543-4b31-b0a6-c67001ad84c5)
- 한국 스토어 무료 배포, 심사 승인 후 자동 출시. 한국 휴대폰 인증을 사용하는 현재 가입 범위에 맞춤.
- 기존 CloudBoard 아이콘 적용. [536 빌드 및 검증 성공](https://github.com/hyroxseouldev/cloud_board/actions/runs/36370848977)
- 전용 심사 계정의 Google 로그인, 실제 문자 인증, 온보딩, 무료 체험 활성화 확인.
- 실제 계정으로 Review Workout 생성 → 슬라이드 추가 → 저장 → 홈에서 재확인 → 로컬 재생 → 일시정지 → 종료 검증 완료.
- iPhone 6.5인치 및 iPad 13인치 스크린샷 각 2장 등록. 실제 Flutter 화면 위젯과 가상 샘플 데이터로 생성.
- 한국어 소개/키워드, 심사 연락처/로그인 안내, 개인정보 공개, 콘텐츠 권한, 연령 등급, 지원 URL 입력 완료.
- 비밀번호는 App Store Connect 심사 정보에만 입력했으며 저장소 문서에 기록하지 않음.
- 고객 지원: https://clyr-landing-20.vercel.app/apps/cloudboard/support
- 개인정보 처리방침: https://clyr-landing-20.vercel.app/apps/cloudboard/privacy
- [접수 증빙](apple/review-submitted.png)

## 문자 인증 발송 장애 — 해결
- Firebase 운영 함수의 SOLAPI 요청이 로컬 PC만 허용된 IP 설정으로 HTTP 403 / Forbidden 반환.
- 사용자 지시대로 해당 SOLAPI 키에 0.0.0.0/0 허용 추가. 실제 인증 문자가 수신되었고 사용자 확인 및 온보딩 완료.
- 비밀키·휴대폰 번호·인증번호·공급자 원문 없이 오류 코드와 분류만 기록하는 서버 진단 추가.
- Functions 테스트 32개 통과, 운영 cloudboardAppOnboarding 함수 배포 완료.
- 스크린샷 생성 테스트 및 해당 파일 Dart 분석 통과.

## 변경하지 않은 항목
- 앱 이름, 배너 및 브랜드
- Firebase 프로젝트, 앱 패키지/번들 ID
- 도메인 구매·상표 출원

## 브랜드 사전 조사 기록
- lumove.store에서 동명 스포츠/피트니스 상품 서비스 사용 확인.
- lumove.com: Verisign RDAP 등록 확인 (2026-09-28).
- lumove.app: Google registry RDAP 404. 구매 가능 여부는 미확인.
- 상표 등록 가능성에 대한 판단 및 공식 선행상표 검토는 완료하지 않음.
