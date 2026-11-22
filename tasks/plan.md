# Implementation Plan: download-page

Source spec: `SPEC-download-page.md` · 모듈 지도: `CAPABILITY-MAP.md` · 이전 모듈 계획: `tasks/plan-vm-host.md`, `tasks/plan-backend-deploy.md`, `tasks/plan-broadcast-api.md`, `tasks/plan-desktop-app.md`

작업은 GitHub Issues에서 관리한다. 부모 이슈 #40 아래 하위 이슈이고, 순서는 차단(blocked-by) 관계로 걸려 있다. 작업 내용·완료 조건은 각 이슈가 기준이다.

## Overview

새 `download` 패키지에 `/download` 페이지(컨트롤러·설정 바인딩·템플릿)를 먼저 세우고, 그다음 사이트 머리글 링크와 OS 추천 표시를 붙인다. 문서·배포 확인으로 닫는다. 작은 모듈이라 작업 네 개다. 모든 작업은 테스트를 먼저 쓴다.

## Architecture Decisions

- **다운로드 주소는 `DesktopDownloads`(설정 `chzzk.desktop.download-base` 바인딩)가 만든다.** 파일 이름은 데스크톱 워크플로와 같은 상수(`Tadak-Live-windows-x64-setup.exe`, `Tadak-Live-macos-universal.dmg`). Releases 목록 주소는 기본값에서 `/latest/download` 를 뗀 값이 아니라 별도 설정 없이 `…/releases` 로 계산(기본값 기준). 템플릿은 이 객체 값만 쓴다.
- **페이지는 기존 레이아웃 조각(`fragments/layout :: head/header`)을 쓰는 Thymeleaf 템플릿.**
- **OS 추천 표시는 템플릿 안 작은 인라인 스크립트**(기존 화면의 스크립트 방식에 맞춤). 서버는 User-Agent를 보지 않는다.

## Task List

| 순서 | 이슈 | 작업 | 차단하는 이슈 |
|---|---|---|---|
| 1 | #41 | /download 페이지 | — |
| 2 | #42 | 머리글 '앱 받기'와 OS 추천 표시 | #41 |
| — | | **Checkpoint 로컬:** `/download` 와 머리글 확인 | |
| 3 | #43 | README·.env.example·verify.sh --app | #41, #42 |
| 4 | #44 | 병합·배포 후 공개 주소 확인 | #43 |
| — | | **Checkpoint 완료:** 완료 기준 1~11, 사용자 검토 후 Status implemented | |

모든 작업 라벨은 `ready-for-agent`.

## 병렬 가능

- 작업이 서로 이어져 있어 순서대로 한다(모두 같은 템플릿·CSS를 건드림).

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| 머리글 버튼이 늘어 휴대폰 화면에서 넘침 | Low | 기존 `header-actions` 줄바꿈(`flex-wrap`) 확인, 필요하면 작은 버튼 스타일 |
| 기존 화면 테스트가 머리글 HTML을 통째로 비교 | Low | #42에서 함께 맞춤 |
| OS 화면 문구가 OS 버전마다 다름 | Low | macOS 15·Windows 11 기준 문구로 쓰고 "비슷한 문구"로 안내 |
| Release 파일 이름이 바뀌면 링크가 깨짐 | Med | 이름은 상수 한 곳 + 데스크톱 워크플로와 같이 바꾸기는 Ask first, `verify.sh` 가 링크를 확인 |

## Open Questions

- 없음.
