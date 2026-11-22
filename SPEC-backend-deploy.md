# Spec: backend-deploy — V1

Status: approved (2026-11-22) · 모듈 지도: `CAPABILITY-MAP.md` · 의도: `docs/intent/oci-deploy.md` · 앞 모듈: `SPEC-vm-host.md`(implemented)

## Objective

`main` 에 푸시하면 GitHub Actions가 테스트를 통과한 커밋으로 ARM64 이미지를 만들어 GHCR에 올리고, `vm-host` 가 만든 VM에서 새 이미지로 앱을 다시 띄운다. 결과로 `https://<공인IP>.sslip.io` 에서 타닥 라이브 웹 전체(방송 목록·녹화방송 업로드·재생·라이브·로그인·댓글·후원)가 동작한다.

사용자:
- **시청자·방송자:** 공개 주소에서 지금 로컬과 같은 기능을 쓴다.
- **운영자(저장소 주인):** 코드를 `main` 에 합치기만 하면 배포된다. 비밀 값은 GitHub Secrets에 직접 넣는다.

## 가정

1. **새 Spring 프로필은 만들지 않는다.** VM은 지금의 단독 모드(H2 파일 DB, `/data`)로 돌고, 배포용 차이는 모두 환경변수로 준다. 기존 `application.properties` 의 환경변수 계약을 그대로 쓴다.
2. **상태 확인 경로는 이미 있다.** `/actuator/health`(+ liveness·readiness)만 노출되고 다른 actuator는 404다(`ActuatorHealthTest`). 배포는 이 경로로 성공을 판단한다. 코드 변경 없음.
3. **세션 쿠키 Secure 플래그는 환경변수로 켠다.** Caddy 뒤에서 앱은 HTTP로 요청을 받는다. `forward-headers-strategy=framework` 는 Spring 쪽 URL 생성(토스 successUrl 등)은 https로 맞추지만, Tomcat이 만드는 `JSESSIONID` 쿠키에 Secure가 붙는다는 보장은 없다. `server.servlet.session.cookie.secure=${CHZZK_COOKIE_SECURE:false}` 를 추가하고 VM에서 `true` 로 둔다. 로컬 HTTP 실행은 기본값 그대로라 영향 없음. **유일한 앱 코드(설정) 변경**이고 테스트를 붙인다.
4. **이미지는 GitHub의 ARM64 러너(`ubuntu-24.04-arm`)에서 기존 `Dockerfile` 로 그대로 빌드한다.** 저장소가 공개라 무료이고, QEMU 에뮬레이션(느림)이 필요 없다. 태그는 커밋 SHA와 `main`.
5. **VM은 GHCR에서 받을 때 배포 작업의 `GITHUB_TOKEN` 으로 로그인했다가 바로 로그아웃한다.** 패키지 공개 여부와 상관없이 동작하고, VM에 오래 남는 레지스트리 자격 증명이 없다.
6. **CI 배포 전용 SSH 키와 VM 사용자 `deploy` 를 따로 둔다.** 키는 `~/.ssh/tadak_deploy`(ed25519)로 만들고, 공개 키는 `provision.sh` 가 VM의 `deploy` 사용자(docker 그룹)에 등록한다. 비밀 키는 GitHub Secret `VM_SSH_KEY` 에만 둔다. 관리용 `ubuntu` 키(`tadak_oci`)는 CI에 주지 않는다. docker 그룹은 사실상 root 권한이라는 점은 받아들인다(VM 한 대, 이 앱 전용).
7. **비밀 값의 원본은 GitHub Secrets다.** 배포 작업이 매번 VM의 `/opt/tadak/.env`(권한 600)에 앱 비밀 값을 다시 쓴다. VM에서 손으로 바꾼 값은 다음 배포에 덮인다. `vm-host` 가 쓰는 `TADAK_HOST`·`TADAK_ACME_CA` 줄은 건드리지 않는다.
8. **설정 파일도 배포 작업이 올린다.** `deploy/vm/compose.yaml` 과 `Caddyfile` 을 매 배포마다 `/opt/tadak` 에 올린다. `provision.sh` 와 같은 경로·같은 방식이라 어느 쪽이 마지막에 돌든 결과가 같다.
9. **앱 컨테이너는 포트를 열지 않는다.** Compose 내부 네트워크에서 Caddy가 `app:8080` 으로 보낸다. WebSocket(`/ws/**`)과 2GB 업로드는 Caddy 기본 설정으로 통과한다(본문 크기 제한 없음).
10. **메모리:** 앱 컨테이너 `mem_limit: 6g`. Dockerfile의 `-XX:MaxRAMPercentage=75` 로 힙 약 4.5GB. VM 12GB 중 나머지는 OS·Caddy·Docker 몫.
11. **배포 중 잠깐 끊김은 받아들인다.** 인스턴스 하나라 컨테이너를 바꾸는 동안 수 초~수십 초 502가 날 수 있다. 무중단 배포는 하지 않는다.
12. **실패하면 이전 이미지로 되돌린다.** 새 이미지로 띄운 뒤 2분 안에 `/actuator/health` 가 `UP` 이 아니면 `.env` 의 이미지 태그를 이전 값으로 되돌려 다시 띄우고 작업을 실패로 끝낸다.
13. **TURN 서버는 이번 범위가 아니다.** STUN만으로는 서로 다른 네트워크(예: LTE 방송자 ↔ 집 Wi-Fi 시청자) 사이 라이브가 안 될 수 있다. 녹화방송은 영향 없음. `CHZZK_TURN_*` 는 Secret이 있으면 `.env` 에 넣도록만 해 둔다.

## Tech Stack

- GitHub Actions: `actions/checkout@v4`, `actions/setup-java@v4`(temurin 25), `gradle/actions/setup-gradle@v4`(기존 CI와 같음), `docker/login-action@v3`, `docker/setup-buildx-action@v3`, `docker/build-push-action@v6`
- 레지스트리: GHCR `ghcr.io/zoek1211/tadak-live`
- VM: Docker Compose(앱 + Caddy), 기존 `Dockerfile`(JDK 25 빌드 → JRE 25 실행, 비루트)
- 배포 연결: `ssh`/`scp`(러너 기본 OpenSSH), 호스트 키 고정(`known_hosts` 를 저장소 변수로)

## Commands

```bash
# 로컬
./gradlew test                                        # 기존 테스트 + 새 쿠키 설정 테스트
docker build -t tadak-live:local .                    # 이미지 빌드 확인(로컬은 arm64 Mac이라 VM과 같은 아키텍처)
TADAK_DEPLOY_KEY=~/.ssh/tadak_deploy deploy/oci/provision.sh   # VM에 deploy 사용자·키 등록(재실행 안전)
deploy/oci/verify.sh --app                            # 배포 후 외부 확인(아래 Success Criteria)

# GitHub 설정(사용자가 직접 실행, 값은 프롬프트에 붙여 넣거나 파일에서 읽음 — 채팅에 붙이지 않음)
gh secret set VM_SSH_KEY < ~/.ssh/tadak_deploy
gh secret set TOSS_CLIENT_KEY
gh secret set TOSS_SECRET_KEY
gh variable set TADAK_HOST --body "<공인IP 대시 표기>.sslip.io"
gh variable set VM_SSH_KNOWN_HOSTS --body "$(ssh-keyscan -t ed25519 <공인IP>)"

# 배포는 main 푸시로. 수동 재배포는
gh workflow run deploy.yml
```

## Project Structure

```
.github/workflows/ci.yml         → (기존) 모든 브랜치·PR 테스트. 바꾸지 않음
.github/workflows/deploy.yml     → main 푸시·수동 실행: test → ARM64 이미지 빌드·푸시 → VM 배포
deploy/vm/compose.yaml           → app 서비스 추가(이미지는 .env 의 TADAK_IMAGE, 볼륨 tadak_data:/data, 포트 없음)
deploy/vm/Caddyfile              → respond 를 reverse_proxy app:8080 으로
deploy/vm/deploy.sh              → VM에서 실행: 이미지 받기 → 태그 교체 → up -d → 헬스 확인 → 실패 시 되돌림
deploy/oci/provision.sh          → deploy 사용자와 CI 공개 키 등록 단계 추가
deploy/oci/verify.sh             → --app 모드: 앱 응답·헬스·actuator 차단·쿠키 Secure 확인
src/main/resources/application.properties → CHZZK_COOKIE_SECURE 한 줄
src/test/java/.../SessionCookieSecureTest.java → 새 테스트
README.md                        → 공개 주소, VM shape와 선택 이유, 배포 방법, 새 환경변수
.env.example                     → CHZZK_COOKIE_SECURE 예시
```

VM 안: `/opt/tadak/{compose.yaml,caddy/Caddyfile,.env,deploy.sh}`, Docker 볼륨 `tadak_data`(H2 DB·영상), `caddy_data`.

## Code Style

워크플로는 기존 `ci.yml` 처럼 단계 이름을 한국어로 쓴다. VM 스크립트는 `deploy/oci/*.sh` 와 같은 규칙(`set -euo pipefail`, `==> ` 단계 출력, macOS·Linux bash 모두 고려).

```yaml
  deploy:
    needs: image
    runs-on: ubuntu-latest
    concurrency: { group: deploy-vm, cancel-in-progress: false }
    steps:
      - name: VM에 설정 올리기
        run: scp -i ~/.ssh/deploy_key deploy/vm/compose.yaml deploy/vm/Caddyfile deploy/vm/deploy.sh "deploy@${{ vars.TADAK_HOST }}:/opt/tadak/"
      - name: 새 이미지로 교체
        run: ssh -i ~/.ssh/deploy_key "deploy@${{ vars.TADAK_HOST }}" "/opt/tadak/deploy.sh ghcr.io/zoek1211/tadak-live:${{ github.sha }}"
```

- 비밀 값은 `env:` 로 넘기고 명령 줄에 직접 쓰지 않는다(로그 노출 방지). `.env` 는 VM 쪽에서 표준 입력으로 받아 쓴다.
- 이미지 이름·태그는 한 곳(워크플로 `env`)에서 정한다.

## Testing Strategy

- **단위·통합(JUnit, 기존 방식):** `SessionCookieSecureTest` — `CHZZK_COOKIE_SECURE=true` 일 때 로그인 응답의 `JSESSIONID` 에 `Secure` 가 붙고, 기본값에선 안 붙는다. 기존 `ActuatorHealthTest` 는 그대로 통과해야 한다. 테스트는 `./data` 를 건드리지 않는 기존 규칙을 따른다.
- **정적:** `shellcheck deploy/oci/*.sh deploy/vm/deploy.sh`. 워크플로는 `actionlint` 로 확인(로컬 도구, `brew install actionlint`).
- **이미지:** 로컬 `docker build` 성공, 컨테이너가 `/data` 볼륨으로 뜨고 `/actuator/health` 가 `UP`.
- **배포(실제):** `main` 에 합친 뒤 Actions의 deploy 작업 성공, 그다음 `verify.sh --app` 통과. 되돌림은 존재하지 않는 이미지 태그로 `deploy.sh` 를 직접 실행해 이전 이미지로 돌아오는지 한 번 확인한다.
- **수동(사용자와 함께):** 브라우저로 회원가입·로그인, 녹화방송 업로드·재생, 댓글, 토스 테스트 후원 한 건.

## Boundaries

- **Always:** 배포 전에 테스트 통과(`needs: test`), 이미지 태그는 커밋 SHA, 배포 후 헬스 확인, 비밀 값은 Secret·`env:` 로만, VM `.env` 권한 600.
- **Ask first:** Secret·변수 추가·변경(사용자가 직접 입력), 앱 코드의 설정 외 변경, 새 Gradle 의존성, `ci.yml` 변경, VM 데이터 볼륨(`tadak_data`)을 지우거나 옮기는 일, 메모리 한도·JVM 옵션 변경, 첫 실제 배포 실행.
- **Never:** 비밀 값·SSH 비밀 키·`.env` 커밋, 비밀 값을 채팅·로그·이슈에 출력, 앱 포트(8080)를 인터넷에 여는 일, `tadak_data` 삭제, 사용자 대신 토스 키 입력, `zoek1211/chzzk` 저장소 수정.

## Success Criteria

1. `main` 에 푸시하면 deploy 워크플로가 test → image → deploy 순서로 성공한다. 테스트가 실패하면 이미지·배포 단계가 돌지 않는다.
2. GHCR에 `ghcr.io/zoek1211/tadak-live:<커밋 SHA>` (linux/arm64) 이미지가 있다.
3. `https://<host>/` 가 200이고 방송 목록 화면(타닥 라이브 제목)을 낸다. `https://<host>/actuator/health` 가 `{"status":"UP"}`, `/actuator/env` 는 404.
4. 외부에서 8080 연결이 안 되고, 열린 포트는 여전히 22/80/443뿐이다.
5. HTTPS 로그인 응답의 `JSESSIONID` 쿠키에 `Secure` 가 붙는다.
6. 브라우저에서 회원가입·로그인, 녹화방송 업로드(수백 MB 영상 하나)·재생, 댓글 작성이 된다.
7. 토스 테스트 키를 넣으면 후원 결제창이 뜨고, 테스트 결제 후 성공 화면이 `https://<host>/donations/success` 로 돌아온다.
8. 재배포(빈 커밋 푸시 또는 `gh workflow run`) 뒤에도 회원·방송·댓글·영상이 남아 있다(`tadak_data` 볼륨 유지).
9. 존재하지 않는 이미지로 배포하면 이전 이미지로 되돌아가 서비스가 계속 되고, 배포는 실패로 표시된다.
10. 저장소·Actions 로그·이슈에 비밀 값이 없다. 비밀 키는 이 Mac과 GitHub Secret에만 있다.
11. README에 공개 주소, VM shape(A1 2 OCPU·12GB)와 선택 이유, 배포 방법, 새 환경변수가 있고 코드와 맞는다.

## Out of Scope (Deferred)

- `GET /api/broadcasts` → `broadcast-api`
- 다운로드 페이지 → `download-page`
- `zoek.im` → `custom-domain`
- TURN 서버 운영 → V2. 무료 범위에서 VM에 coturn을 같이 띄울 수 있지만 UDP 포트 범위를 열어야 해서 따로 판단
- DB·영상 백업 → V2(Object Storage 무료 20GB 후보)
- 무중단 배포(두 컨테이너 교대) → V2
- 모니터링·알림, 로그 수집 → V2
- rpcbind(111) 끄기 등 VM 하드닝 → 외부에서 이미 닫혀 있어 V2
- Postgres 전환 → 단독 모드 H2로 충분, 필요해지면 delta spec

## Decisions (2026-11-22, 기본값으로 승인)

1. **GHCR 패키지는 비공개 유지.** 배포 작업이 `GITHUB_TOKEN` 으로 로그인해 받는다(가정 5).
2. **배포 승인 단계 없음.** `main` 푸시(테스트 통과)마다 바로 배포한다.
3. **토스 테스트 키가 없으면** 완료 기준 7번(후원)만 키를 넣은 뒤로 미루고 나머지로 완료 처리한다.

## Open Questions

없음.
