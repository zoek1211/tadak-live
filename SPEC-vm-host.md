# Spec: vm-host — V1

Status: implemented (2026-11-22) · 모듈 지도: `CAPABILITY-MAP.md` · 의도: `docs/intent/oci-deploy.md`

## Objective

OCI Always Free VM 한 대를 만들고 `https://<공인IP>.sslip.io` 에서 신뢰받는 Let's Encrypt 인증서로 응답하게 한다. 이 모듈이 끝나면 `backend-deploy` 는 VM에 컨테이너를 올리고 Caddy 설정만 바꾸면 된다.

사용자: 이 저장소 주인(운영자). OCI 로그인·동의만 직접 하고 나머지는 스크립트가 한다.

이 모듈에서는 앱을 띄우지 않는다. Caddy는 고정 문구(`tadak vm ok`)로 응답한다.

## 가정

1. OCI CLI가 없으므로 Homebrew로 설치한다(`brew install oci-cli`). 로컬 도구라 저장소 의존성은 늘지 않는다.
2. 인증은 `oci session authenticate`(브라우저 로그인, 토큰 1시간)를 쓴다. API 서명 키를 만들어 저장하지 않는다.
3. VM 관리용 SSH 키는 이 작업 전용으로 새로 만든다: `~/.ssh/tadak_oci` (ed25519). 비밀 키는 이 Mac에만 있다. CI 배포용 키는 `backend-deploy` 가 따로 만든다.
4. OS 이미지는 Canonical Ubuntu 24.04 (A1이면 aarch64, E2.1.Micro면 x86_64).
5. **공인 IP는 예약(reserved) IP를 쓴다** (2026-11-22 Checkpoint 결정). 인스턴스를 다시 만들어도 `<IP>.sslip.io` 주소가 유지된다. preflight 결과 Oracle 공개 가격표에 공인 IP 품목이 없어 과금 대상이 아닌 것으로 판단했다.
6. **shape는 `VM.Standard.A1.Flex` 2 OCPU·12GB** (같은 Checkpoint 결정). 무료 한도 4 OCPU·24GB가 모두 남아 있었다. 재고 부족이면 6회 재시도 후 E2.1.Micro.
7. 프로비저닝은 Terraform이 아니라 OCI CLI 셸 스크립트 + cloud-init 으로 한다. 자원이 VCN 하나·인스턴스 하나뿐이라 상태 파일을 관리할 이유가 작고, 기존 `scripts/*.sh` 방식과 맞는다.
8. **계정은 Pay As You Go로 바꾸되 Always Free 한도 안 자원만 쓴다** (2026-11-22 사용자 결정). 유휴 인스턴스 회수를 피하기 위해서다. 전환은 사용자가 OCI 콘솔에서 직접 한다(결제 수단 등록, 카드 임시 승인이 있을 수 있음). 실수로 과금되는 것을 잡으려고 OCI 예산(Budget)과 알림을 만든다. 예산 기능 자체는 무료다.
9. Caddy와 앞으로의 앱은 VM에서 Docker Compose로 함께 돌린다. Caddy만 80/443을 열고 앱 포트(8080)는 외부에 열지 않는다.

## Tech Stack

- OCI CLI (Homebrew 최신), `jq`, `ssh`, `curl`, `openssl` (모두 로컬)
- VM: Ubuntu 24.04, Docker Engine + Compose 플러그인(공식 apt 저장소), Caddy 2 공식 이미지(`caddy:2`)
- 주소: sslip.io (`<a-b-c-d>.sslip.io` 대시 표기)

## Commands

```bash
brew install oci-cli jq
oci session authenticate --region <홈 리전> --profile-name tadak   # 사용자가 브라우저에서 로그인
deploy/oci/preflight.sh      # 홈 리전, A1·E2 무료 한도와 남은 양, 이미지 OCID 확인. 아무것도 만들지 않음
TADAK_BUDGET_EMAIL=<알림 받을 주소> deploy/oci/budget.sh   # 월 예산 1 USD, 실제 사용액이 0.01 USD 넘으면 메일 알림(있으면 재사용)
deploy/oci/provision.sh      # VCN·서브넷·인터넷 게이트웨이·보안 목록·인스턴스 생성(있으면 재사용), cloud-init 주입
deploy/oci/verify.sh         # 외부에서 HTTPS·인증서·포트 확인
ssh -i ~/.ssh/tadak_oci ubuntu@<공인IP>
```

`provision.sh` 는 다시 실행해도 같은 결과가 나와야 한다(이름으로 기존 자원을 찾아 재사용).

## Project Structure

```
deploy/oci/preflight.sh        → 읽기 전용 점검
deploy/oci/budget.sh           → 예산·과금 알림 생성
deploy/oci/provision.sh        → 자원 생성, 결과를 deploy/oci/.state.env 에 기록
deploy/oci/verify.sh           → 외부 확인
deploy/oci/cloud-init.yaml     → Docker 설치, OS 방화벽 80/443 개방, /opt/tadak 준비
deploy/vm/compose.yaml         → VM에서 돌릴 Compose (이 모듈에서는 caddy 서비스만)
deploy/vm/Caddyfile            → {$TADAK_HOST} 사이트 블록, 이 모듈에서는 고정 문구 응답
deploy/oci/.state.env          → 리전·OCID·공인 IP (gitignore, 커밋 안 함)
```

VM 안 경로: `/opt/tadak/` (compose.yaml, Caddyfile, `.env` 는 권한 600), Caddy 인증서는 Docker 볼륨 `caddy_data`.

## Code Style

기존 `scripts/cluster-up.sh` 와 같게 쓴다.

```bash
#!/usr/bin/env bash
# OCI 자원 생성(있으면 재사용) -> 인스턴스 -> 공인 IP 기록.
# 필요 도구: oci, jq. 인증: oci session authenticate --profile-name tadak
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${OCI_PROFILE:-tadak}"

for tool in oci jq; do
  command -v "$tool" >/dev/null || { echo "필요한 도구가 없습니다: $tool" >&2; exit 1; }
done

echo "==> VCN 'tadak-vcn' 확인"
```

- 주석과 출력은 한국어, 단계마다 `==> ` 로 시작하는 한 줄.
- 자원 이름 접두사는 `tadak-`, 모든 자원에 freeform 태그 `project=tadak-live`.
- OCID·IP를 스크립트에 하드코딩하지 않는다.

## Testing Strategy

인프라라서 단위 테스트는 없고, 스크립트로 확인한다.

- **정적:** 로컬에서 `shellcheck deploy/oci/*.sh` 통과.
- **동작:** `verify.sh` 가 다음을 모두 확인하고 하나라도 실패하면 종료 코드 1.
  - `curl -fsS https://<host>/` 가 200과 `tadak vm ok`
  - 인증서 발급자가 Let's Encrypt 운영 CA(스테이징 아님), SAN에 `<host>` 포함
  - `http://<host>/` 가 `https://` 로 리다이렉트
  - 외부에서 8080 연결 실패
- **재실행:** `provision.sh` 를 두 번 실행해 두 번째에 새 자원이 생기지 않음(`oci search` 로 `project=tadak-live` 태그 자원 수 비교).

Let's Encrypt 발급 한도를 아끼려고 처음 발급은 스테이징 CA로 확인한 뒤 운영 CA로 바꾼다.

## Boundaries

- **Always:** 만들기 전에 `preflight.sh` 로 무료 한도를 확인한다. Always Free 대상 shape·스토리지만 쓴다. 비밀 값과 OCID는 커밋하지 않는다.
- **Ask first:** 무료 한도를 넘는 자원(Pay As You Go 계정이라 실제로 과금된다), 예산 금액·알림 기준 변경, 기존(이 작업이 만들지 않은) OCI 자원을 바꾸거나 지우는 일, 인스턴스 종료(공인 IP가 바뀐다), CI 설정 변경.
- **Never:** 비밀 키·세션 토큰·`.state.env` 커밋, 22·80·443 외 포트를 인터넷에 여는 일, `zoek1211/chzzk` 저장소 수정, 사용자 대신 OCI 로그인·약관 동의·결제 수단 등록·계정 등급 변경, 예산 알림 주소를 커밋.

## Success Criteria

1. `preflight.sh` 가 홈 리전, A1 OCPU·메모리 남은 양, E2.1.Micro 남은 수를 출력한다.
2. VM이 Always Free shape로 실행 중이다. A1이 아니면 그 이유(재고 부족 오류 원문 또는 한도 부족)가 `deploy/oci/.state.env` 와 작업 기록에 남아 있다. README 반영은 `backend-deploy` 에서 한다.
3. `deploy/oci/verify.sh` 가 종료 코드 0으로 끝난다(위 네 가지 확인).
4. `provision.sh` 재실행이 새 자원을 만들지 않는다.
5. 인터넷에 열린 포트는 22, 80, 443뿐이다(보안 목록과 VM 방화벽 둘 다).
6. VM 재부팅 뒤에도 Caddy가 자동으로 다시 떠서 3번이 통과한다.
7. 저장소에 OCID·IP·키가 들어 있지 않다(`git grep -E 'ocid1\.|BEGIN OPENSSH'` 결과 없음).
8. 계정이 Pay As You Go이고(`preflight.sh` 가 계정 등급 출력), 테넌시에 예산과 과금 알림 규칙이 있다(`oci budgets budget list` 로 확인).
9. 만든 자원이 모두 Always Free 대상이다: 인스턴스 shape, 부트 볼륨 합계 200GB 이하, VCN·인터넷 게이트웨이(무료). 콘솔 비용 분석에서 이번 달 사용액 0.

## Out of Scope (Deferred)

- 앱 컨테이너 실행, 환경변수·비밀 값 주입, CI 배포 키 → `backend-deploy`
- `zoek.im` DNS·인증서 → `custom-domain`
- Terraform 등 IaC 도구 도입 → 자원 두 개에는 과함
- 모니터링·알림, 백업 → V2 (VM 한 대·무료 범위 밖 서비스가 필요할 수 있음)
- SSH 포트 제한(내 IP만) → 사용자 IP가 바뀌고 CI가 SSH로 배포하므로 `backend-deploy` 에서 다시 판단

## Open Questions

없음. 예약 IP와 A1 재고 부족 시 재시도(6회 후 E2.1.Micro)는 2026-11-22 Checkpoint에서 확정해 가정 5·6에 반영했다.
