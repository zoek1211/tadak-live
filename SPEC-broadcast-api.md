# Spec: broadcast-api — V1

Status: implemented (2026-11-22) · 모듈 지도: `CAPABILITY-MAP.md` · 의도: `docs/intent/oci-deploy.md` · 공개는 `backend-deploy`(implemented)로

## Objective

데스크톱 앱(`desktop-app`)이 배포한 백엔드에서 **방송 목록을 API로 받아 자기 화면에 그리고, 녹화방송은 앱 안 플레이어로 재생**할 수 있게 `GET /api/broadcasts` 를 추가한다. 라이브 시청·로그인·댓글·후원은 앱이 웹 화면을 여는 방식이므로, API는 각 방송의 웹 주소도 함께 준다.

사용자:
- **데스크톱 앱(1차 소비자):** 로그인 없이 목록 조회, 녹화방송 영상 주소로 재생(탐색 포함), 라이브는 웹 주소로 열기.
- **이후 다른 클라이언트:** 같은 계약을 그대로 쓴다. 필드는 추가만 하고 바꾸거나 지우지 않는다.

## 가정

1. **경로는 `GET /api/broadcasts` 하나.** 의도 문서의 예시 그대로, 버전 접두사(`/api/v1`)는 붙이지 않는다. 계약을 깨는 변경이 필요해지면 그때 새 경로를 만든다.
2. **웹 목록과 같은 범위·같은 순서.** 라이브는 방송 중이 먼저, 그다음 종료(각각 최신순), 녹화방송은 최신순. 기존 `LiveBroadcastService.list()`, `RecordedBroadcastService.list()` 를 그대로 쓴다. 페이지 나누기는 하지 않는다(방송 수가 적음).
3. **비로그인 공개, 읽기 전용.** 웹 목록에서 누구나 보는 정보와 같다. 회원 DB id는 넣지 않는다(CODING_STANDARDS). 방송 id는 웹 주소에 이미 드러나 있으므로 넣는다.
4. **주소는 절대 주소.** 앱은 서버 밖에서 돌기 때문에 `playbackUrl`·`watchUrl` 을 `https://<host>/...` 로 준다. 요청 기준으로 만들고(`ServletUriComponentsBuilder`), 이미 켜져 있는 `forward-headers-strategy=framework` 덕분에 Caddy 뒤에서 `https` 공개 주소가 된다. 외부 영상(`EXTERNAL`)은 등록된 주소 그대로.
5. **시각은 ISO-8601 UTC 문자열**(예: `2026-11-22T09:44:00Z`). 기존 댓글 JSON(`CommentView` 의 `Instant`)과 같은 직렬화다. 화면 표시 형식(`yyyy-MM-dd HH:mm`, Asia/Seoul)은 클라이언트가 바꾼다.
6. **라이브 시청자 수를 준다.** 방송 중인 라이브에 `viewerCount`(지금 붙어 있는 시청자 수, `LiveRooms.viewerIds(id).size()`)와 `viewerCapacity`(정원, `chzzk.live.viewer-capacity`)를 넣는다. 종료된 라이브는 `viewerCount: 0`. 단독·클러스터 모드 모두 `LiveRooms` 구현이 답한다.
7. **CORS는 이 경로만, 모든 출처에 GET 허용, 쿠키 없음.** Tauri 웹뷰의 출처(`tauri://localhost`, `http://tauri.localhost`)는 플랫폼마다 다르고, 데이터가 공개 정보라 `Access-Control-Allow-Origin: *` 로 둔다. 자격 증명(쿠키)은 허용하지 않으므로 로그인 세션이 실리지 않는다. 다른 경로(`/broadcasts`, `/live/**` 등)의 CORS는 바꾸지 않는다.
8. **녹화 영상 탐색(Range)은 이미 된다고 보고 테스트로 못박는다.** `VideoController` 가 `ResponseEntity<Resource>` 를 돌려주므로 Spring MVC가 `Range` 요청에 `206 Partial Content` 로 답한다. 데스크톱 플레이어의 탐색이 이것에 기댄다. 안 되면 이 모듈에서 고친다.
9. **코드 위치:** 목록 화면과 같은 `list` 패키지에 `BroadcastListApiController` 를 새로 둔다. 기존 `BroadcastListController`(화면)는 건드리지 않는다. 응답 모양은 컨트롤러 안의 `record` 로 정의한다(엔티티를 그대로 직렬화하지 않음).
10. **배포는 기존 파이프라인.** PR 병합 → `deploy.yml` → VM. 새 환경변수 없음.

## 응답 계약

```http
GET /api/broadcasts
200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *
```

```json
{
  "live": [
    {
      "id": 3,
      "title": "저녁 산책 라이브",
      "ownerNickname": "타닥이",
      "status": "ON_AIR",
      "startedAt": "2026-11-22T10:20:00Z",
      "endedAt": null,
      "viewerCount": 2,
      "viewerCapacity": 5,
      "watchUrl": "https://129-221-138-89.sslip.io/live/3"
    }
  ],
  "recorded": [
    {
      "id": 2,
      "title": "첫 녹화",
      "ownerNickname": "타닥이",
      "registeredAt": "2026-11-22T10:03:00Z",
      "videoSource": "UPLOADED",
      "playbackUrl": "https://129-221-138-89.sslip.io/videos/2f1c….mp4",
      "watchUrl": "https://129-221-138-89.sslip.io/broadcasts/2"
    }
  ]
}
```

- `status`: `ON_AIR` | `ENDED` (기존 `LiveStatus` 이름 그대로)
- `videoSource`: `UPLOADED` | `EXTERNAL`
- `ownerNickname`: 소유자 없는 기존 방송이면 `null`
- 빈 목록은 `[]` (필드 자체는 항상 있음)
- 필드 추가는 하위 호환으로 본다. 클라이언트는 모르는 필드를 무시해야 한다.

## Tech Stack

기존 그대로: Spring Boot 4.1 MVC, Jackson 3(`tools.jackson`), Spring Security(경로는 이미 `anyRequest().permitAll()`), JUnit 5 + `@SpringBootTest(RANDOM_PORT)` + `java.net.http.HttpClient`(기존 `TestLogin.Http`). 새 의존성 없음.

## Commands

```bash
./gradlew test --tests 'kr.devcourse.chzzk.BroadcastListApiTest'   # 새 테스트
./gradlew test                                                      # 전체
./gradlew bootRun                                                   # 로컬 확인: curl -s localhost:8080/api/broadcasts | jq
curl -s https://129-221-138-89.sslip.io/api/broadcasts | jq          # 배포 후
deploy/oci/verify.sh --app                                          # 기존 확인(+ API 항목 추가)
```

## Project Structure

```
src/main/java/kr/devcourse/chzzk/list/BroadcastListApiController.java  → 새 컨트롤러 + 응답 record
src/main/java/kr/devcourse/chzzk/live/LiveBroadcastService.java       → 시청자 수 조회 메서드(필요하면) 추가
src/main/java/kr/devcourse/chzzk/member/SecurityConfig.java           → /api/** CORS(GET, *, 자격 증명 없음)
src/test/java/kr/devcourse/chzzk/BroadcastListApiTest.java            → 새 테스트
deploy/oci/verify.sh                                                  → --app 에 /api/broadcasts 200·JSON·https 주소 확인
README.md                                                             → API 절(계약 요약, 예시)
```

## Code Style

기존 `CommentJsonController` 와 같은 모양으로 쓴다.

```java
/** 데스크톱 앱 등 클라이언트용 방송 목록(비로그인 공개, 읽기 전용). 회원 DB id는 넣지 않는다. */
@RestController
class BroadcastListApiController {

    record BroadcastList(List<LiveItem> live, List<RecordedItem> recorded) {
    }

    record RecordedItem(Long id, String title, String ownerNickname, Instant registeredAt,
                        VideoSource videoSource, String playbackUrl, String watchUrl) {
    }

    @GetMapping("/api/broadcasts")
    BroadcastList list() { ... }
}
```

- 서비스가 이미 있는 목록 메서드를 쓴다. 컨트롤러는 엔티티를 응답 record로 바꾸기만 한다.
- 절대 주소는 한 도우미(`absolute(String path)`)로 만든다.

## Testing Strategy

`BroadcastListApiTest`(실제 포트, 기존 `TestLogin.Http` 사용, 데이터 디렉터리는 `@TempDir` — `./data` 를 건드리지 않음):

1. 빈 상태: `200`, `{"live":[],"recorded":[]}`.
2. 회원이 녹화방송(업로드·외부 주소 각 하나)과 라이브를 만든 뒤: 필드 값·순서, `videoSource`, `ownerNickname`, 외부 영상은 등록 주소 그대로.
3. `X-Forwarded-Proto: https`, `X-Forwarded-Host: example.test` 를 붙이면 `playbackUrl`·`watchUrl` 이 `https://example.test/...`.
4. 응답 본문에 회원 DB id·로그인 아이디가 없다(`loginId`, `ownerId` 같은 필드 없음).
5. 라이브 시청자 수: 방송 중이고 시청자가 붙으면 `viewerCount` 가 늘고, 종료하면 `status: "ENDED"`, `viewerCount: 0`. (시청자 붙이기는 기존 시그널링 테스트 도우미를 재사용)
6. CORS: `Origin: tauri://localhost` 로 요청하면 `Access-Control-Allow-Origin: *`, `Access-Control-Allow-Credentials` 없음. `/broadcasts`(HTML)에는 CORS 헤더가 붙지 않는다.
7. 업로드 영상 `GET /videos/<name>` 에 `Range: bytes=0-9` → `206`, 10바이트.

기존 `ActuatorHealthTest` 등 전체 테스트가 그대로 통과해야 한다.

## Boundaries

- **Always:** 테스트 먼저, 응답은 record로 명시, 절대 주소는 요청 기준(하드코딩 금지), 회원 DB id 제외.
- **Ask first:** 응답 필드 이름·의미를 바꾸는 일, `/api/**` 외 경로의 CORS·보안 설정 변경, 페이지 나누기·검색 같은 범위 확장, 새 의존성.
- **Never:** 비공개 정보(로그인 아이디, 회원 id, 후원 내역) 노출, CORS에 자격 증명 허용, 기존 화면 경로 동작 변경.

## Success Criteria

1. `GET /api/broadcasts` 가 비로그인으로 `200`, 위 계약의 JSON을 낸다. 빈 목록은 `[]`.
2. 순서가 웹 목록(`/broadcasts`)과 같다.
3. 배포 주소에서 `playbackUrl`·`watchUrl` 이 `https://129-221-138-89.sslip.io/...` 로 나온다(http 아님).
4. `playbackUrl` 로 받은 업로드 영상이 재생되고 `Range` 요청에 `206` 으로 답한다.
5. 방송 중 라이브의 `viewerCount` 가 실제 붙은 시청자 수와 같다.
6. 응답에 회원 DB id·로그인 아이디가 없다.
7. 다른 출처(`tauri://localhost`)의 브라우저 `fetch` 가 CORS로 막히지 않는다. 쿠키는 실리지 않는다.
8. `./gradlew test` 전체 통과, 새 테스트가 위 항목을 덮는다.
9. 병합 후 자동 배포가 성공하고 `verify.sh --app` 이 API 항목까지 통과한다.
10. README에 API 절(경로, 필드, 예시, 하위 호환 규칙)이 있다.

## Out of Scope (Deferred)

- 페이지 나누기·검색·필터 → 방송이 많아지면
- 방송 하나 조회(`/api/broadcasts/{id}`), 댓글·후원 API → 데스크톱 앱은 웹 화면을 연다(의도 문서). 필요해지면 delta spec
- 인증이 필요한 API(내 방송 등) → 범위 밖
- OpenAPI 문서 자동 생성(springdoc) → 새 의존성, 필드가 적어 README로 충분
- 썸네일 → 업로드 영상 썸네일이 아직 없음
- `ENDED` 라이브 숨기기 → 웹과 같게 두고 클라이언트가 거름

## Decisions (2026-11-22, 기본값으로 승인)

1. **종료된 라이브도 넣는다.** 웹 목록과 같은 범위·순서. 클라이언트가 `status` 로 거른다.
2. **시청자 수를 넣는다.** 방송 중 라이브에 `viewerCount`·`viewerCapacity`.
3. **CORS는 `/api/**` 에 모든 출처(`*`) GET, 자격 증명 없음.**

## Open Questions

없음.
