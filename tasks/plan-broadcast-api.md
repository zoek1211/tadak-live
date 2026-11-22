# Implementation Plan: broadcast-api

Source spec: `SPEC-broadcast-api.md` · 모듈 지도: `CAPABILITY-MAP.md` · 이전 모듈 계획: `tasks/plan-vm-host.md`, `tasks/plan-backend-deploy.md`

**상태: 완료(2026-11-22).** #21~#26 모두 닫힘, 스펙 완료 기준 1~10 통과(#26). 작업은 GitHub Issues에서 관리한다. 부모 이슈 #20 아래 하위 이슈이고, 순서는 차단(blocked-by) 관계로 걸려 있다. 작업 내용·완료 조건은 각 이슈가 기준이다.

## Overview

`list` 패키지에 `BroadcastListApiController` 를 새로 두고, 기존 서비스의 목록 메서드로 계약(JSON)을 만든다. 먼저 녹화·라이브 기본 필드와 절대 주소로 계약의 뼈대를 세우고(가장 많은 결정이 모인 곳), 그다음 시청자 수·CORS·영상 Range를 각각 독립 조각으로 더한다. 마지막에 문서·배포 확인으로 닫는다. 모든 작업은 테스트를 먼저 쓴다.

## Architecture Decisions

- **응답은 컨트롤러 안 `record` 로 명시한다.** 엔티티를 직접 직렬화하지 않아 회원 id 같은 필드가 실수로 나가지 않는다.
- **절대 주소는 요청 기준 `ServletUriComponentsBuilder.fromCurrentContextPath()`.** `forward-headers-strategy=framework` 가 Caddy 뒤에서 `https` 공개 주소로 바꾼다. 주소를 설정값으로 두지 않는다.
- **시청자 수는 `live` 패키지가 답한다.** `LiveBroadcastService` 에 "이 라이브의 지금 시청자 수"를 묻는 메서드를 두고(`LiveRooms.viewerIds(id).size()`), 컨트롤러는 그 값을 옮기기만 한다(CODING_STANDARDS 모듈 경계). 정원은 `chzzk.live.viewer-capacity` 를 같은 서비스가 노출한다.
- **CORS는 `SecurityConfig` 의 `cors()` + `/api/**` 한정 `CorsConfigurationSource`.** 다른 경로는 CORS 설정이 없어 헤더가 붙지 않는다. `allowCredentials(false)`.
- **영상 Range는 기존 동작을 테스트로 못박는다.** 실패하면 `VideoController` 를 고친다.

## Task List

| 순서 | 이슈 | 작업 | 차단하는 이슈 |
|---|---|---|---|
| 1 | #21 | `GET /api/broadcasts` 기본 필드와 절대 주소 | — |
| 2 | #22 | 라이브 시청자 수 | #21 |
| 3 | #23 | `/api/**` CORS | #21 |
| 4 | #24 | 업로드 영상 Range 요청 | — |
| — | | **Checkpoint 로컬:** 전체 테스트, `curl localhost:8080/api/broadcasts` | |
| 5 | #25 | README API 절과 `verify.sh --app` | #21, #22, #23 |
| 6 | #26 | 병합·배포 후 공개 주소 확인 | #24, #25 |
| — | | **Checkpoint 완료:** 완료 기준 1~10, 사용자 검토 후 Status implemented | |

모든 작업 라벨은 `ready-for-agent`.

## 병렬 가능

- #22, #23은 #21 뒤 서로 독립. #24는 처음부터 독립.
- 디자인 적용 PR #19(화면 템플릿)와 파일이 겹치지 않는다. 겹칠 수 있는 곳은 README 정도라 병합 순서만 맞추면 된다.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 프록시 뒤에서 절대 주소가 `http` 로 나옴 | High(데스크톱 재생 실패) | #21 테스트가 `X-Forwarded-*` 로 확인, #26에서 공개 주소로 재확인 |
| CORS 설정이 기존 보안 체인을 바꿈 | Med | `/api/**` 한정, #23에서 기존 보안 테스트 전체 통과 확인 |
| 시청자 수가 클러스터 모드에서 다름 | Low | `LiveRooms` 인터페이스로만 묻는다(단독·Redis 구현 모두). 클러스터 테스트는 기존 것으로 회귀 확인 |
| 응답 필드가 나중에 바뀌어 클라이언트가 깨짐 | Med | 계약을 README·스펙에 고정, 바꾸기는 Ask first |

## Open Questions

- 없음.
