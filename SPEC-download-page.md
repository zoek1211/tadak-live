# Spec: download-page — V1

Status: approved (2026-11-22) · 모듈 지도: `CAPABILITY-MAP.md` · 의도: `docs/intent/oci-deploy.md`("다운로드 페이지") · 가리키는 파일: `SPEC-desktop-app.md`(implemented, Release `desktop-v0.1.N`)

## Objective

공개 서버에 **`/download` 페이지**를 둔다. 방문자가 자기 OS에 맞는 데스크톱 앱 설치 파일을 받고, 서명하지 않은 앱이라 뜨는 **macOS Gatekeeper·Windows SmartScreen 경고를 넘겨** 처음 실행까지 할 수 있게 한다. iPhone·Android는 웹(Safari·Chrome)을 쓰라고 안내한다.

사용자:
- **방문자(비로그인 포함):** 사이트 머리글의 "앱 받기"로 들어와 파일을 받고, 단계 안내대로 설치·실행한다.
- **운영자:** 새 Release가 나오면 페이지를 고치지 않아도 링크가 최신 파일을 가리킨다.

## 가정

1. **백엔드 안 Thymeleaf 페이지 `GET /download`.** 모듈 지도 공통 결정 5("백엔드 안 정적 페이지")를 따르되, 사이트 머리글·글꼴·색을 그대로 쓰려고 정적 HTML 대신 기존 `fragments/layout` 을 쓰는 템플릿으로 만든다. 비로그인 공개(보안 설정은 이미 `anyRequest().permitAll()`).
2. **링크는 GitHub Releases 고정 주소.** `https://github.com/zoek1211/tadak-live/releases/latest/download/Tadak-Live-windows-x64-setup.exe`, `…/Tadak-Live-macos-universal.dmg`(데스크톱 워크플로가 이름을 고정함). 페이지는 버전을 몰라도 항상 최신을 가리킨다. 주소 앞부분은 설정 `chzzk.desktop.download-base`(환경변수 `CHZZK_DESKTOP_DOWNLOAD_BASE`, 기본값 위 GitHub 주소)로 바꿀 수 있게 한다. 서버가 GitHub API를 부르지 않는다(외부 의존·요청 한도 없음).
3. **버전 번호는 페이지에 쓰지 않는다.** 대신 "모든 버전·변경 내역" 링크로 Releases 목록(`…/releases`)을 건다.
4. **페이지 내용(위에서 아래로):**
   - 한 줄 소개("불가를 데스크톱에서도") + 앱이 하는 일(목록·녹화 재생, 라이브·로그인·댓글·장작 넣기는 앱 안 웹 창)
   - OS별 카드 두 개: **Windows**(Windows 10·11, x64, `.exe` 약 4MB) / **macOS**(macOS 11 이상, Apple Silicon·Intel 겸용, `.dmg` 약 9MB), 각각 "받기" 버튼
   - **macOS 처음 열기:** `.dmg` 열고 Applications로 끌기 → 열면 "Apple은 … 확인할 수 없습니다" 경고 → **완료** → 시스템 설정 → 개인정보 보호 및 보안 → **그래도 열기** → 다시 **그래도 열기** + 암호. macOS 15부터 Control-클릭 열기가 안 된다는 점, 안 되면 `xattr -dr com.apple.quarantine "/Applications/Tadak Live.app"`
   - **Windows 처음 실행:** 설치 파일 실행 → "Windows의 PC 보호" 창 → **추가 정보** → **실행** → 설치 마법사. WebView2가 없으면 설치 중에 자동으로 받는다는 점
   - **왜 경고가 뜨나:** 코드 서명 인증서(유료)를 쓰지 않은 개인 프로젝트라서, 파일은 이 저장소 GitHub Actions가 공개 소스로 빌드한 것(Release·워크플로 링크)
   - **휴대폰:** iPhone·Android 앱은 없고 이 사이트를 브라우저로 쓰면 된다(라이브 송출은 휴대폰 브라우저에서)
5. **OS 추천 표시는 브라우저에서만, 선택적.** 작은 인라인 스크립트가 `navigator.userAgentData`/`userAgent` 로 Windows·Mac을 알아내 해당 카드에 "이 컴퓨터용" 표시를 붙인다. 스크립트가 없어도 두 카드가 똑같이 보이고 받을 수 있다. 서버는 User-Agent를 보지 않는다. (기존 화면이 인라인 스크립트를 쓰는지에 맞춰 위치를 정하고, CSP를 새로 걸지는 않는다)
6. **머리글에 "앱 받기" 링크.** `fragments/layout` 의 머리글 메뉴에 `/download` 링크를 더한다(모든 화면, 데스크톱 앱 안 웹 창 포함). 디자인 시안 말투에 맞춰 문구는 "앱 받기".
7. **코드 위치:** 새 패키지 `download`(도메인 단위 패키지 규칙)에 `DownloadController` 와 설정 값 바인딩. 템플릿 `templates/download/index.html`, 스타일은 기존 `app.css` 에 몇 줄.
8. **README:** "데스크톱 앱" 절의 경고 안내를 줄이고 `/download` 페이지로 안내(같은 내용을 두 곳에 길게 두지 않음).
9. **새 의존성·백엔드 API 변경 없음.** 배포는 기존 파이프라인(병합 → 자동 배포).

## Tech Stack

기존 그대로: Spring Boot 4.1 MVC, Thymeleaf(`fragments/layout`), `app.css`, JUnit 5 + MockMvc(`TestWeb.mvc`).

## Commands

```bash
./gradlew test --tests 'kr.devcourse.chzzk.DownloadPageWebTest'
./gradlew test
./gradlew bootRun                                   # http://localhost:8080/download
curl -s https://129-221-138-89.sslip.io/download | grep -c 'releases/latest/download'   # 배포 후
deploy/oci/verify.sh --app                          # /download 확인 항목 추가
```

## Project Structure

```
src/main/java/kr/devcourse/chzzk/download/DownloadController.java   → GET /download
src/main/java/kr/devcourse/chzzk/download/DesktopDownloads.java     → 다운로드 주소(설정 바인딩, 파일 이름 상수)
src/main/resources/templates/download/index.html                    → 페이지
src/main/resources/templates/fragments/layout.html                  → 머리글 "앱 받기"
src/main/resources/static/css/app.css                               → 카드·단계 목록 스타일 몇 줄
src/main/resources/application.properties                           → chzzk.desktop.download-base
src/test/java/kr/devcourse/chzzk/DownloadPageWebTest.java           → 새 테스트
README.md, .env.example                                             → /download 안내, 새 환경변수
deploy/oci/verify.sh                                                → --app 에 /download 200·링크 확인
```

## Code Style

기존 컨트롤러처럼 화면 이름만 돌려주고 값은 작은 객체로 넘긴다.

```java
/** 데스크톱 앱 다운로드 안내(비로그인 공개). 링크는 GitHub Releases 의 고정 이름 최신 파일. */
@Controller
class DownloadController {

    private final DesktopDownloads downloads;

    @GetMapping("/download")
    String page(Model model) {
        model.addAttribute("downloads", downloads);
        return "download/index";
    }
}
```

- 사용자 입력이 없는 페이지지만 값은 `th:text`/`th:href` 로만 넣는다.
- 화면 문구는 한국어, 버튼·단계 이름은 실제 OS 화면 문구와 같게(그래도 열기, 추가 정보, 실행).

## Testing Strategy

`DownloadPageWebTest`(MockMvc, `@TempDir` 데이터 디렉터리):
1. 비로그인 `GET /download` → 200, 제목에 "앱 받기".
2. Windows·macOS 링크가 기본 고정 주소(`…/releases/latest/download/Tadak-Live-windows-x64-setup.exe`, `…/Tadak-Live-macos-universal.dmg`).
3. `chzzk.desktop.download-base` 를 바꾸면 링크 앞부분이 바뀐다(별도 컨텍스트).
4. 경고 넘기는 단계의 핵심 문구가 있다: "그래도 열기", "개인정보 보호 및 보안", "추가 정보", "실행", `xattr`.
5. 휴대폰 안내(브라우저로 쓰기)가 있다.
6. 머리글에 `/download` 링크("앱 받기")가 있다(목록 화면에서 확인).

기존 화면 테스트가 머리글 문구를 검사하면 함께 맞춘다. 전체 `./gradlew test` 통과.

## Boundaries

- **Always:** 테스트 먼저, 링크는 설정 값으로(템플릿에 저장소 주소 하드코딩 금지), OS 화면 문구는 실제와 같게.
- **Ask first:** 새 의존성, 서버가 GitHub API를 부르는 방식(버전 표시), 머리글 구조를 크게 바꾸는 일, Release 파일 이름 변경(데스크톱 워크플로와 같이 바꿔야 함).
- **Never:** 설치 파일을 서버(VM)에 두는 일(디스크·트래픽), 서명이 있는 것처럼 안내하는 일, 사용자 OS 보안 설정을 끄라고(예: Gatekeeper 전체 끄기 `spctl --master-disable`) 안내하는 일, `zoek1211/chzzk` 수정.

## Success Criteria

1. `https://129-221-138-89.sslip.io/download` 가 비로그인으로 200, 사이트 머리글·글꼴·색으로 보인다.
2. Windows·macOS "받기"가 최신 Release 파일을 내려준다(고정 주소, 페이지 수정 없이 새 Release를 따라감).
3. 지원 대상(Windows 10·11 x64 / macOS 11+ Apple Silicon·Intel)과 파일 형식·크기가 보인다.
4. macOS 15 이후 방식(그래도 열기)과 `xattr` 대안, Windows SmartScreen(추가 정보 → 실행) 단계가 실제 화면 문구로 적혀 있다.
5. 왜 경고가 뜨는지(서명 없음, 공개 소스·Actions 빌드)와 Releases 목록 링크가 있다.
6. 휴대폰은 브라우저로 쓰라는 안내가 있다.
7. 모든 화면 머리글에 "앱 받기" 링크가 있다(데스크톱 앱 웹 창에서도).
8. Windows·Mac 브라우저에서 해당 카드에 "이 컴퓨터용" 표시가 붙고, 스크립트가 없어도 페이지가 그대로 쓸 수 있다.
9. `./gradlew test` 전체 통과, 새 테스트가 1~7을 덮는다.
10. 병합 후 자동 배포 성공, `verify.sh --app` 이 `/download` 항목까지 통과.
11. README가 `/download` 로 안내하고, 새 환경변수가 README 표·`.env.example` 에 있다.

## Out of Scope (Deferred)

- 최신 버전 번호·출시일 표시(GitHub API) → 필요하면 delta spec
- 다운로드 수 집계 → 범위 밖
- 자동 업데이트 안내 → 앱에 업데이트 기능이 없음(desktop V2)
- Linux 파일 → 지원 대상 아님
- 영어 페이지 → 사이트가 한국어 전용
- 설치 과정 스크린샷·영상 → 문구로 충분, 필요하면 V2

## Decisions (2026-11-22, 기본값으로 승인)

1. **머리글 "앱 받기"는 메뉴 맨 오른쪽**(로그인·회원가입/로그아웃 뒤).
2. **OS 추천 표시("이 컴퓨터용")를 넣는다.** 스크립트가 없어도 페이지는 그대로 쓸 수 있다.
3. **README는 `/download` 로만 안내**하고 경고 넘기는 단계는 페이지에만 둔다.

## Open Questions

없음.
