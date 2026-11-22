# Implementation Plan: vm-host

Source spec: `SPEC-vm-host.md` · 모듈 지도: `CAPABILITY-MAP.md`

**상태: 완료(2026-11-22).** #2~#7 모두 닫힘, 스펙 완료 기준 1~9 통과(#7). 작업은 GitHub Issues(`zoek1211/tadak-live`)에서 관리한다. 부모 이슈 #1 아래 하위 이슈이고, 순서는 GitHub의 차단(blocked-by) 관계로 걸려 있다. 작업 내용·완료 조건은 각 이슈가 기준이다.

## Overview

로컬 Mac에서 OCI CLI 스크립트로 Always Free VM 한 대를 만들고, VM의 Docker Compose 위 Caddy가 `https://<공인IP>.sslip.io` 에 Let's Encrypt 인증서로 `tadak vm ok` 를 응답하게 한다. 위험이 큰 일(무료 재고·한도 확인)을 맨 앞에 둔다.

## Architecture Decisions

- **cloud-init은 처음 한 번만, 설정 배포는 SSH로.** cloud-init은 Docker 설치와 OS 방화벽만 맡는다. `deploy/vm/` 의 compose.yaml·Caddyfile은 `provision.sh` 가 매번 scp로 올리고 `docker compose up -d` 한다. 그래야 `backend-deploy` 가 같은 경로로 설정을 바꿀 수 있고 재실행이 설정 변경을 반영한다.
- **Ubuntu OCI 이미지의 iptables.** OCI Ubuntu 이미지는 보안 목록과 별개로 `/etc/iptables/rules.v4` 에 REJECT 규칙이 있다. cloud-init에서 80/443 ACCEPT를 REJECT 앞에 넣고 `netfilter-persistent save` 한다(보안 목록만 열면 접속이 안 됨).
- **재실행 안전.** 모든 자원은 `tadak-` 이름 + `project=tadak-live` 태그로 찾아 있으면 재사용한다.
- **인증서는 스테이징 먼저.** Caddyfile의 CA를 환경변수로 바꿀 수 있게 하고, 처음엔 스테이징으로 발급 경로를 확인한 뒤 운영 CA로 바꾼다.
- **로컬 도구:** `oci-cli`, `jq`, `shellcheck` 를 Homebrew로 설치한다. 저장소 의존성은 늘지 않는다.

## Task List

| 순서 | 이슈 | 작업 | 차단하는 이슈 | 라벨 |
|---|---|---|---|---|
| 1 | #2 | OCI 로그인과 Pay As You Go 전환 (사용자) | — | ready-for-human |
| 2 | #3 | 읽기 전용 점검 `preflight.sh` | #2 | ready-for-agent |
| 3 | #4 | 과금 감시 `budget.sh` | #2 | ready-for-agent |
| — | | **Checkpoint 계정과 한도:** preflight 결과로 shape(A1/E2)와 공인 IP 방식 확정, 예산 알림 확인 | | |
| 4 | #5 | 네트워크와 인스턴스 생성 `provision.sh` | #3, #4 | ready-for-agent |
| 5 | #6 | Caddy HTTPS와 외부 확인 `verify.sh` | #5 | ready-for-agent |
| — | | **Checkpoint HTTPS:** 브라우저로 경고 없이 `tadak vm ok` | | |
| 6 | #7 | 재부팅·포트·비용·저장소 점검 | #6 | ready-for-agent |
| — | | **Checkpoint 완료:** 스펙 완료 기준 1~9 통과, 사용자 검토 후 `SPEC-vm-host.md` Status를 implemented로 | | |

## 병렬 가능

- #3과 #4는 서로 독립(둘 다 #2만 필요).
- `broadcast-api` 모듈은 이 계획 전체와 독립이라 따로 진행할 수 있다(별도 스펙 필요).

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| A1 재고 부족(인기 리전에서 흔함) | High | #3에서 먼저 확인, 6회 재시도 후 E2.1.Micro. E2는 1GB 메모리라 `backend-deploy` 에서 JVM 메모리 설정을 줄여야 함 |
| Ubuntu 이미지 iptables가 80/443 차단 | Med | cloud-init에서 규칙 추가, `verify.sh` 로 확인 |
| Let's Encrypt 발급 한도 | Med | 스테이징 CA로 먼저 확인, 운영 발급은 한 번 |
| 세션 토큰 1시간 만료(재시도 루프 중) | Low | `oci session refresh`, 실패 시 재로그인 안내 후 종료(재실행 안전) |
| 실수로 유료 자원 생성(PAYG 계정) | Med | #4 예산 알림을 #5보다 먼저, 스크립트는 Always Free shape만 허용 |
| sslip.io 장애 | Low | 임시 주소일 뿐, `custom-domain` 에서 자체 도메인으로 대체 |

## Open Questions

- 없음. shape와 공인 IP 방식은 Checkpoint "계정과 한도"에서 preflight 결과로 정한다.
