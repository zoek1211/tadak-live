# Implementation Plan: desktop-app

Source spec: `SPEC-desktop-app.md` · 모듈 지도: `CAPABILITY-MAP.md` · 이전 모듈 계획: `tasks/plan-vm-host.md`, `tasks/plan-backend-deploy.md`, `tasks/plan-broadcast-api.md`

**상태: 완료(2026-11-22).** #30~#37 모두 닫힘, 스펙 완료 기준 11개 중 10개 통과·9번(Windows 실기기) 보류(#37). 첫 Release desktop-v0.1.3. 작업은 GitHub Issues에서 관리한다. 부모 이슈 #29 아래 하위 이슈이고, 순서는 차단(blocked-by) 관계로 걸려 있다. 작업 내용·완료 조건은 각 이슈가 기준이다.

## Overview

`desktop/` 에 Tauri 2 + 바닐라 TS 앱을 세우고, 공개 서버의 `/api/broadcasts` 로 목록 화면 → 녹화 플레이어 → 웹 창 순서로 한 조각씩 붙인다. 각 조각은 이 Mac에서 `pnpm tauri dev` 로 실제 서버를 보며 확인한다. 위험이 큰 "앱 안 웹 창(결제·IPC 차단)"을 CI·릴리스보다 먼저 확인한다. 마지막에 워크플로로 Windows·macOS 설치 파일을 만들어 Release에 올리고 실제 설치로 닫는다.

## Architecture Decisions

- **로직은 TS 모듈로 나누고 DOM은 얇게.** `api.ts`(검증·변환), `format.ts`(시각), `list.ts`(정리·그리기), `player.ts`, `web.ts`. 순수 함수는 Vitest로, 그리기는 jsdom으로 테스트한다. Rust(`src-tauri`)는 창 설정과 플러그인만 둔다.
- **화면 전환은 한 페이지 안 상태로.** 라우터 없이 `main.ts` 가 목록/플레이어를 바꾼다.
- **웹 창은 `@tauri-apps/api/webviewWindow` 의 `WebviewWindow`, 브라우저 열기는 `@tauri-apps/plugin-opener`.** 원격 출처에는 capability를 주지 않는다(로컬 앱 창 `main` 에만 opener·window 권한).
- **서버 주소는 `import.meta.env.VITE_TADAK_API_BASE`**(기본 공개 서버). 워크플로가 `vars.TADAK_HOST` 로 넣는다.
- **릴리스 파일 이름 고정:** 워크플로가 `tauri-action` 산출물을 `Tadak-Live-windows-x64-setup.exe`, `Tadak-Live-macos-universal.dmg` 로 바꿔 Release에 올린다.

## Task List

| 순서 | 이슈 | 작업 | 차단하는 이슈 |
|---|---|---|---|
| 1 | #30 | desktop/ Tauri 2 프로젝트 뼈대 | — |
| 2 | #31 | API 클라이언트와 목록 화면 | #30 |
| 3 | #32 | 녹화방송 플레이어 | #31 |
| 4 | #33 | 앱 안 웹 창과 브라우저 열기 | #31 |
| 5 | #34 | 타닥 브랜드(색·글꼴·로고·앱 아이콘) | #30 |
| — | | **Checkpoint 로컬 앱:** 사용자가 dev 창으로 목록·재생·웹 창 확인 | |
| 6 | #35 | desktop.yml 워크플로(PR 빌드, main 릴리스) | #31, #32, #33, #34 |
| 7 | #36 | README 데스크톱 앱 절 | #35 |
| 8 | #37 | 실제 설치 확인과 완료 기준 점검 | #36 |
| — | | **Checkpoint 완료:** 완료 기준 1~11, 사용자 검토 후 Status implemented | |

모든 작업 라벨은 `ready-for-agent`(4·8번은 사용자 확인이 함께 필요).

## 병렬 가능

- #31와 #34는 #30 뒤 서로 독립. #32·#33는 #31 뒤 서로 독립(같은 `list.ts`·`main.ts` 를 조금씩 건드리므로 순서대로 하는 편이 안전).
- 백엔드 변경이 없어 다른 작업과 겹치지 않는다.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 앱 안 웹 창에서 토스 결제 팝업 막힘 | Med | #33에서 CI 전에 직접 확인, 안 되면 "브라우저로 열기" 우회와 README 기록 |
| 원격 페이지에 Tauri IPC가 노출 | High | capabilities에 원격 출처 없음, #33에서 `window.__TAURI__` 없음 확인 |
| 유니버설 macOS 빌드 실패·느림 | Low | 실패 시 arm64·x64 두 파일로(스펙 결정 변경은 Ask first) |
| Windows 실기기 없음 | Med | CI 빌드 성공까지 확인, 9번 기준 보류 표시 |
| 첫 Release가 잘못된 파일로 공개 | Low | #35 첫 릴리스 전 사용자 확인, 잘못되면 Release 삭제는 Ask first |
| 앱만 바뀐 푸시도 백엔드 재배포 | Low | 같은 코드라 무해. 스펙 Out of Scope |

## Open Questions

- 없음.
