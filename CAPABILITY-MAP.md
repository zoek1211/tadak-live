# Capability Map: 타닥 라이브 OCI 배포

승인: 2026-11-22. 의도는 `docs/intent/oci-deploy.md`. 모듈 스펙은 루트의 `SPEC-<모듈 id>.md`이고, 무엇이 있는지는 이 표가 기준이다.

| 모듈 id | 하는 일 | 먼저 있어야 하는 모듈 |
|---|---|---|
| `vm-host` | 리전·무료 한도 확인, VM 생성(A1 우선, 안 되면 E2.1.Micro), 80/443 개방, Docker·Caddy 설치, `<공인IP>.sslip.io` Let's Encrypt HTTPS | — |
| `backend-deploy` | 배포용 실행 설정, 상태 확인 경로, 비밀 값 주입(GitHub Secrets·VM 환경 설정), `main` 푸시 시 ARM64 이미지 빌드·VM 배포 | `vm-host` |
| `broadcast-api` | 데스크톱 앱용 `GET /api/broadcasts` JSON API | — (공개는 `backend-deploy`로) |
| `desktop-app` | Tauri 앱: API 목록 표시, 녹화방송 앱 내 재생, 라이브·로그인·댓글·후원은 웹 화면으로. Windows x64, macOS arm64·x64 빌드 | `broadcast-api` |
| `download-page` | OS별 링크, 지원 아키텍처, 설치 방법, Gatekeeper·SmartScreen 안내 | `desktop-app`, `backend-deploy` |
| `custom-domain` | `zoek.im` OCI DNS 영역, 네임서버 이전, 인증서 재발급 | `vm-host` (도메인 구매 전까지 보류) |

만드는 순서: `vm-host` → `backend-deploy` → `broadcast-api` → `desktop-app` → `download-page` → (도메인 구매 후) `custom-domain`

`broadcast-api`는 VM 작업과 무관해 앞의 두 모듈과 동시에 진행할 수 있다. CI 모듈은 따로 두지 않고 각 모듈이 자기 빌드·배포 작업을 가진다.

## 모듈 공통 결정

1. DB는 단독 모드 H2 파일 DB(`/data`)를 VM 디스크에 둔다. Postgres·Redis는 띄우지 않는다.
2. HTTPS는 Caddy 리버스 프록시가 인증서를 자동 발급·갱신한다. Spring `server.ssl`은 쓰지 않는다.
3. 컨테이너 이미지는 GHCR에 올리고 VM이 받아 다시 시작한다.
4. 데스크톱 설치 파일은 GitHub Releases에 둔다.
5. 다운로드 페이지는 백엔드 안 정적 페이지(`/download`)다.
6. 상태 확인은 `/actuator/health`만 공개한다.
7. `/api/broadcasts`는 비로그인 읽기 전용이다(웹 방송 목록과 같은 범위).
8. 데스크톱 앱 코드는 이 저장소의 `desktop/`에 둔다.
