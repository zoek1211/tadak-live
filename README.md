# 타닥 라이브

**불 켜면 모인다.** 휴대폰 하나로 라이브를 켜면, 사람들이 불가에 둘러앉듯 모여 함께 보고 이야기하고 후원하는 방송 서비스입니다.

- **라이브 방송:** 휴대폰 카메라·마이크로 송출하고 다른 화면에서 실시간으로 봅니다. 영상은 WebRTC로 기기끼리 직접 오가고, 서버는 연결(시그널링)만 이어 줍니다.
- **다시 보기:** 영상 파일을 올리거나 영상 주소를 넣어 녹화방송을 등록하고 바로 재생합니다.
- **회원과 댓글:** 회원가입·로그인한 사람만 방송을 만들고 댓글을 씁니다. 방송은 만든 사람만, 댓글은 쓴 사람만 고치고 지울 수 있고, 권한은 서버가 매번 검사합니다. 목록·시청·댓글 읽기는 로그인 없이 공개입니다.
- **후원:** 토스페이먼츠 테스트 결제로 방송한 사람에게 후원합니다. 서버가 토스에 승인을 다시 확인한 뒤에만 합계에 더합니다.
- **여러 인스턴스:** 같은 서버를 로컬 Kubernetes(kind)에 여러 개 띄우고, 부하에 따라 2~5개로 자동으로 늘고 줄어도 로그인·방송·댓글·라이브가 유지됩니다.

## 목차

- [빠른 실행](#빠른-실행)
- [휴대폰으로 송출하기](#휴대폰으로-송출하기)
- [후원 켜기](#후원-켜기)
- [여러 인스턴스로 실행하기](#여러-인스턴스로-실행하기)
- [환경변수](#환경변수)
- [기술 구성](#기술-구성)
- [이 프로젝트의 출발점](#이-프로젝트의-출발점)

## 빠른 실행

필요한 것: JDK 25 이상 (Gradle은 래퍼가 내려받습니다)

```bash
./gradlew bootRun
```

브라우저에서 <http://localhost:8080> 을 엽니다. 방송을 만들거나 댓글을 쓰려면 헤더의 **회원가입** 으로 가입하세요(가입하면 바로 로그인됩니다). 8080 포트를 다른 프로그램이 쓰고 있다면 `PORT=9090 ./gradlew bootRun` 처럼 포트를 바꿉니다.

데이터(H2 DB 파일과 올린 영상)는 `./data` 에 저장되어 서버를 다시 켜도 남습니다. 처음 상태로 돌리려면 서버를 끄고 `data/` 를 지웁니다.

```bash
./gradlew test                     # 테스트 (클러스터 모드 테스트는 Docker가 켜져 있어야 실행됨)
./gradlew bootJar && java -jar build/libs/chzzk-0.0.1-SNAPSHOT.jar   # jar로 실행
```

## 휴대폰으로 송출하기

휴대폰 브라우저는 **HTTPS 주소에서만** 카메라·마이크를 엽니다. 가장 간단한 방법은 cloudflared 임시 터널입니다(계정·인증서 필요 없음).

1. [cloudflared](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/) 를 설치합니다 (macOS: `brew install cloudflared`).
2. 서버를 띄운 채로 다른 터미널에서 터널을 엽니다.

   ```bash
   cloudflared tunnel --url http://localhost:8080
   ```

3. 출력에 나오는 `https://<임의이름>.trycloudflare.com` 주소를 휴대폰에서 열고, 로그인한 뒤 `/live/new` 에서 방송을 시작합니다.
4. 컴퓨터 브라우저의 방송 목록에서 "방송 중" 배지가 붙은 라이브를 눌러 시청합니다.

서로 다른 네트워크라 영상이 안 오면 TURN 서버를 설정하세요([환경변수](#환경변수)). 직접 HTTPS(자체 서명 키스토어)와 카메라 권한 문제 해결은 [과제 문서의 휴대폰 연결 방법](docs/chzzk-assignment-README.md#휴대폰-연결-방법)에 있습니다.

## 후원 켜기

실제 돈이 오가지 않는 **테스트 결제** 만 씁니다.

1. [토스페이먼츠 개발자센터](https://developers.tosspayments.com)에서 **API 개별 연동 키** 의 테스트 키를 확인합니다. 클라이언트 키는 `test_ck_`, 시크릿 키는 `test_sk_` 로 시작합니다.
2. 두 값을 환경변수로 넣고 서버를 띄웁니다. 시크릿 키는 저장소에 커밋하지 마세요.

   ```bash
   TOSS_CLIENT_KEY=test_ck_<클라이언트키> TOSS_SECRET_KEY=test_sk_<시크릿키> ./gradlew bootRun
   ```

키가 하나라도 없으면 후원만 꺼진 채로 앱이 뜹니다. 웹훅 등록 같은 자세한 내용은 [과제 문서의 4단계](docs/chzzk-assignment-README.md#4단계-도네이션)에 있습니다.

## 여러 인스턴스로 실행하기

필요한 것: Docker(메모리 4GB 이상 권장), [kind](https://kind.sigs.k8s.io), kubectl. JDK는 필요 없습니다(이미지 안에서 빌드).

```bash
scripts/cluster-up.sh       # kind 클러스터 생성 → 이미지 빌드 → Postgres·Redis·앱·HPA 배포
kubectl --context kind-chzzk get hpa,pods -w   # 인스턴스 수 지켜보기 (다른 터미널)
scripts/load.sh             # k6로 부하 걸기 (약 5분 30초)
scripts/check-state.sh      # 스케일 중 로그인·목록·댓글 유지 확인 (다른 터미널)
scripts/cluster-down.sh     # 클러스터 삭제
```

배포가 끝나면 <http://localhost:8080> 으로 접속합니다. 클러스터는 호스트의 8080 포트를 쓰므로, 다른 프로그램이 8080을 쓰고 있으면 먼저 멈추세요.

이 구성에서는 인스턴스가 언제든 생기고 사라지므로 상태를 모두 서버 밖에 둡니다. 회원·방송·댓글·후원은 Postgres, 로그인 세션과 라이브 방 상태는 Redis, 올린 영상은 공유 볼륨에 둡니다. 실제로 돌려 본 기록(인스턴스 2→5→2, 요청 597,305건 실패 0%, 상태 확인 91/91 유지)은 [docs/scale-check/](docs/scale-check/)에 있습니다.

## 환경변수

모두 선택 사항이고, 예시는 [.env.example](.env.example)에 있습니다. 비밀 값(TURN 자격 증명, 키스토어 비밀번호, 토스 시크릿 키, DB 비밀번호)은 커밋하지 말고 실행 환경에서만 설정하세요. 변수 이름의 `CHZZK_` 접두어는 출발점이었던 과제 이름을 그대로 쓴 것입니다.

| 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `PORT` | `8080` | 서버 포트 |
| `CHZZK_DATA_DIR` | `./data` | DB 파일과 올린 영상(`videos/`)이 저장되는 디렉터리 |
| `CHZZK_MAX_UPLOAD_SIZE` | `2GB` | 올릴 수 있는 영상 최대 크기 |
| `CHZZK_VIEWER_CAPACITY` | `5` | 라이브 하나를 동시에 볼 수 있는 시청자 수 |
| `CHZZK_BROADCASTER_JOIN_TIMEOUT` | `30s` | 라이브를 시작한 뒤 방송자가 접속해야 하는 제한 시간 |
| `CHZZK_STUN_URL` | `stun:stun.l.google.com:19302` | WebRTC STUN 서버 |
| `CHZZK_TURN_URL` / `CHZZK_TURN_USERNAME` / `CHZZK_TURN_CREDENTIAL` | (없음) | TURN 서버. 서로 다른 네트워크 사이 연결이 필요할 때만 |
| `CHZZK_SSL_ENABLED` | `false` | `true` 면 HTTPS로 서비스 |
| `CHZZK_SSL_KEY_STORE` / `CHZZK_SSL_KEY_STORE_PASSWORD` / `CHZZK_SSL_KEY_STORE_TYPE` | (없음) / (없음) / `PKCS12` | HTTPS 키스토어 |
| `TOSS_CLIENT_KEY` / `TOSS_SECRET_KEY` | (없음) | 토스페이먼츠 테스트 키. 둘 다 있어야 후원이 켜짐 |
| `TOSS_CONNECT_TIMEOUT` / `TOSS_READ_TIMEOUT` | `5s` / `10s` | 토스 API 제한 시간 |

클러스터 모드(`SPRING_PROFILES_ACTIVE=cluster`) 전용 변수(`CHZZK_DB_*`, `CHZZK_REDIS_*`, `CHZZK_INSTANCE_ID`)는 k8s 매니페스트([k8s/chzzk.yaml](k8s/chzzk.yaml))가 설정하므로 직접 정할 필요가 없습니다. 전체 표는 [과제 문서의 환경변수](docs/chzzk-assignment-README.md#환경변수)에 있습니다.

## 기술 구성

- Java 25, Spring Boot 4.1, Spring MVC + Thymeleaf, Spring Data JPA, Spring WebSocket, Spring Security(세션 로그인·CSRF)
- 저장소: 단독 실행은 파일 기반 H2 + 로컬 디스크, 클러스터 실행은 Postgres + Redis + 공유 볼륨
- 설계 결정: [docs/adr/](docs/adr/)
  - [WebRTC P2P 라이브](docs/adr/0001-webrtc-p2p-live.md)
  - [송출 키 대신 로그인한 소유자 검사](docs/adr/0002-live-owner-session-replaces-broadcast-key.md)
  - [토스 테스트 결제와 서버 승인 확인](docs/adr/0003-toss-test-payment-with-server-confirmation.md)
  - [공용 저장소와 Redis 중계를 쓰는 클러스터 모드](docs/adr/0004-cluster-mode-with-shared-stores-and-redis-relay.md)
- 용어: [GLOSSARY.md](GLOSSARY.md)

## 이 프로젝트의 출발점

타닥 라이브는 Codemit 과제 "치지직 만들기" 1~5단계(녹화방송 → 휴대폰 라이브 → 인증·댓글 → 후원 → 로컬 오토스케일)로 만든 서비스에 새 이름과 화면 테마를 입힌 것입니다. 커밋 기록은 그대로 이어지고, 단계별 제출 태그(`step-1`~`step-5`)는 [zoek1211/chzzk](https://github.com/zoek1211/chzzk)에 있습니다. 제출 당시 README(단계별 구현 범위, 직접 확인 절차, 테스트 목록)는 [docs/chzzk-assignment-README.md](docs/chzzk-assignment-README.md)에 그대로 옮겨 두었습니다.
