# Spec: desktop-app — V1

Status: approved (2026-11-22) · 모듈 지도: `CAPABILITY-MAP.md` · 의도: `docs/intent/oci-deploy.md`(B 방식: 자체 화면) · 쓰는 API: `SPEC-broadcast-api.md`(implemented)

## Objective

Windows·macOS용 **타닥 라이브 데스크톱 앱**을 만든다. 앱은 배포한 백엔드의 `GET /api/broadcasts` 로 방송 목록을 받아 **자기 화면에 그리고**, 녹화방송은 **앱 안 플레이어로 재생**한다. 라이브 시청·로그인·댓글·후원은 앱에서 해당 웹 화면을 연다. `main` 에 푸시하면 GitHub Actions가 설치 파일을 빌드해 GitHub Releases에 올린다.

사용자:
- **시청자(Windows x64, macOS Apple Silicon·Intel):** 설치하고 열면 방송 목록이 보이고, 녹화방송을 바로 재생하고, 라이브는 눌러서 본다.
- **운영자:** `main` 에 합치면 새 버전 설치 파일이 Releases에 생긴다. 다운로드 페이지(`download-page`)는 고정 주소로 최신 파일을 가리킨다.

## 가정

1. **Tauri 2 + 바닐라 TypeScript(Vite).** 의도 문서의 후보 그대로. 프런트엔드 프레임워크(React 등)는 쓰지 않는다. 화면이 목록·플레이어 두 개뿐이고 의존성을 줄이기 위해서다. 로컬에 Rust 1.99, Node 26, pnpm 12가 이미 있다.
2. **코드는 이 저장소 `desktop/`.** 백엔드 빌드(Gradle·Docker)와 섞이지 않게 `.dockerignore` 에 `desktop/` 을 더한다.
3. **서버 주소는 빌드할 때 정한다.** 기본값 `https://129-221-138-89.sslip.io`, 워크플로 변수 `TADAK_HOST` 로 주입(`VITE_TADAK_API_BASE`). 앱 안 설정 화면은 두지 않는다. `custom-domain` 으로 주소가 바뀌면 새 버전을 배포한다(자동 업데이트는 V2).
4. **화면은 두 개.**
   - **목록:** 웹 홈과 같은 두 줄 — "지금 타는 중"(방송 중 라이브, "불가에 N명"), "다시 보기"(녹화방송). 종료된 라이브는 API에는 있지만 앱에서는 숨긴다(볼 수 있는 게 없음). 30초마다, 그리고 창이 다시 앞으로 올 때 새로 불러온다. 서버에 닿지 않으면 한국어 안내와 "다시 시도" 버튼.
   - **녹화방송 플레이어:** HTML `<video>` 로 `playbackUrl` 재생(탐색은 서버의 Range 206), 제목·방송한 사람·등록 시각, "댓글·장작 넣기는 웹에서" 버튼.
5. **웹 화면은 앱 안 새 창으로 연다.** 라이브 카드나 "웹에서 열기"를 누르면 그 `watchUrl` 을 Tauri `WebviewWindow` 로 연다(의도 문서 "앱에서 웹 화면을 열어"). 로그인 세션은 그 창들끼리 공유되고 사용자 브라우저와는 따로다. 각 웹 창에 "브라우저로 열기"(기본 브라우저)를 둬서, 웹뷰에서 막히는 경우(아래 위험)를 우회한다.
6. **디자인은 웹과 같은 타닥 브랜드.** 색은 `app.css` 의 토큰(`--bg #16120f`, `--surface`, `--accent #ff7a2f`, `--ember #ffc56b` 등)을 그대로, 글꼴 Noto Sans KR, 불꽃 로고, 문구는 디자인 시안의 대응표(지금 타는 중·다시 보기·불가에 N명·장작 넣기)를 따른다. 글꼴은 앱에 넣는다(Google Fonts 요청 없이).
7. **보안:** 앱 화면(목록·플레이어)에는 원격 스크립트를 싣지 않는다. CSP는 `connect-src`·`media-src` 를 서버 주소와 외부 영상(`https:`)으로 제한. 원격 웹 창(`WebviewWindow`)에는 Tauri IPC(앱 명령)를 열지 않는다(capabilities에서 원격 출처 제외). API 응답의 사용자 글(제목·닉네임)은 `textContent` 로만 넣는다(CODING_STANDARDS).
8. **설치 파일:** Windows는 NSIS `.exe`(x64), macOS는 유니버설 `.dmg`(arm64+x64 한 파일). 코드 서명은 하지 않는다(유료). macOS는 **ad-hoc 서명**(`signingIdentity: "-"`)만 해서 Apple Silicon에서 "손상된 앱" 대신 "확인되지 않은 개발자" 경고가 뜨게 한다. 경고 우회 안내는 `download-page` 몫이고, 이 모듈은 README에 짧게 적는다.
9. **버전과 배포:** `main` 푸시마다 `desktop/**` 이 바뀌었을 때만 빌드한다(경로 필터). 버전은 `0.1.<워크플로 실행 번호>`. GitHub Release `desktop-v0.1.N` 을 만들고 "latest"로 표시한다. 다운로드 페이지가 고정 주소로 가리키도록 파일 이름을 고정한다: `Tadak-Live-windows-x64-setup.exe`, `Tadak-Live-macos-universal.dmg` → `https://github.com/zoek1211/tadak-live/releases/latest/download/<파일>`.
10. **PR에서는 빌드만 확인한다.** `desktop/**` 를 바꾸는 PR에서 테스트·타입 검사와 세 플랫폼 빌드(릴리스 없이)를 돌린다. 기존 `ci.yml`·`deploy.yml` 은 바꾸지 않고 새 워크플로를 둔다.
11. **백엔드 변경 없음.** 필요한 API·CORS·Range는 `broadcast-api` 에서 끝났다.

## Tech Stack

- Tauri 2(최신 2.x), Rust stable, `@tauri-apps/cli`, `@tauri-apps/api`
- Vite + TypeScript(strict), 테스트 Vitest(jsdom)
- 패키지 관리 pnpm(`desktop/pnpm-lock.yaml`)
- CI: `tauri-apps/tauri-action`, 러너 `windows-latest`(x64), `macos-latest`(유니버설: `aarch64-apple-darwin` + `x86_64-apple-darwin`)

## Commands

```bash
cd desktop
pnpm install
pnpm test                    # Vitest: API 파싱·목록 정리·시각 표시·화면 그리기
pnpm typecheck               # tsc --noEmit
pnpm tauri dev               # 로컬 실행(기본: 공개 서버). 로컬 서버: VITE_TADAK_API_BASE=http://localhost:8080 pnpm tauri dev
pnpm tauri build             # 이 Mac용 빌드(.app/.dmg)
pnpm tauri build --target universal-apple-darwin
```

## Project Structure

```
desktop/
  package.json, pnpm-lock.yaml, tsconfig.json, vite.config.ts
  index.html                 → 목록·플레이어 화면 틀(한 페이지, 화면 전환은 상태로)
  src/
    api.ts                   → fetchBroadcasts(base): 응답 검증·변환(타입 BroadcastList)
    list.ts                  → 목록 화면 그리기(지금 타는 중·다시 보기), 종료 라이브 숨김
    player.ts                → 녹화방송 플레이어
    web.ts                   → watchUrl 을 앱 안 창으로 열기, 브라우저로 열기
    format.ts                → 시각 표시(yyyy-MM-dd HH:mm, Asia/Seoul — 웹과 같은 형식)
    main.ts, styles.css, fonts/
  test/                      → *.test.ts (Vitest)
  src-tauri/
    Cargo.toml, tauri.conf.json, capabilities/, icons/, src/main.rs
.github/workflows/desktop.yml → PR: 테스트·빌드 / main 푸시(desktop/** 변경): 빌드·Release
.dockerignore                 → desktop/ 추가
README.md                     → 데스크톱 앱 절(설치 파일, 로컬 실행, 배포 방식, 서명 없음)
```

## Code Style

```ts
/** 서버 목록 API(계약: SPEC-broadcast-api.md). 모르는 필드는 무시하고, 필요한 필드가 없으면 오류로 본다. */
export async function fetchBroadcasts(base: string, fetchImpl: typeof fetch = fetch): Promise<BroadcastList> {
  const response = await fetchImpl(`${base}/api/broadcasts`, { headers: { Accept: "application/json" } });
  if (!response.ok) throw new ApiError(`목록을 불러오지 못했습니다(${response.status}).`);
  return parseBroadcastList(await response.json());
}
```

- 사용자 글은 `textContent` 로만. `innerHTML` 에 응답 값을 넣지 않는다.
- 화면 문구는 한국어, 오류는 무엇을 하면 되는지 한 문장(CODING_STANDARDS).
- Rust 쪽은 창 열기 외 로직을 두지 않는다(최소 셸).

## Testing Strategy

- **Vitest(단위·DOM):** `parseBroadcastList`(정상·모르는 필드 무시·필수 필드 없음 → 오류), 목록 정리(방송 중만 "지금 타는 중", 종료 숨김, 녹화 순서 유지), 시각 표시(UTC → `yyyy-MM-dd HH:mm` 서울), 목록 그리기(제목에 `<script>` 를 넣어도 글자로 보임, "불가에 N명", 빈 목록 안내), 서버 오류 시 안내·다시 시도.
- **타입:** `pnpm typecheck`.
- **빌드:** PR 워크플로가 Windows·macOS 빌드 성공을 확인.
- **수동(사용자와):** 공개 서버를 가리키는 실제 앱으로 목록 표시, 녹화방송 재생·탐색, 라이브 웹 창 열기(가능하면 라이브 시청), 웹 창에서 로그인·댓글, 장작 넣기(토스 테스트 결제) 또는 막히면 "브라우저로 열기"로 우회되는지. macOS는 이 Mac에서, Windows는 사용자 PC 또는 Windows가 없으면 CI 빌드 산출물 설치까지만.

## Boundaries

- **Always:** 테스트 먼저(TS 로직), 사용자 글 `textContent`, CSP·capabilities 최소, 비밀 값 없음(앱에 키를 넣지 않음), 파일 이름 고정.
- **Ask first:** 프런트엔드 프레임워크·큰 의존성 추가, 서버(백엔드) 변경, 기존 `ci.yml`·`deploy.yml` 변경, 자동 업데이트·트레이 같은 범위 확장, 릴리스를 지우거나 덮어쓰는 일, 첫 Release 공개.
- **Never:** 코드 서명 인증서·Apple 계정 사용(유료), 원격 웹 창에 Tauri IPC 허용, 앱 안에 로그인·댓글·후원·송출을 다시 만드는 일(의도 문서 "하지 않는 것"), `zoek1211/chzzk` 수정.

## Success Criteria

1. `main` 에 `desktop/**` 변경이 들어가면 워크플로가 Windows `.exe` 와 macOS 유니버설 `.dmg` 를 만들고 Release `desktop-v0.1.N`(latest)에 올린다. `desktop/**` 가 안 바뀐 푸시는 앱을 빌드하지 않는다.
2. `https://github.com/zoek1211/tadak-live/releases/latest/download/Tadak-Live-windows-x64-setup.exe` 와 `…/Tadak-Live-macos-universal.dmg` 가 최신 파일을 내려준다.
3. macOS(이 Mac, Apple Silicon)에서 `.dmg` 설치 후 "확인되지 않은 개발자" 경고를 넘기면 열리고, 공개 서버의 방송 목록이 "지금 타는 중"·"다시 보기"로 보인다. 방송 중 라이브에는 "불가에 N명".
4. 녹화방송을 누르면 앱 안에서 재생되고 탐색(앞뒤로 넘기기)이 된다.
5. 라이브 카드·"웹에서 열기"는 해당 웹 화면을 앱 안 새 창으로 열고, "브라우저로 열기"로 기본 브라우저에서도 열 수 있다.
6. 서버에 닿지 않으면 안내와 "다시 시도"가 보이고, 다시 닿으면 목록이 돌아온다.
7. 제목·닉네임에 HTML을 넣어도 앱 화면에서 글자로 보인다(스크립트 실행 안 됨).
8. 원격 웹 창에서 Tauri 명령을 부를 수 없다(capabilities에 원격 출처 없음).
9. Windows 설치 파일이 CI에서 만들어지고 설치·실행된다(사용자 Windows PC에서 확인, 없으면 빌드 성공까지만으로 하고 보류 표시).
10. `pnpm test`·`pnpm typecheck` 통과, PR 워크플로가 두 플랫폼 빌드 성공.
11. README에 데스크톱 앱 절(파일 링크, 지원 아키텍처, 로컬 실행, 서명 없음과 경고)이 있다.

## Out of Scope (Deferred)

- 다운로드 페이지(`/download`)와 Gatekeeper·SmartScreen 우회 자세한 안내 → `download-page`
- 자동 업데이트(Tauri updater, 서명 키 필요) → V2
- 앱 안 서버 주소 설정 → `custom-domain` 때 새 버전으로 대신
- Linux 빌드 → 의도 문서 지원 대상 아님
- 트레이·알림(라이브 시작 알림) → V2
- 썸네일 → 서버에 썸네일이 없음
- 코드 서명·공증 → 유료, 의도 문서 "하지 않는 것"
- 백엔드 배포를 `desktop/**` 변경에서 건너뛰는 경로 필터(`deploy.yml`) → 지금은 앱만 바뀐 푸시도 백엔드를 다시 배포한다(같은 코드라 무해). 필요하면 따로

## Risks

| 위험 | 영향 | 대응 |
|---|---|---|
| 앱 안 웹뷰에서 토스 결제창(팝업·새 창)이 막힘 | 중 | 웹 창의 `window.open` 을 새 앱 창으로 허용, 안 되면 "브라우저로 열기"로 우회하고 README에 적음 |
| 웹뷰 WebRTC·카메라 권한(라이브 시청) | 중 | 시청은 수신만이라 카메라 불필요. macOS WKWebView·WebView2 모두 WebRTC 지원. 안 되면 브라우저로 |
| 유니버설 macOS 빌드 시간·실패 | 낮 | 실패 시 arm64·x64 두 파일로 나누는 대안 |
| 서명 없는 앱 경고로 사용자가 못 엶 | 중 | ad-hoc 서명, README·다운로드 페이지 안내 |
| 서버 주소 변경(`custom-domain`) | 낮 | 빌드 변수 하나라 새 버전 배포로 해결 |

## Decisions (2026-11-22, 기본값으로 승인)

1. **웹 화면은 앱 안 새 창**(`WebviewWindow`), 창마다 "브라우저로 열기".
2. **릴리스는 `desktop/**` 이 바뀐 `main` 푸시마다** 자동(`desktop-v0.1.<실행 번호>`, latest).
3. **macOS는 유니버설 `.dmg` 하나.**

## Open Questions

없음.
