# 정식 Mac 배포 서명과 공증

2026-10-16 기준 ChiiBar의 정식 서명·공증 준비 상태와 배포 절차다. 현재 공개 0.4.24는 ad-hoc 서명이며 공증되지 않았다.

## 확인 결과

- 로컬 배포 인증서 없음: 유효한 codesigning identity 0개.
- 기존 앱: ad-hoc 서명, TeamIdentifier 없음.
- 로컬 Gatekeeper 평가: rejected.
- 따라서 친구 Mac에서 보안 경고 없이 실행되는 상태라고 안내할 수 없다. 경고의 정확한 문구에 따라 다른 원인도 있을 수 있다.

## 필요한 준비

사용자 소유 Apple Developer Program 계정의 Developer ID Application 인증서와 해당 개인 키가 Mac 키체인에 설치되어 있어야 한다. Apple 계정 로그인, 유료 등록·약관 동의, 인증서 접근 권한은 계정 소유자가 처리해야 한다. 자격 증명은 저장소나 채팅에 넣지 않는다. 기존 notarytool 키체인 프로필을 사용한다.

## 배포 순서

1. `CHIIBAR_SIGN_IDENTITY`에 키체인의 Developer ID Application 인증서 이름을 지정하고, `CHIIBAR_UNIVERSAL=1 bash Scripts/build-app.sh`로 빌드한다. 이 경로는 hardened runtime과 timestamp를 사용한다.
2. `CHIIBAR_NOTARY_PROFILE`에 기존 키체인 프로필 이름을 지정하고 `bash Scripts/notarize-app.sh`를 실행한다.
3. 스크립트는 Developer ID 서명과 hardened runtime을 확인한 다음 Apple에 제출한다. Accepted 결과에만 공증 티켓을 앱에 붙인다.
4. 티켓 검증, 코드 서명 검증, Gatekeeper 평가를 모두 통과한 뒤 `-notarized-universal.zip` 파일을 만든다. 이 최종 파일과 체크섬만 릴리스·Homebrew에 반영한다.
5. 다른 Mac에서 Homebrew/브라우저로 새로 내려받아 최초 실행을 확인한다. 로컬 빌드 실행만으로 다운로드 차단 해결을 확정하지 않는다.

기존 ad-hoc ZIP에 서명만 덮어쓰고 같은 버전·체크섬을 재사용하지 않는다. 격리 속성 삭제와 Gatekeeper 비활성화는 해결 방법으로 사용하지 않는다.

## 검증 범위

현재는 셸 문법 검사와 미설정 프로필·ad-hoc 서명 거부 확인까지 수행했다. 실제 Developer ID 서명, Apple 제출, Accepted 수신, stapling, Gatekeeper 통과는 인증서 준비 후 수행해야 한다.

출처(2026-10-16 확인): [Apple Developer ID](https://developer.apple.com/developer-id/), [Apple 공증 안내](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
