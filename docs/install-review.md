# 설치 경로 검토와 실제 테스트

2026-10-16 기준 공개 v0.4.24를 일반 사용자가 내려받아 설치하는 흐름을 검토했다. 테스트 기기는 macOS 26.6.1의 Apple Silicon Mac 한 대이며, 다른 사람의 Mac·Intel 실기기·macOS 14/15의 최초 실행까지 검증한 것은 아니다.

## 결론

다운로드와 파일 설치는 가능하지만, 보안 경고 없이 쉽게 설치하는 일반 공개 배포는 아직 준비되지 않았다. 다운로드 페이지나 Homebrew를 바꾸는 것만으로 Gatekeeper 차단이 해결되지는 않는다.

## 직접 확인한 결과

| 항목 | 결과 | 확인 범위 |
|---|---|---|
| 공개 ZIP 다운로드 | 통과 | GitHub 로그인/인증 없이 URL에서 다운로드 |
| 파일 무결성 | 통과 | 공개 파일 SHA-256이 릴리스와 Homebrew 값과 일치 |
| ZIP 압축 해제 | 통과 | ChiiBar.app 정상 생성 |
| 앱 코드 서명 구조 검증 | 통과 | codesign strict 검증 통과. Apple 공증/악성코드 검사 통과를 의미하지 않음 |
| 배포용 서명 | 미완료 | Signature=adhoc, TeamIdentifier 없음 |
| 공증 티켓 | 없음 | stapler validate에서 티켓 없음 |
| macOS 실행 보안 평가 | 실패 | 직접 내려받은 앱과 Homebrew 설치본 모두 spctl rejected |
| Homebrew 신규 설치 | 통과 | 실제 brew install 실행, 사용자 앱과 충돌하지 않도록 임시 appdir 사용 |
| Homebrew 격리 속성 | 유지 | 설치본에 com.apple.quarantine 존재, 보안 예외/해제 없이 검사 |
| 임시 설치 제거 | 통과 | brew uninstall로 테스트 설치만 제거, 기존 /Applications 앱 0.4.24 및 실행 프로세스 유지 |
| CPU/최소 OS | 메타데이터 확인 | arm64·x86_64 포함, 두 아키텍처 minos 14.0 |
| 외부 런타임 | 의존성 확인 | 링크된 라이브러리는 Apple 시스템/Swift 런타임 경로. Python·Node·Xcode 설치를 사용자에게 요구하지 않음 |
| 첫 실행 UI | 코드 검토 | 일반 첫 실행은 메뉴 막대 아이콘만 생성, 팝오버 자동 열기는 --show 인자에 한정. 앱 재실행 시 팝오버 열림 |
| 자동 실행/업데이트 | 미구현 확인 | 로그인 시 자동 실행 및 앱 내 자동 업데이트 없음 |

파일: `ChiiBar-0.4.24-universal.zip` (56,016,209 bytes)
SHA-256: `5ad1a3fd51d8f47cefb8378e3145a332145a615b78a380deb4d0f3062c14efca`

Gatekeeper rejected는 이번 검사에서 실행 신뢰 조건을 충족하지 못했다는 뜻이다. 그 자체로 실제 악성코드가 발견됐다는 결론을 내리지 않는다. 다운로드한 앱을 보안 예외로 실행하는 테스트는 하지 않았다.

## 추천 설치 흐름

**일반 팬:** 소개 페이지의 ‘Mac용 다운로드’ → 공증된 DMG 열기 → 앱을 응용 프로그램으로 드래그 → 실행 → 첫 화면에서 메뉴 막대 위치와 무료 뽑기권 안내.

**Homebrew를 이미 쓰는 사람:** 같은 페이지의 보조 설치 명령 → 응용 프로그램에서 실행. Homebrew는 기본 사용자 경로가 아니라 선택지로 둔다.

DMG는 설치 안내를 담기 위한 포장이고 공증을 대신하지 않는다. ZIP 배포도 정식 서명·공증을 거치면 사용할 수 있다. 앱 하나를 복사하는 데 관리자 권한을 요구하는 PKG 설치기는 현재 구조에 불필요하다.

## 개선 우선순위

1. **공개 홍보 전 필수:** Developer ID Application 서명 → Apple 공증 Accepted → 티켓 첨부 → 새 다운로드본의 Gatekeeper 통과. 현재 이 Mac의 유효 코드 서명 인증서는 0개이며 계정 소유자의 인증서 준비가 필요하다.
2. **첫 실행 이해:** 앱 실행 직후 실제 첫 친구 화면과 메뉴 막대 위치를 보여주기. 처음부터 체험 화면으로 보내지 않기.
3. **다운로드 경험:** 응용 프로그램 바로가기와 드래그 안내가 있는 DMG, Finder에서 식별되는 앱 아이콘, 눈에 띄는 다운로드 버튼. 현재 앱 번들에 CFBundleIconFile 지정이 없다.
4. **재실행과 업데이트:** 로그인 시 자동 실행을 사용자가 선택하게 하고, 앱 안에서 업데이트 여부를 알려주기. 기존 게임 데이터 보존.
5. **외부 검증:** 공증 완료본을 ChiiBar 사용 이력이 없는 다른 Mac에서 브라우저와 Homebrew 각각 설치해 실행·첫 뽑기·재시작·업데이트를 확인. Intel 및 지원 최저 macOS도 별도 확인.

이번 작업에서는 현재 설치 안내를 직접 다운로드 우선으로 정리하고, 테스트 배포 상태·지원 환경·메뉴 막대 앱이라는 점을 명시했다. DMG, 첫 실행 변경, 로그인 자동 실행, 공증은 이 검토에서 구현 완료했다고 주장하지 않는다.

## 근거

- [Apple: Mac에서 앱 안전하게 열기](https://support.apple.com/ko-kr/102445) — 서명·공증과 첫 실행 경고, 관리형 Mac의 정책 제한.
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) — 정식 공증 절차.
- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook) — 앱 배포 및 설치 구성.
- [Homebrew 사용법](https://github.com/Homebrew/homebrew-cask/blob/main/USAGE.md) — 기본 /Applications 경로와 appdir 옵션.
