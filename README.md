# 타닥 라이브

**불 켜면 모인다.** 휴대폰 하나로 라이브를 켜면, 사람들이 불가에 둘러앉듯 모여 함께 보고 이야기하고 후원하는 방송 서비스입니다.

- **라이브 방송:** 휴대폰 카메라·마이크로 송출하고 다른 화면에서 실시간으로 봅니다. 영상은 WebRTC로 기기끼리 직접 오가고, 서버는 연결(시그널링)만 이어 줍니다.
- **다시 보기:** 영상 파일을 올리거나 영상 주소를 넣어 녹화방송을 등록하고 바로 재생합니다.
- **회원과 댓글:** 회원가입·로그인한 사람만 방송을 만들고 댓글을 씁니다. 방송은 만든 사람만, 댓글은 쓴 사람만 고치고 지울 수 있고, 권한은 서버가 매번 검사합니다. 목록·시청·댓글 읽기는 로그인 없이 공개입니다.
- **후원(장작 넣기):** 토스페이먼츠 테스트 결제로 방송한 사람에게 후원합니다. 서버가 토스에 승인을 다시 확인한 뒤에만 합계에 더합니다.
- **데스크톱 앱:** Windows·macOS 앱이 공개 서버의 방송 목록을 받아 보여 주고, 녹화방송을 앱 안에서 재생합니다.

## 공개 주소

| 무엇 | 주소 |
| --- | --- |
| 웹 서비스 | <https://129-221-138-89.sslip.io> |
| 앱 받기(다운로드 페이지) | <https://129-221-138-89.sslip.io/download> |
| 방송 목록 API | <https://129-221-138-89.sslip.io/api/broadcasts> |
| 상태 확인 | <https://129-221-138-89.sslip.io/actuator/health> |
| 데스크톱 설치 파일 | [GitHub Releases(최신)](https://github.com/zoek1211/tadak-live/releases/latest) |

> **임시 배포입니다.** 쓰려는 도메인(`zoek.im`)의 등록을 기다리는 중이라, 지금은 VM의 공인 IP를 이름으로 바꿔 주는 [sslip.io](https://sslip.io) 주소(`<IP를 대시로>.sslip.io`)에 Let's Encrypt 인증서를 붙여 HTTPS로 공개했습니다. 도메인 등록이 끝나면 OCI DNS로 옮기고 주소를 바꿉니다. 도메인을 아직 사지 않아 도메인 비용은 없습니다.

## 목차

- [빠른 실행(로컬)](#빠른-실행로컬)
- [휴대폰으로 송출하기](#휴대폰으로-송출하기)
- [후원 켜기](#후원-켜기)
- [배포 구성](#배포-구성)
  - [서버 배포 설정](#서버-배포-설정)
  - [클라이언트 빌드·패키징 설정](#클라이언트-빌드패키징-설정)
  - [다운로드 페이지](#다운로드-페이지)
  - [비밀 값과 결제 정보](#비밀-값과-결제-정보)
- [재현 절차](#재현-절차)
- [방송 목록 API](#방송-목록-api)
- [데스크톱 앱](#데스크톱-앱)
- [환경변수](#환경변수)
- [기술 구성](#기술-구성)
- [이 프로젝트의 출발점](#이-프로젝트의-출발점)

## 빠른 실행(로컬)

필요한 것: JDK 25 이상 (Gradle은 래퍼가 내려받습니다)

```bash
./gradlew bootRun
```

브라우저에서 <http://localhost:8080> 을 엽니다. 방송을 만들거나 댓글을 쓰려면 머리글의 **회원가입** 으로 가입하세요(가입하면 바로 로그인됩니다). 8080 포트를 다른 프로그램이 쓰고 있다면 `PORT=9090 ./gradlew bootRun` 처럼 포트를 바꿉니다.

데이터(H2 DB 파일과 올린 영상)는 `./data` 에 저장되어 서버를 다시 켜도 남습니다. 처음 상태로 돌리려면 서버를 끄고 `data/` 를 지웁니다.

```bash
./gradlew test                     # 테스트 (일부는 Docker가 켜져 있어야 실행됨)
./gradlew bootJar && java -jar build/libs/chzzk-0.0.1-SNAPSHOT.jar   # jar로 실행
docker build -t tadak-live .       # 배포와 같은 컨테이너 이미지
```

## 휴대폰으로 송출하기

휴대폰 브라우저는 **HTTPS 주소에서만** 카메라·마이크를 엽니다. 공개 주소(<https://129-221-138-89.sslip.io>)는 이미 HTTPS라 휴대폰에서 바로 로그인 → **불 피우기** 로 방송을 시작하면 됩니다.

로컬 서버로 시험할 때는 cloudflared 임시 터널이 가장 간단합니다(계정·인증서 필요 없음).

1. [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) 를 설치합니다 (macOS: `brew install cloudflared`).
2. 서버를 띄운 채로 다른 터미널에서 터널을 엽니다.

   ```bash
   cloudflared tunnel --url http://localhost:8080
   ```

3. 출력에 나오는 `https://<임의이름>.trycloudflare.com` 주소를 휴대폰에서 열고, 로그인한 뒤 **불 피우기** 로 방송을 시작합니다.
4. 컴퓨터 브라우저의 목록 "지금 타는 중"에서 그 라이브를 눌러 시청합니다.

서로 다른 네트워크라 영상이 안 오면 TURN 서버를 설정하세요([환경변수](#환경변수)). 직접 HTTPS(자체 서명 키스토어)와 카메라 권한 문제 해결은 [과제 문서의 휴대폰 연결 방법](docs/chzzk-assignment-README.md#휴대폰-연결-방법)에 있습니다.

## 후원 켜기

실제 돈이 오가지 않는 **테스트 결제** 만 씁니다.

1. [토스페이먼츠 개발자센터](https://developers.tosspayments.com)에서 **API 개별 연동 키** 의 테스트 키를 확인합니다. 클라이언트 키는 `test_ck_`, 시크릿 키는 `test_sk_` 로 시작합니다.
2. 두 값을 환경변수로 넣고 서버를 띄웁니다. 시크릿 키는 저장소에 커밋하지 마세요.

   ```bash
   TOSS_CLIENT_KEY=test_ck_<클라이언트키> TOSS_SECRET_KEY=test_sk_<시크릿키> ./gradlew bootRun
   ```

키가 하나라도 없으면 후원만 꺼진 채로 앱이 뜹니다. 공개 서버에서는 GitHub Secrets에 넣은 테스트 키를 배포가 VM에 넣습니다([비밀 값과 결제 정보](#비밀-값과-결제-정보)). 웹훅 등록 같은 자세한 내용은 [과제 문서의 4단계](docs/chzzk-assignment-README.md#4단계-도네이션)에 있습니다.

## 배포 구성

```text
 개발자 ── PR 병합 ──▶ main ──┬─▶ deploy.yml ─ 테스트 → arm64 이미지 → GHCR ─ SSH ─▶ OCI VM(Docker Compose)
                              │                                                       ├─ Caddy :80/:443 (Let's Encrypt)
                              │                                                       └─ 앱 :8080(내부) + 볼륨 tadak_data
                              └─▶ desktop.yml(desktop/ 바뀔 때) ─ Windows·macOS 빌드 ─▶ GitHub Release(latest)

 방문자 ── https://129-221-138-89.sslip.io ──▶ Caddy ──▶ 앱(웹·/api/broadcasts·/download)
 데스크톱 앱 ── /api/broadcasts·영상 ──▶ 같은 서버          /download 의 받기 버튼 ──▶ GitHub Release 파일
```

설계와 완료 기준: [CAPABILITY-MAP.md](CAPABILITY-MAP.md)(모듈 지도) · [SPEC-vm-host.md](SPEC-vm-host.md) · [SPEC-backend-deploy.md](SPEC-backend-deploy.md) · [SPEC-broadcast-api.md](SPEC-broadcast-api.md) · [SPEC-desktop-app.md](SPEC-desktop-app.md) · [SPEC-download-page.md](SPEC-download-page.md). 작업 기록은 GitHub 이슈(#1~#46)에 있습니다.

### 서버 배포 설정

**서버:** Oracle Cloud Always Free VM 한 대(싱가포르 리전), `VM.Standard.A1.Flex` 2 OCPU·12GB(arm64), Ubuntu 24.04. 무료 한도(A1 합계 4 OCPU·24GB) 안에서 가장 넉넉한 사양이라 골랐습니다. 만들기 전 점검에서 A1 한도가 모두 남아 있었고, 재고 부족 없이 첫 시도에 만들어졌습니다. 무료 한도 밖 자원은 쓰지 않으며, 과금이 생기면 바로 알 수 있게 월 1 USD 예산과 0.01 USD 초과 메일 알림을 걸어 두었습니다. 앱은 단독 모드(파일 기반 H2 + 디스크)로 돕니다.

**주소와 HTTPS:** 예약 공인 IP(인스턴스를 다시 만들어도 유지) + sslip.io 임시 주소. Caddy가 Let's Encrypt 인증서를 받고 갱신하며, HTTP는 HTTPS로 넘깁니다. 인터넷에 열린 포트는 22·80·443뿐이고 앱(8080)은 Caddy 뒤 Compose 내부 네트워크에만 있습니다.

| 파일 | 하는 일 |
| --- | --- |
| [deploy/oci/preflight.sh](deploy/oci/preflight.sh) | 읽기 전용 점검: 홈 리전, 무료 한도 남은 양, 이미지. 아무것도 만들지 않음 |
| [deploy/oci/budget.sh](deploy/oci/budget.sh) | 월 예산·과금 알림 생성(알림 주소는 실행할 때 환경변수로만) |
| [deploy/oci/provision.sh](deploy/oci/provision.sh) | VCN·서브넷·보안 목록(22/80/443)·인스턴스·예약 IP 생성(있으면 재사용), CI 전용 `deploy` 사용자, 설정 업로드. 다시 실행해도 안전 |
| [deploy/oci/cloud-init.yaml](deploy/oci/cloud-init.yaml) | 인스턴스 첫 부팅: Docker 설치, OS 방화벽 80/443 개방 |
| [deploy/oci/verify.sh](deploy/oci/verify.sh) | 외부에서 확인: 인증서·HTTP→HTTPS·8080 차단, `--app` 이면 앱 화면·헬스·쿠키 Secure·목록 API·다운로드 링크 |
| [deploy/vm/compose.yaml](deploy/vm/compose.yaml) | VM의 Compose: Caddy(80/443) + 앱(포트 없음, 볼륨 `tadak_data:/data`, 메모리 6GB) |
| [deploy/vm/Caddyfile](deploy/vm/Caddyfile) | `reverse_proxy app:8080`, 인증서 발급처를 Let's Encrypt로 고정 |
| [deploy/vm/deploy.sh](deploy/vm/deploy.sh) | VM에서 실행: 새 이미지로 교체 → 2분 안에 `/actuator/health` 가 `UP` 이 아니면 이전 이미지로 되돌리고 실패로 끝냄 |
| [Dockerfile](Dockerfile) | JDK 25로 빌드 → JRE 25로 실행(비루트) |
| [.github/workflows/deploy.yml](.github/workflows/deploy.yml) | `main` 푸시·수동 실행: 테스트 → arm64 러너에서 이미지 빌드·GHCR(`ghcr.io/zoek1211/tadak-live:<커밋 SHA>`) → 고정 호스트 키로 SSH, 설정 업로드, `deploy.sh` |

컨테이너를 바꾸는 동안 수 초 끊길 수 있습니다. DB 파일과 올린 영상은 Docker 볼륨 `tadak_data` 에 있어 재배포해도 남습니다. **백업은 아직 없습니다.** 수동 재배포는 `gh workflow run deploy.yml` 입니다.

### 클라이언트 빌드·패키징 설정

| 파일 | 하는 일 |
| --- | --- |
| [desktop/](desktop/) | Tauri 2 + TypeScript(Vite) 앱 소스, 테스트(`desktop/test`, Vitest) |
| [desktop/src-tauri/tauri.conf.json](desktop/src-tauri/tauri.conf.json) | 앱 이름·식별자(`live.tadak.desktop`)·창·CSP, 번들 설정(macOS ad-hoc 서명 `-`, 최소 macOS 11) |
| [desktop/src-tauri/capabilities/default.json](desktop/src-tauri/capabilities/default.json) | 권한: 로컬 앱 창에만 창 열기·브라우저 열기. 원격 웹 창에는 권한 없음 |
| [desktop/package.json](desktop/package.json) · [pnpm-lock.yaml](desktop/pnpm-lock.yaml) | 프런트엔드 의존성(pnpm 버전 고정) |
| [.github/workflows/desktop.yml](.github/workflows/desktop.yml) | PR(`desktop/` 변경): 테스트·타입 검사 + 빌드만. `main` 푸시(`desktop/` 변경): 버전 `0.1.<실행 번호>` 로 Windows NSIS `.exe`(x64)·macOS 유니버설 `.dmg` 빌드 → Release `desktop-v0.1.N`(latest)에 고정 이름으로 올림 |

- 앱이 붙는 서버 주소는 빌드할 때 저장소 변수 `TADAK_HOST` 로 정합니다(`VITE_TADAK_API_BASE=https://<TADAK_HOST>`).
- 설치 파일 이름은 고정입니다: `Tadak-Live-windows-x64-setup.exe`, `Tadak-Live-macos-universal.dmg`. 그래서 `https://github.com/zoek1211/tadak-live/releases/latest/download/<파일 이름>` 이 항상 최신 파일입니다.
- 코드 서명은 하지 않습니다(유료 인증서). macOS는 ad-hoc 서명만 해서 "손상된 앱" 대신 "확인할 수 없음" 경고가 뜨고, 다운로드 페이지의 안내대로 열 수 있습니다.

### 다운로드 페이지

`/download` 는 별도 서버 없이 **백엔드 안 Thymeleaf 페이지**로 들어 있어 백엔드와 함께 배포됩니다(위 `deploy.yml`). 설치 파일은 VM에 두지 않고 GitHub Release로 링크합니다.

| 파일 | 하는 일 |
| --- | --- |
| [download/DownloadController.java](src/main/java/kr/devcourse/chzzk/download/DownloadController.java) | `GET /download`(비로그인 공개) |
| [download/DesktopDownloads.java](src/main/java/kr/devcourse/chzzk/download/DesktopDownloads.java) | 설치 파일 주소 = 설정 `chzzk.desktop.download-base` + 고정 파일 이름 |
| [templates/download/index.html](src/main/resources/templates/download/index.html) | 페이지: OS별 받기, 지원 대상, macOS·Windows 경고 넘기는 법, 휴대폰 안내, "이 컴퓨터용" 표시 |
| [templates/fragments/layout.html](src/main/resources/templates/fragments/layout.html) | 모든 화면 머리글의 **앱 받기** 링크 |
| [application.properties](src/main/resources/application.properties) | `chzzk.desktop.download-base`(환경변수 `CHZZK_DESKTOP_DOWNLOAD_BASE`, 기본: GitHub Releases 최신) |

### 비밀 값과 결제 정보

저장소에는 실제 비밀 값과 결제 정보가 없습니다. 이름만 적어 두고 값은 아래 위치에만 있습니다.

| 무엇 | 어디에 |
| --- | --- |
| CI 배포용 SSH 비밀 키 | GitHub Secret `VM_SSH_KEY`(만든 사람 컴퓨터의 `~/.ssh/tadak_deploy` 에서 사용자가 직접 입력) |
| 토스 테스트 키 | GitHub Secret `TOSS_CLIENT_KEY`, `TOSS_SECRET_KEY`(사용자가 직접 입력) |
| TURN 자격 증명(선택) | GitHub Secret `CHZZK_TURN_URL`, `CHZZK_TURN_USERNAME`, `CHZZK_TURN_CREDENTIAL` |
| VM 주소·호스트 키(공개 정보) | GitHub 변수 `TADAK_HOST`, `VM_SSH_KNOWN_HOSTS` |
| VM의 실행 설정 | VM `/opt/tadak/.env`(권한 600). 배포할 때마다 GitHub Secrets 기준으로 다시 씀 |
| OCI 자원 ID·공인 IP 기록 | 로컬 `deploy/oci/.state.env`(gitignore) |
| OCI 로그인 | 로컬 `~/.oci/`(1시간짜리 세션 토큰) |
| 과금 알림 메일 주소 | OCI 예산 알림 설정에만(실행할 때 `TADAK_BUDGET_EMAIL` 로 넘김) |
| 클라우드 결제 수단 | OCI 콘솔 계정에만. 저장소·문서·이슈에 없음 |

비밀 값은 워크플로에서 `env:` 와 표준 입력으로만 넘겨 명령 줄과 로그에 나오지 않습니다. 배포 로그·이슈·저장소에서 키 형태 문자열이 없는 것을 확인했습니다(이슈 #16·#37).

## 재현 절차

처음부터 같은 구성을 만드는 순서입니다(지금 공개 서버는 이 순서로 만들어져 있습니다). 계정 로그인·약관 동의·결제 수단 등록·비밀 값 입력은 사람이 직접 합니다.

**1. 준비**

- OCI 계정(Always Free, 무료 인스턴스 회수를 피하려면 종량제로 전환하되 무료 한도 안 자원만 사용), 이 저장소를 가진 GitHub 계정
- 로컬 도구: `brew install oci-cli jq shellcheck` (데스크톱 앱까지 빌드하려면 Rust, Node.js, pnpm)

**2. OCI 자원 만들기**

```bash
oci session authenticate --profile-name tadak --region <홈 리전>   # 브라우저 로그인(세션 1시간)
deploy/oci/preflight.sh                              # 무료 한도 점검(아무것도 만들지 않음)
TADAK_BUDGET_EMAIL=<알림 받을 주소> deploy/oci/budget.sh   # 과금 알림
deploy/oci/provision.sh                              # 네트워크·VM·예약 IP·Caddy·deploy 사용자(재실행 안전)
deploy/oci/verify.sh                                 # HTTPS·인증서·포트 확인
```

`provision.sh` 가 끝나면 공인 IP와 `https://<IP를 대시로>.sslip.io` 주소를 출력하고, CI 배포 키 `~/.ssh/tadak_deploy` 를 만들어 둡니다.

**3. GitHub 설정**(값은 터미널에 직접 입력, 채팅·이슈에 붙이지 않음)

```bash
gh secret set VM_SSH_KEY < ~/.ssh/tadak_deploy
gh secret set TOSS_CLIENT_KEY
gh secret set TOSS_SECRET_KEY
gh variable set TADAK_HOST --body "<IP를 대시로>.sslip.io"
gh variable set VM_SSH_KNOWN_HOSTS --body "$(ssh-keyscan -t ed25519 <공인 IP> 2>/dev/null)"
```

저장소 설정에서 자동 병합을 켜고 `main` 에 필수 검사 `test` 를 걸면, PR이 테스트를 통과한 뒤에만 배포됩니다.

**4. 배포와 확인**

```bash
gh workflow run deploy.yml                           # 또는 main 에 PR 병합
deploy/oci/verify.sh --app                           # 앱·헬스·쿠키·목록 API·다운로드 링크까지 확인
```

`desktop/` 을 바꾼 커밋이 `main` 에 들어가면 `desktop.yml` 이 설치 파일을 Release에 올립니다(처음 한 번은 `gh workflow run desktop.yml`). 그 뒤 `/download` 의 받기 버튼이 그 파일을 내려줍니다.

**5. 손으로 확인**: 공개 주소에서 회원가입·로그인, 녹화방송 업로드·재생, 댓글, 다른 계정으로 장작 넣기(토스 테스트 결제), 휴대폰으로 불 피우기. 데스크톱 앱을 받아 목록·재생·웹 창이 되는지.

## 방송 목록 API

데스크톱 앱 같은 클라이언트가 방송 목록을 받아 자기 화면에 그리고, 녹화방송은 직접 재생하도록 공개 API를 둡니다. 로그인이 필요 없고 읽기만 합니다. 계약 전체는 [SPEC-broadcast-api.md](SPEC-broadcast-api.md)에 있습니다.

```bash
curl -s https://129-221-138-89.sslip.io/api/broadcasts | jq
```

```json
{
  "live": [
    { "id": 3, "title": "저녁 산책 라이브", "ownerNickname": "타닥이", "status": "ON_AIR",
      "startedAt": "2026-11-22T10:20:00Z", "endedAt": null, "viewerCount": 2, "viewerCapacity": 5,
      "watchUrl": "https://129-221-138-89.sslip.io/live/3" }
  ],
  "recorded": [
    { "id": 2, "title": "첫 녹화", "ownerNickname": "타닥이", "registeredAt": "2026-11-22T10:03:00Z",
      "videoSource": "UPLOADED", "playbackUrl": "https://129-221-138-89.sslip.io/videos/….mp4",
      "watchUrl": "https://129-221-138-89.sslip.io/broadcasts/2" }
  ]
}
```

| 필드 | 설명 |
| --- | --- |
| `live[]` | 라이브 방송. 방송 중(`status: ON_AIR`)이 먼저, 그다음 종료(`ENDED`), 각각 최신순(웹 목록과 같음) |
| `recorded[]` | 녹화방송, 최신순 |
| `id`, `title` | 방송 번호와 제목 |
| `ownerNickname` | 방송한 회원의 닉네임. 소유자 없는 옛 방송은 `null` |
| `startedAt` / `endedAt` / `registeredAt` | ISO-8601 UTC 시각(`…Z`). 방송 중이면 `endedAt` 은 `null` |
| `viewerCount` / `viewerCapacity` | 지금 보고 있는 시청자 수와 정원. 종료된 라이브는 `viewerCount: 0` |
| `videoSource` | `UPLOADED`(이 서버에 올린 영상) 또는 `EXTERNAL`(다른 곳의 영상 주소) |
| `playbackUrl` | 녹화 영상 주소. 올린 영상은 이 서버의 절대 주소이고 `Range` 요청(`206`)으로 탐색할 수 있습니다. 외부 영상은 등록한 주소 그대로 |
| `watchUrl` | 웹 시청 화면의 절대 주소. 라이브 시청·로그인·댓글·후원은 이 화면에서 합니다 |

- 주소는 요청을 받은 주소 기준으로 만듭니다. 공개 서버에서는 `https://` 공개 주소가 됩니다.
- 회원 번호와 로그인 아이디는 넣지 않습니다.
- 다른 출처(예: 데스크톱 앱 웹뷰 `tauri://localhost`)에서 `fetch` 할 수 있도록 `/api/**` 의 `GET` 은 모든 출처를 허용합니다(CORS). 쿠키는 실리지 않습니다. 화면 경로는 CORS를 열지 않습니다.
- 필드는 추가만 하고 이름이나 뜻을 바꾸지 않습니다. 클라이언트는 모르는 필드를 무시하면 됩니다.

## 데스크톱 앱

Windows·macOS용 앱입니다. 공개 서버의 [방송 목록 API](#방송-목록-api)로 "지금 타는 중"·"다시 보기"를 보여 주고, 녹화방송은 앱 안에서 바로 재생합니다(앞뒤로 넘기기 가능). 라이브 시청·로그인·댓글·장작 넣기는 웹 화면을 **앱 안 새 창**으로 열어 씁니다. 상단 **로그인**·**회원가입**도 웹 화면을 앱 창으로 열고, 앱의 웹 창들은 로그인 상태를 함께 씁니다. 앱 창에서 막히는 일이 있으면 라이브 카드와 플레이어의 **브라우저로 열기**를 쓰세요.

| 운영체제 | 파일 |
| --- | --- |
| Windows 10·11 (x64) | [Tadak-Live-windows-x64-setup.exe](https://github.com/zoek1211/tadak-live/releases/latest/download/Tadak-Live-windows-x64-setup.exe) |
| macOS 11 이상 (Apple Silicon·Intel 겸용) | [Tadak-Live-macos-universal.dmg](https://github.com/zoek1211/tadak-live/releases/latest/download/Tadak-Live-macos-universal.dmg) |

코드 서명을 하지 않은 앱이라 처음 열 때 macOS·Windows가 경고를 띄웁니다. 경고를 넘기고 처음 실행하는 순서는 **[앱 받기 페이지(/download)](https://129-221-138-89.sslip.io/download)** 에 있습니다. 사이트 머리글의 **앱 받기**로도 들어갈 수 있습니다. macOS 설치본은 실제로 설치해 확인했고, Windows 설치본은 CI 빌드까지 확인했습니다(실기기 확인 대기).

**로컬에서 실행·빌드**(필요한 것: Rust, Node.js, pnpm):

```bash
cd desktop
pnpm install
pnpm test && pnpm typecheck
pnpm tauri dev                                                  # 공개 서버에 붙는 개발 모드 앱
VITE_TADAK_API_BASE=http://localhost:8080 pnpm tauri dev         # 로컬 서버(./gradlew bootRun)에 붙이기
pnpm tauri build --target universal-apple-darwin --bundles dmg   # macOS 설치 파일
```

## 환경변수

모두 선택 사항이고, 예시는 [.env.example](.env.example)에 있습니다. 비밀 값(TURN 자격 증명, 키스토어 비밀번호, 토스 시크릿 키)은 커밋하지 말고 실행 환경에서만 설정하세요. 변수 이름의 `CHZZK_` 접두어는 출발점이었던 과제 이름을 그대로 쓴 것입니다.

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `PORT` | `8080` | 서버 포트 |
| `CHZZK_DATA_DIR` | `./data` | DB 파일과 올린 영상(`videos/`)이 저장되는 디렉터리 |
| `CHZZK_MAX_UPLOAD_SIZE` | `2GB` | 올릴 수 있는 영상 최대 크기 |
| `CHZZK_VIEWER_CAPACITY` | `5` | 라이브 하나를 동시에 볼 수 있는 시청자 수 |
| `CHZZK_BROADCASTER_JOIN_TIMEOUT` | `30s` | 라이브를 시작한 뒤 방송자가 접속해야 하는 제한 시간 |
| `CHZZK_STUN_URL` | `stun:stun.l.google.com:19302` | WebRTC STUN 서버 |
| `CHZZK_TURN_URL` / `CHZZK_TURN_USERNAME` / `CHZZK_TURN_CREDENTIAL` | (없음) | TURN 서버. 서로 다른 네트워크 사이 연결이 필요할 때만 |
| `CHZZK_SSL_ENABLED` | `false` | `true` 면 앱이 직접 HTTPS로 서비스(공개 서버는 Caddy가 HTTPS를 맡아 끔) |
| `CHZZK_SSL_KEY_STORE` / `CHZZK_SSL_KEY_STORE_PASSWORD` / `CHZZK_SSL_KEY_STORE_TYPE` | (없음) / (없음) / `PKCS12` | HTTPS 키스토어 |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY` | (없음) | 토스페이먼츠 테스트 키. 둘 다 있어야 후원이 켜짐 |
| `TOSS_CONNECT_TIMEOUT` / `TOSS_READ_TIMEOUT` | `5s` / `10s` | 토스 API 제한 시간 |
| `CHZZK_DESKTOP_DOWNLOAD_BASE` | `https://github.com/zoek1211/tadak-live/releases/latest/download` | 앱 받기 페이지(`/download`)의 설치 파일 주소 앞부분. 파일 이름(`Tadak-Live-windows-x64-setup.exe`, `Tadak-Live-macos-universal.dmg`)은 고정 |
| `CHZZK_COOKIE_SECURE` | `false` | `true` 면 로그인 세션 쿠키에 Secure를 붙임. HTTPS 프록시 뒤 배포에서만 켬(공개 서버는 배포가 켬. 로컬 `http://localhost` 에서 켜면 로그인이 유지되지 않음) |

## 기술 구성

- Java 25, Spring Boot 4.1, Spring MVC + Thymeleaf, Spring Data JPA, Spring WebSocket, Spring Security(세션 로그인·CSRF)
- 저장소: 파일 기반 H2 + 로컬 디스크(공개 서버는 Docker 볼륨)
- 배포: OCI Always Free VM, Docker Compose(앱 + Caddy), GitHub Actions → GHCR
- 데스크톱 앱: Tauri 2 + TypeScript(Vite), GitHub Actions → GitHub Releases
- 설계 결정: [docs/adr/](docs/adr/)
  - [WebRTC P2P 라이브](docs/adr/0001-webrtc-p2p-live.md)
  - [송출 키 대신 로그인한 소유자 검사](docs/adr/0002-live-owner-session-replaces-broadcast-key.md)
  - [토스 테스트 결제와 서버 승인 확인](docs/adr/0003-toss-test-payment-with-server-confirmation.md)
- 용어: [GLOSSARY.md](GLOSSARY.md)

## 이 프로젝트의 출발점

타닥 라이브는 Codemit 과제 "치지직 만들기"로 만든 서비스에 새 이름과 화면 테마를 입힌 것입니다. 커밋 기록은 그대로 이어지고, 단계별 제출 태그는 [zoek1211/chzzk](https://github.com/zoek1211/chzzk)에 있습니다. 제출 당시 README(단계별 구현 범위, 직접 확인 절차, 테스트 목록)는 [docs/chzzk-assignment-README.md](docs/chzzk-assignment-README.md)에 그대로 옮겨 두었습니다.
