# Implementation Plan: backend-deploy

Source spec: `SPEC-backend-deploy.md` · 모듈 지도: `CAPABILITY-MAP.md` · 이전 모듈 계획: `tasks/plan-vm-host.md`

작업은 GitHub Issues에서 관리한다. 부모 이슈 #9 아래 하위 이슈이고, 순서는 차단(blocked-by) 관계로 걸려 있다. 작업 내용·완료 조건은 각 이슈가 기준이다.

## Overview

앱 설정 한 줄(쿠키 Secure)을 더하고, VM에 CI 전용 `deploy` 사용자를 만들고, Compose에 앱을 붙여 **로컬에서 만든 이미지로 먼저 손 배포**해 VM 쪽 경로(`deploy.sh`, Caddy 프록시, 볼륨, 되돌림)를 검증한다. 그다음 같은 `deploy.sh` 를 호출하는 Actions 워크플로를 붙여 `main` 푸시 자동 배포로 바꾼다. 위험이 큰 VM 쪽 경로를 CI보다 먼저 확인해서, 워크플로 디버깅이 "푸시하고 기다리기"의 반복이 되지 않게 한다.

## Architecture Decisions

- **VM 배포 로직은 `deploy/vm/deploy.sh` 한 곳.** 손 배포와 CI 배포가 같은 스크립트를 부른다. 워크플로는 파일을 올리고 `deploy.sh <이미지>` 를 호출할 뿐이다.
- **`deploy.sh` 계약:** 인자로 이미지 참조를 받는다. 표준 입력이 있으면 앱 비밀 값 줄(`TOSS_*`, `CHZZK_TURN_*`)로 보고 `.env` 의 해당 줄만 바꾼다(`TADAK_HOST`·`TADAK_ACME_CA` 는 유지). 레지스트리 로그인은 호출하는 쪽(CI)이 미리 한다. 순서: 이전 `TADAK_IMAGE` 기록 → 새 이미지 `docker pull`(로컬에 있으면 생략) → `.env` 갱신 → `docker compose up -d` → `caddy reload` → 헬스 대기(2분) → 실패 시 이전 이미지로 되돌리고 종료 코드 1.
- **헬스 확인은 VM 안에서.** `docker compose exec app` 대신 Caddy를 거쳐 `https://$TADAK_HOST/actuator/health` 를 VM에서 호출한다(JRE 이미지에 curl이 있다고 가정하지 않음, 외부 경로 전체를 확인).
- **손 배포 이미지 전달:** 로컬 Mac(arm64)에서 `docker build` → `docker save | ssh ... docker load`. 레지스트리 없이 VM 경로를 검증한다.
- **CI 워크플로는 `ci.yml` 과 별도(`deploy.yml`).** `ci.yml` 은 바꾸지 않는다(Boundaries). `deploy.yml` 안에서 test 작업을 다시 돌린다.

## Task List

| 순서 | 이슈 | 작업 | 차단하는 이슈 | 라벨 |
|---|---|---|---|---|
| 1 | #10 | 세션 쿠키 Secure 설정 | — | ready-for-agent |
| 2 | #11 | VM `deploy` 사용자와 CI 전용 키 | — | ready-for-agent |
| 3 | #12 | GitHub Secrets·변수 입력 (사용자) | #11 | ready-for-human |
| 4 | #13 | Compose 앱·Caddy 프록시·`deploy.sh` 로 첫 배포 | #10, #11 | ready-for-agent |
| — | | **Checkpoint 손 배포:** 브라우저로 로그인·업로드·재생 확인 | | |
| 5 | #14 | `deploy.yml` 워크플로 | #12, #13 | ready-for-agent |
| 6 | #15 | README와 `.env.example` | #13 | ready-for-agent |
| 7 | #16 | 재배포·후원·비밀 값 점검 | #14, #15 | ready-for-agent |
| — | | **Checkpoint 완료:** 스펙 완료 기준 1~11, 사용자 검토 후 Status implemented | | |

## 병렬 가능

- #10, #11은 서로 독립. #12는 #11 뒤 언제든(사용자).
- #15는 #13 뒤 #14와 병렬.
- `broadcast-api` 모듈은 이 계획과 독립(별도 스펙).

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Caddy 뒤에서 쿠키·리다이렉트 URL이 http로 나옴 | Med | #10 Secure 설정, `verify.sh --app` 이 쿠키·토스 리다이렉트 기준 확인 |
| 첫 배포에서 H2 파일 권한 문제(비루트 uid 10001과 볼륨) | Med | Dockerfile이 `/data` 를 10001 소유로 만든다. 새 이름 볼륨은 이미지 경로 소유권을 따른다. #13에서 확인 |
| ARM 러너 대기·실패 | Low | 공개 저장소 무료 러너. 실패 시 QEMU(`setup-qemu-action`)로 x86 러너에서 빌드하는 대안 |
| 배포 작업이 비밀 값을 로그에 찍음 | High | `env:` 로만 전달, VM 쪽은 표준 입력으로 받기, `set -x` 금지, #16에서 로그 검색 |
| 잘못된 이미지로 서비스 중단 | Med | `deploy.sh` 헬스 실패 시 자동 되돌림, #13에서 실제로 시험 |
| `main` 보호 규칙의 필수 검사 `test` 가 deploy.yml의 `test` 와 이름이 겹침 | Low | 둘 다 같은 커밋 테스트라 의미가 같다. 혼동되면 deploy.yml 작업 이름을 `deploy-test` 로 |
| H2 단일 파일에 쌓인 데이터 유실(VM 장애) | Med | 이번 범위 밖(백업은 V2). README에 백업 없음 명시 |

## Open Questions

- 없음.
